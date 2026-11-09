# Declarative disk layout for alexvps (Oracle Cloud Ampere A1), applied by
# nixos-anywhere via disko. disko owns config.fileSystems, so
# hardware-configuration.nix must NOT declare any fileSystems entries.
#
# NOTE: `device` is the whole boot volume and WILL BE WIPED on install. Oracle's
# paravirtualized boot volume usually appears as /dev/sda — confirm with `lsblk`
# on the running Ubuntu instance before running nixos-anywhere and adjust if it
# differs (e.g. /dev/vda).
{
  disko.devices.disk.main = {
    device = "/dev/sda";
    type = "disk";
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
