{ pkgs, ... }:
{
  imports = [ ./base.nix ];

  home.packages = [ pkgs.filebot ];
}
