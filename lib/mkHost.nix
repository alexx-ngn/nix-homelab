{
  nixpkgs,
  home-manager,
  sops-nix,
  inputs,
  self,
}:

{
  hostModule,
  hmModule,
  system ? "x86_64-linux",
}:

let
  specialArgs = { inherit inputs self; };
  inherit (import ./constants.nix) username;
in
nixpkgs.lib.nixosSystem {
  inherit system specialArgs;
  modules = [
    hostModule
    sops-nix.nixosModules.sops
    home-manager.nixosModules.home-manager
    {
      home-manager.useUserPackages = true;
      home-manager.users.${username} = hmModule;
      home-manager.extraSpecialArgs = specialArgs;
    }
  ];
}
