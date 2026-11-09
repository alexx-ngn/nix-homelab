# Stripped from `nixos-generate-config` output: only fileSystems + swap remain.
# Kernel modules, hostPlatform, and microcode are provided by facter.json
# (see hardware.facter.reportPath in configuration.nix).
{
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/9b1a8252-6a6b-4b82-a5b2-50a6f800624c";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/4075-38EB";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  swapDevices = [ ];
}
