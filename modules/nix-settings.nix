{ lib, inputs, ... }:
{
  nixpkgs = {
    config.allowUnfree = true;
    overlays = [ (import ../overlays/sops-install-secrets-go.nix) ];
  };

  nix =
    let
      flakeInputs = lib.filterAttrs (_: lib.isType "flake") inputs;
    in
    {
      settings = {
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        flake-registry = "";
        # When this host offloads a build to a remote builder (e.g.
        # nixos-anywhere --build-on remote, where an x86_64/darwin box drives an
        # aarch64-linux install), have the builder fetch dependencies from the
        # binary caches itself rather than receiving unsigned copies pushed over
        # SSH — the latter makes the builder reject paths with "lacks a
        # signature by a trusted key".
        builders-use-substitutes = true;
        # Let the interactive admin user push/copy unsigned store paths to the
        # local daemon (e.g. `nix copy`, nixos-anywhere). Without this a
        # non-trusted user hits "cannot add path … lacks a signature by a
        # trusted key". ci-deploy.nix adds `deploy` for CD; this covers `alex`.
        trusted-users = [
          "root"
          "@wheel"
        ];
        extra-substituters = [ "https://alex-infra.cachix.org" ];
        extra-trusted-public-keys = [
          "alex-infra.cachix.org-1:zIjukoiwUNlM9ZzDqjN9uDoPkrm9M6aANeRkbMIS1y8="
        ];
      };
      channel.enable = true;
      registry = lib.mapAttrs (_: flake: { inherit flake; }) flakeInputs;
      nixPath = lib.mapAttrsToList (n: _: "${n}=flake:${n}") flakeInputs;
    };
}
