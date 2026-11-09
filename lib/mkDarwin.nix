{
  nix-darwin,
  home-manager,
  inputs,
  self,
}:

{
  hostModule,
  hmModule,
  system ? "aarch64-darwin",
}:

let
  specialArgs = { inherit inputs self; };
  inherit (import ./constants.nix) username;
in
nix-darwin.lib.darwinSystem {
  inherit specialArgs;
  modules = [
    hostModule
    home-manager.darwinModules.home-manager
    {
      nixpkgs.hostPlatform = system;
      home-manager.useUserPackages = true;
      home-manager.users.${username} = hmModule;
      home-manager.extraSpecialArgs = specialArgs;
      home-manager.backupFileExtension = "hm-backup";
    }
  ];
}
