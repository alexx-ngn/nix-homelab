{ lib, ... }:
{
  networking.networkmanager.enable = true;

  systemd.services.NetworkManager-wait-online = {
    enable = false;
    wantedBy = lib.mkForce [ ];
  };

  time.timeZone = "America/Toronto";
  i18n.defaultLocale = "en_CA.UTF-8";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  system.stateVersion = "25.05";
}
