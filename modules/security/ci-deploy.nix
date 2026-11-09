{ pkgs, ... }:
# CI deploy entry point for deploy-rs. Imported only by roles that accept
# automated deploys so other hosts don't carry the deploy SSH key, sudo grant,
# or nix-daemon trust for the CI account.
let
  # GitHub Actions deploy public key. Private half lives in the
  # `DEPLOY_SSH_KEY` repo secret.
  ciDeployPubKey = "ssh-ed25519 AAAA_REPLACE_WITH_YOUR_PUBLIC_KEY github-actions deploy";
in
{
  users.groups.deploy = { };

  users.users = {
    deploy = {
      isSystemUser = true;
      group = "deploy";
      home = "/var/lib/deploy";
      createHome = true;
      shell = pkgs.bashInteractive;
      openssh.authorizedKeys.keys = [ ciDeployPubKey ];
    };
  };

  # Trusted nix users bypass signature verification when receiving paths via
  # `nix copy --to ssh://…`. Without this the daemon rejects the unsigned
  # closure the CI runner produces with "lacks a signature by a trusted key".
  nix.settings.trusted-users = [ "deploy" ];

  # deploy-rs invokes the sudo command for the activation wrapper and, when
  # magicRollback is enabled, for the post-activation canary cleanup. NixOS'
  # sudo-rs module provides the sudo command through a setuid wrapper.
  #
  #   sudo -u root /nix/store/<hash>-activatable-.../activate-rs ...
  #   sudo -u root rm /tmp/deploy-rs-canary-...
  #
  # sudo-rs allows the activate-rs command-path glob, but does not allow
  # wildcards in command arguments. The canary filename includes the target
  # closure hash, so the rm rule must allow arbitrary arguments.
  security.sudo-rs.extraRules = [
    {
      users = [ "deploy" ];
      commands = [
        {
          command = "/nix/store/*-activatable-*/activate-rs";
          options = [
            "NOPASSWD"
            "SETENV"
          ];
        }
        {
          command = "/run/current-system/sw/bin/rm";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}
