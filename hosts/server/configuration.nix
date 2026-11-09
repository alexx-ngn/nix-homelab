{ pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../roles/server.nix
    ../../modules/services/nas-server.nix
    ../../modules/hardware/nvidia.nix
  ];

  # Hardware detection (kernel modules, microcode, hostPlatform, virtio bits)
  # comes from facter.json. fileSystems / swap / boot.loader live in
  # hardware-configuration.nix above — facter deliberately does not touch those.
  hardware.facter.reportPath = ./facter.json;

  networking.hostName = "alexserver";
  # Required by ZFS (below). Any stable 8 hex chars unique to this host.
  networking.hostId = "a1e75e72";

  # --- ZFS: local mirrors "tank" (HDD) and "ssd" (SSD) were created out-of-band;
  # NixOS imports them. ---
  # Dataset mountpoints (e.g. tank/nas -> /mnt/tank/nas) come from `zfs set
  # mountpoint=...` on the dataset itself — no fileSystems entry needed here.
  #
  # Hot service state lives on the SSD mirror via datasets mounted at the
  # canonical /var/lib paths — mountpoints set on the datasets, so no Nix dataDir
  # overrides and NixOS keeps owning each path's contents:
  #   ssd/postgresql -> /var/lib/postgresql   (PG; currently Immich only, + arr
  #                                            DBs once nixflix is re-enabled)
  # Pending — create before re-enabling nixflix (see roles/server.nix) so the
  # arr dirs are born on the SSD with no migration:
  #   ssd/arr/sonarr       -> /var/lib/sonarr
  #   ssd/arr/sonarr-anime -> /var/lib/sonarr-anime   } arr config + SQLite DBs
  #   ssd/arr/radarr       -> /var/lib/radarr
  #   ssd/arr/prowlarr     -> /var/lib/prowlarr
  # No explicit ordering needed: zfs-mount.service runs before local-fs.target,
  # so every ssd dataset is mounted before postgresql/the arr units start at
  # multi-user.target.
  #
  # Pin the LTS 6.18 kernel so the running kernel stays in lockstep with what
  # zfs_2_4 in this nixpkgs targets. Without an explicit pin the default
  # kernel can drift ahead of OpenZFS support between rebuilds.
  boot.kernelPackages = pkgs.linuxPackages_6_18;
  boot.supportedFilesystems = [ "zfs" ];
  boot.kernelModules = [ "zfs" ];
  boot.zfs.forceImportRoot = false;
  boot.zfs.extraPools = [
    "tank"
    "ssd"
  ];

  services.zfs = {
    autoScrub = {
      enable = true;
      interval = "weekly";
    };
    trim.enable = true;
    # Datasets opt-in via `zfs set com.sun:auto-snapshot=true <ds>`; set on the
    # `tank` and `ssd` pool roots so all children inherit. Retention pinned below
    # (snapshots kept per cadence): 4x15min + 24h + 7d + 4w + 12mo.
    autoSnapshot = {
      enable = true;
      frequent = 4; # every 15 min, keep 4 (1h of sub-hour granularity)
      hourly = 24;
      daily = 7;
      weekly = 4;
      monthly = 12;
    };
    # No SMTP on this host yet; flip enableMail + ZED_EMAIL_ADDR later.
    zed.settings = {
      ZED_NOTIFY_VERBOSE = true;
    };
  };

  # Headless server: ssh reachable on the LAN (192.168.1.10) for recovery,
  # not only via tailnet.
  modules.openssh.lanAccess = true;

  # No interface-name binding: the profile matches whatever the single wired
  # device is, so it survives NIC renames (ens18 -> ens19/enp.. etc.) when the
  # virtual hardware layout changes. Static IP is network topology, not hardware.
  networking.networkmanager.ensureProfiles.profiles."lan-static" = {
    connection = {
      id = "lan-static";
      type = "ethernet";
      autoconnect = true;
      autoconnect-priority = 10;
    };
    ipv4 = {
      method = "manual";
      address1 = "192.168.1.10/24,192.168.1.1";
      dns = "192.168.1.1;1.1.1.1;";
    };
    ipv6 = {
      method = "auto";
      addr-gen-mode = "stable-privacy";
    };
  };

}
