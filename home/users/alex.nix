{ pkgs, lib, ... }:
{
  # mkDefault: standalone homes (lib/mkHome.nix) take these from the environment.
  home.username = lib.mkDefault "alex";
  home.homeDirectory = lib.mkDefault (if pkgs.stdenv.isDarwin then "/Users/alex" else "/home/alex");
  home.stateVersion = "25.05";
  programs.home-manager.enable = true;
}
