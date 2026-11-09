{ pkgs, ... }:
{
  imports = [
    /etc/nixos/hardware-configuration.nix
    ../../roles/workstation.nix
    ../../modules/hardware/amd.nix
    ../../modules/desktop/gpu-passthrough.nix
    ../../modules/network/br0.nix
    ./vms
  ];

  networking.hostName = "alexpc";

  modules.network.br0 = {
    enable = true;
    enslave = "enp5s0";
    wakeOnLan = true;
  };

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  environment.systemPackages = with pkgs; [
    noisetorch
    ddcutil
  ];

  programs.noisetorch.enable = true;
}
