{
  inputs,
  lib,
  modulesPath,
  ...
}:
{
  imports = [
    # Guest, not bare metal: alexai is a libvirt domain on alexpc holding the
    # RTX 4070 Super via VFIO (hosts/pc/vms/alexai.nix). Only one of alexai and
    # win11 can run at a time — they share the card.
    "${modulesPath}/profiles/qemu-guest.nix"
    inputs.disko.nixosModules.disko
    ./disk-config.nix
    ./hardware-configuration.nix
    ../../roles/ai-server.nix
  ];

  networking.hostName = "alexai";

  # disko's image builder runs the installer inside a VM with no EFI variable
  # store, so bootctl must not try to write one. systemd-boot still installs
  # the removable fallback (EFI/BOOT/BOOTX64.EFI), which is what OVMF boots.
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

  # Workaround for a disko/nixpkgs skew that breaks `diskoImagesScript`:
  # disko hands `pkgs.aggregateModules [...]` to vmTools as its `kernel`, but
  # aggregateModules drops the kernel's `target` passthru and nixpkgs now
  # requires it ("the `kernel` argument (kernel-modules) has no `target`
  # attribute"). Re-attach it from the real kernel derivation. Drop this once
  # disko passes extra modules via `kernelModules` instead.
  nixpkgs.overlays = [
    (_final: prev: {
      aggregateModules =
        modules: (prev.aggregateModules modules) // { inherit (builtins.head modules) target; };
    })
  ];
}
