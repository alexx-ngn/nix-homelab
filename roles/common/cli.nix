# Shared CLI baseline every NixOS host imports (directly or via
# common/managed.nix): core system config, the alex user, ssh, and fish.
# Keep this to what genuinely every host needs — role deltas live in the roles.
{
  imports = [
    ../../modules/base.nix
    ../../modules/nix-settings.nix
    ../../modules/security/user-alex.nix
    ../../modules/services/openssh.nix
    ../../modules/programs/fish-shell.nix
  ];
}
