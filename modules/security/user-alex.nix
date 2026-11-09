{ lib, config, ... }:
{
  imports = [ ./ssh.nix ];

  users.users.alex = {
    isNormalUser = true;
    description = lib.mkDefault "alex";

    # Generate with: mkpasswd -m sha-512
    # TODO: move to sops (see modules/security/user-alex sops branch).
    hashedPassword = "$6$2NVzMybi46zqDn7y$Yv13AnSYzdGPPYQ6xgpV4fJ/1dFuyBrTdViD0Y60TLEWDmV9aDJboeWmrVGU2G9E8D3BuUO7p0lBYCI5mx57Z1";

    extraGroups = [
      "wheel"
      "networkmanager"
    ]
    ++ lib.optionals config.virtualisation.libvirtd.enable [ "libvirtd" ]
    ++ lib.optionals config.services.pipewire.enable [ "audio" ]
    ++ lib.optionals config.services.xserver.enable [ "input" ];
  };

  security.sudo.enable = false;
  security.sudo-rs.enable = true;
}
