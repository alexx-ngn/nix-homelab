{ lib, config, ... }:
let
  cfg = config.modules.network.br0;
in
{
  options.modules.network.br0 = {
    enable = lib.mkEnableOption "br0 NetworkManager bridge for libvirt VMs";

    enslave = lib.mkOption {
      type = lib.types.str;
      description = "Physical interface to enslave to br0 (e.g. \"enp5s0\").";
    };

    wakeOnLan = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Wake-on-LAN (magic packet) on the enslaved interface.";
    };
  };

  config = lib.mkIf cfg.enable {
    networking.networkmanager.ensureProfiles.profiles = {
      "br0" = {
        connection = {
          id = "br0";
          type = "bridge";
          interface-name = "br0";
          autoconnect = true;
          autoconnect-priority = 10;
        };
        bridge = {
          stp = false;
        };
        ipv4.method = "auto";
        ipv6 = {
          addr-gen-mode = "stable-privacy";
          method = "auto";
        };
      };

      "br0-slave-${cfg.enslave}" = {
        connection = {
          id = "br0-slave-${cfg.enslave}";
          type = "ethernet";
          interface-name = cfg.enslave;
          master = "br0";
          slave-type = "bridge";
          autoconnect = true;
          autoconnect-priority = 5;
        };
        ethernet = lib.mkIf cfg.wakeOnLan {
          wake-on-lan = 32;
        };
      };
    };
  };
}
