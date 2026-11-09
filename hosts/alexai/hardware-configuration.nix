# Static hardware profile for alexai (libvirt/q35 guest on alexpc, UEFI).
#
# fileSystems / swap are intentionally absent — disko owns them
# (hosts/alexai/disk-config.nix). Because the guest's virtual hardware is
# itself declared (hosts/pc/vms/alexai.nix), this file can be written rather
# than detected: virtio disk, virtio net, and the SATA/cdrom fallbacks.
#
# The passed-through RTX 4070 Super is handled by the role, not here —
# see modules/hardware/nvidia-rtx4070.nix.
{ lib, ... }:
{
  boot.initrd.availableKernelModules = [
    "virtio_pci"
    "virtio_blk"
    "virtio_scsi"
    "virtio_net"
    "ahci"
    "sd_mod"
    "sr_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
