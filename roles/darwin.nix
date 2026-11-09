{ inputs, ... }:

{
  imports = [
    ../modules/darwin/system.nix
    ../modules/darwin/packages.nix
    ../modules/darwin/homebrew.nix
    ../modules/darwin/fonts.nix
    ../modules/darwin/openssh.nix
    inputs.mac-app-util.darwinModules.default
    inputs.nix-homebrew.darwinModules.nix-homebrew
  ];
}
