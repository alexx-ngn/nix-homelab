# Static hardware profile for alexvps (Oracle Cloud Ampere A1, aarch64, UEFI).
#
# fileSystems / swap are intentionally absent — disko owns them
# (hosts/vps/disk-config.nix). This file only carries the boot-time module set
# and platform. The virtio set below covers Oracle's paravirtualized boot volume
# and NICs; nvme is included as a harmless fallback. After the first install you
# can replace this with `nixos-generate-config --show-hardware-config` output
# *with the fileSystems block stripped* if you want exact detection.
{ lib, ... }:
{
  boot.initrd.availableKernelModules = [
    "virtio_pci"
    "virtio_blk"
    "virtio_scsi"
    "virtio_net"
    "sd_mod"
    "sr_mod"
    "nvme"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
