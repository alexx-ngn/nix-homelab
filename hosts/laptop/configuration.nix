{ pkgs, ... }:
{
  imports = [
    /etc/nixos/hardware-configuration.nix
    ../../roles/laptop.nix
  ];

  networking.hostName = "alexlaptop";

  environment.systemPackages = with pkgs; [
    gnome-remote-desktop
    gnomeExtensions.eye-on-cursor
  ];

  systemd.services.gnome-remote-desktop.wantedBy = [ "graphical.target" ];
  services.gnome.gnome-remote-desktop.enable = true;

  networking.firewall.allowedTCPPorts = [ 3389 ];
  networking.firewall.allowedUDPPorts = [ 3389 ];
}
