# Declarative disk layout for the alexai guest. Owns config.fileSystems, so
# hardware-configuration.nix must NOT declare any fileSystems entries.
#
# Unlike alexvps (installed onto a live disk by nixos-anywhere), this layout is
# consumed by disko's image builder:
#
#   nix build .#nixosConfigurations.alexai.config.system.build.diskoImagesScript
#   sudo ./result --build-memory 2048
#
# which produces main.raw — convert it and drop it where the domain expects it:
#
#   qemu-img convert -O qcow2 main.raw /var/lib/libvirt/images/alexai.qcow2
#
# `imageSize` is the virtual size only; the qcow2 stays sparse. Models live in
# /var/lib/llama-models (see modules/services/llama-cpp.nix), so size this for
# however many GGUFs you want resident.
{
  disko.devices.disk.main = {
    device = "/dev/vda";
    type = "disk";
    imageSize = "100G";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "512M";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };
}
