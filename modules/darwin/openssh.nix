# Apple's built-in sshd, enabled declaratively (nix-darwin bootstraps
# /System/Library/LaunchDaemons/ssh.plist rather than shelling out to
# `systemsetup -setremotelogin`, which would need Full Disk Access).
#
# ../security/ssh.nix is shared with the NixOS hosts: the
# `users.users.alex.openssh.authorizedKeys.keys` option exists on both, so the
# same key list lands in /etc/ssh/nix_authorized_keys.d/alex here.
{
  imports = [ ../security/ssh.nix ];

  services.openssh = {
    enable = true;

    # Same posture as modules/services/openssh.nix on the NixOS hosts. Written
    # to /etc/ssh/sshd_config.d/100-nix-darwin.conf, which Apple's sshd_config
    # includes before its own defaults.
    extraConfig = ''
      PermitRootLogin no
      PasswordAuthentication no
      KbdInteractiveAuthentication no
    '';
  };
}
