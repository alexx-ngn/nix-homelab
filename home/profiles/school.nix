{ config, lib, ... }:
{
  imports = [ ./base.nix ];

  # /tmp is mounted noexec on the teaching nodes, which breaks every Nix build
  # (and the installer) with "Permission denied". Keep the build scratch dir in
  # $HOME instead.
  home.sessionVariables.TMPDIR = "${config.home.homeDirectory}/nix-tmp";

  # Shared, admin-controlled box (see homeConfigurations.school in flake.nix):
  # leave ~/.ssh/config alone rather than replacing the school's, and keep the
  # tailnet host list off a machine whose admins have root.
  programs.ssh.enable = lib.mkForce false;
}
