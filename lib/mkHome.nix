{
  nixpkgs,
  home-manager,
  inputs,
  self,
}:

# Standalone Home Manager for Linux machines this flake doesn't own — no root,
# no NixOS (e.g. the school box, where Nix runs rootless under
# nix-user-chroot). The username and home directory come from the environment
# at eval time, so every switch needs --impure (the `sw` alias passes it);
# like /etc/nixos/hardware-configuration.nix, these machine-specific values
# stay out of git.
{
  name,
  hmModule,
  system ? "x86_64-linux",
}:

let
  fromEnv =
    var:
    let
      value = builtins.getEnv var;
    in
    if value == "" then throw "mkHome: ${var} is unset; evaluate with --impure" else value;
in
home-manager.lib.homeManagerConfiguration {
  pkgs = nixpkgs.legacyPackages.${system};
  # homeName tells `sw` which homeConfigurations entry to switch.
  extraSpecialArgs = {
    inherit inputs self;
    homeName = name;
  };
  modules = [
    hmModule
    {
      home.username = fromEnv "USER";
      home.homeDirectory = fromEnv "HOME";
      targets.genericLinux.enable = true;
    }
  ];
}
