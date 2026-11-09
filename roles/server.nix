let
  constants = import ../lib/constants.nix;
in
{
  imports = [
    ./common/managed.nix
    ../modules/services/sops.nix
    ../modules/services/docker.nix
    # media-storage.nix (remote NFS export over wg-nas) stays disabled — it hung
    # nixos-rebuild switch. nixflix now stores media + downloads on the local
    # `tank` pool (/tank/media), so it no longer needs the NFS mount.
    # ../modules/services/media-storage.nix
    ../modules/services/nixflix.nix
    ../modules/services/immich.nix
    ../modules/services/zfs-backup.nix
    ../modules/services/homepage-dashboard.nix
    ../modules/services/minecraft.nix
    ../modules/services/ddns.nix
  ];

  # Keeps ddns.example.com pointed at the home connection's current public IP;
  # service hostnames (mc) CNAME to it — see dns/cloudflare.nix.
  modules.ddns = {
    enable = true;
    domain = "ddns.${constants.domain}";
  };
}
