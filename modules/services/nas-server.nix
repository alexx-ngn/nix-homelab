# Local NAS server: exports the ZFS dataset at /mnt/tank/nas over SMB (Samba)
# and NFSv4 to the LAN and the tailnet. Samba uses pkgs.samba4Full so it links
# Avahi/mDNS — alexmac picks the share up in Finder automatically. Auth: the
# `alex` POSIX user (from modules/security/user-alex.nix) with its Samba password
# provisioned from sops before smbd starts.
#
# This is the COUNTERPART to modules/services/media-storage.nix: that mounts a
# remote NAS *into* this host at /mnt/storage; this exports a local pool *out*.
{
  config,
  pkgs,
  ...
}:
let
  share = "/tank/nas";
  lan = "192.168.1.0/24";
  tailnet = "100.64.0.0/10"; # Tailscale CGNAT range

  # samba4Full enables enableCephFS (and GlusterFS) by default. This NAS is
  # backed by ZFS (tank) and uses neither, but the Ceph dependency drags in a
  # from-source ceph build that is broken/uncached in some nixpkgs revs — it
  # burned ~2h40m of CI and then failed on `arrow/util/span.h`. Drop CephFS
  # (and GlusterFS while we're here) to keep the closure cache-friendly.
  sambaPkg = pkgs.samba4Full.override {
    enableCephFS = false;
    enableGlusterFS = false;
  };
in
{
  sops.secrets."samba/alex_password" = {
    owner = "root";
    mode = "0400";
  };

  # --- Samba ---
  services.samba = {
    enable = true;
    # samba4Full links Avahi/mDNS — needed for Finder discovery on alexmac.
    # See sambaPkg above: same package, minus the unused CephFS/GlusterFS deps.
    package = sambaPkg;
    # We open ports per-interface below, matching the nixflix pattern.
    openFirewall = false;
    settings = {
      global = {
        "workgroup" = "WORKGROUP";
        "server string" = "alexserver";
        "netbios name" = "alexserver";
        "security" = "user";
        "map to guest" = "never";
        "hosts allow" = "${lan} ${tailnet} 127.0.0.0/8";
        "hosts deny" = "0.0.0.0/0";
        # macOS Finder gets weird without these (.DS_Store, AAPL extensions).
        "vfs objects" = "catia fruit streams_xattr";
        "fruit:aapl" = "yes";
        "fruit:metadata" = "stream";
        "fruit:encoding" = "native";
      };
      nas = {
        "path" = share;
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "valid users" = "alex";
        "force user" = "alex";
        "force group" = "users";
        "create mask" = "0644";
        "directory mask" = "0755";
      };
    };
  };

  # Provision the samba password for `alex` from the sops secret before smbd
  # starts. Idempotent: adds the user on first run, syncs the password on every
  # subsequent start (cheap, handles rotation).
  systemd.services.samba-smbd = {
    serviceConfig.ExecStartPre = pkgs.writeShellScript "samba-set-alex-password" ''
      set -eu
      pw_file="${config.sops.secrets."samba/alex_password".path}"
      pw="$(cat "$pw_file")"
      if ${sambaPkg}/bin/pdbedit -L | ${pkgs.gnugrep}/bin/grep -q '^alex:'; then
        printf '%s\n%s\n' "$pw" "$pw" | ${sambaPkg}/bin/smbpasswd -s alex
      else
        printf '%s\n%s\n' "$pw" "$pw" | ${sambaPkg}/bin/smbpasswd -s -a alex
      fi
    '';
    restartTriggers = [ config.sops.secrets."samba/alex_password".path ];
  };

  # --- mDNS so Finder shows alexserver under "Network" ---
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
      domain = true;
      userServices = true;
    };
    extraServiceFiles.smb = ''
      <?xml version="1.0" standalone='no'?>
      <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
      <service-group>
        <name replace-wildcards="yes">%h</name>
        <service>
          <type>_smb._tcp</type>
          <port>445</port>
        </service>
      </service-group>
    '';
  };

  # --- NFSv4 server ---
  # Pinning lockd/mountd/statd ports so the per-interface firewall rules below
  # can be exact rather than opening all of portmap.
  services.nfs.server = {
    enable = true;
    exports = ''
      ${share} ${lan}(rw,sync,no_subtree_check,root_squash,fsid=0) ${tailnet}(rw,sync,no_subtree_check,root_squash,fsid=0)
    '';
    lockdPort = 4001;
    mountdPort = 4002;
    statdPort = 4000;
  };

  # --- Firewall: only on tailscale0 and the LAN NIC, matching the per-interface
  # pattern used in modules/services/nixflix.nix. WAN stays closed. ---
  networking.firewall.interfaces =
    let
      smbTcp = [
        139
        445
      ];
      smbUdp = [
        137
        138
      ];
      nfsTcp = [
        2049
        111
        4000
        4001
        4002
      ];
      nfsUdp = [
        2049
        111
        4000
        4001
        4002
      ];
      mdnsUdp = [ 5353 ];
      bothTcp = smbTcp ++ nfsTcp;
      bothUdp = smbUdp ++ nfsUdp ++ mdnsUdp;
    in
    {
      tailscale0 = {
        allowedTCPPorts = bothTcp;
        allowedUDPPorts = bothUdp;
      };
      ens18 = {
        allowedTCPPorts = bothTcp;
        allowedUDPPorts = bothUdp;
      };
    };
}
