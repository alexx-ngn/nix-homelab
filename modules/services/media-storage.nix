# Remote media storage for nixflix: an NFS mount of the NAS export, riding the
# wg-nas tunnel (defined in nas-wireguard.nix). media + downloads live on the
# share (one mount, so *arr hardlink imports stay instant); service state stays
# local (see modules/services/nixflix.nix). nixflix waits for the mount via
# nixflix.serviceDependencies.
#
# NFS over SMB: real POSIX ownership + reliable hardlinks (which *arr needs), and
# the WireGuard tunnel already gives us the auth/encryption that would be SMB's
# only edge.
{ ... }:
let
  nasIp = "10.0.0.11"; # NAS address reachable over the tunnel
  exportPath = "/mnt/tank/nas/sharepoint"; # NFS export path on the NAS
  mountPoint = "/mnt/storage";
in
{
  imports = [ ./nas-wireguard.nix ];

  # --- NFS mount of the NAS export (media + downloads live under here) ---
  # Declaring an `nfs` fileSystem auto-pulls nfs-utils + the nfs-client target
  # (filesystems.nix feeds each fsType into boot.supportedFilesystems, which the
  # nfs.nix module keys off) — no boot.supportedFilesystems / cifs-utils needed.
  fileSystems.${mountPoint} = {
    device = "${nasIp}:${exportPath}";
    fsType = "nfs";
    options = [
      "nfsvers=4.2" # single port (2049) over the tunnel; no rpcbind/statd/lockd
      "hard" # block + retry on NAS outage rather than corrupt a write
      "noatime"
      "_netdev"
      "nofail" # don't block boot if the NAS is unreachable
      "x-systemd.requires=wireguard-wg-nas.service"
      "x-systemd.after=wireguard-wg-nas.service"
      "x-systemd.mount-timeout=30"
    ];
  };
}
