{ pkgs, ... }:
{
  imports = [
    ./common/cli.nix
    ../modules/services/tailscale.nix
    ../modules/services/docker.nix
    ../modules/services/libvirtd.nix
    ../modules/desktop/gnome.nix
    ../modules/programs/chromium.nix
    ../modules/programs/firefox-librewolf.nix
  ];

  boot.kernelPackages = pkgs.linuxPackages_zen;
  powerManagement.cpuFreqGovernor = "schedutil";
}
