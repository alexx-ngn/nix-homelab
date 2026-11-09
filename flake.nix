{
  description = "Multi-device NixOS configuration with Home Manager for PC, Laptop, Thinkpad, and Server";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Declarative disk partitioning for alexvps; consumed by nixos-anywhere at
    # install time and owns the host's fileSystems thereafter.
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:LnL7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mac-app-util = {
      url = "github:hraban/mac-app-util";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lazyvim = {
      url = "github:pfassina/lazyvim-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixflix = {
      url = "github:kiriwalawren/nixflix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    terranix = {
      url = "github:terranix/terranix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Declarative libvirt domains. nixpkgs' own virtualisation.libvirtd only
    # configures the daemon — it has no way to define a domain — so alexpc's
    # VMs live here instead of as loose XML defined by hand.
    nixvirt = {
      url = "github:AshleyYakeley/NixVirt";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      sops-nix,
      deploy-rs,
      flake-parts,
      nix-darwin,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];

      perSystem =
        { pkgs, system, ... }:
        let
          # Declarative Cloudflare DNS (example.com) -> terraform JSON via terranix.
          dnsConfig = inputs.terranix.lib.terranixConfiguration {
            inherit system;
            modules = [ ./dns/cloudflare.nix ];
          };
          # `nix run .#dns -- plan|apply`. Decrypts the CF/R2 creds from
          # secrets/terraform.yaml, drops the generated config in a gitignored
          # workdir, then runs `tofu init` + the passed subcommand.
          dns = pkgs.writeShellApplication {
            name = "dns";
            runtimeInputs = with pkgs; [
              opentofu
              sops
              coreutils
              git
            ];
            text = ''
              root="$(git rev-parse --show-toplevel)"
              secrets="$root/secrets/terraform.yaml"
              work="$root/dns/.tofu"

              mkdir -p "$work"
              install -m644 ${dnsConfig} "$work/config.tf.json"

              CLOUDFLARE_API_TOKEN="$(sops -d --extract '["cloudflare"]["api_token"]' "$secrets")"
              AWS_ACCESS_KEY_ID="$(sops -d --extract '["cloudflare"]["r2_access_key_id"]' "$secrets")"
              AWS_SECRET_ACCESS_KEY="$(sops -d --extract '["cloudflare"]["r2_secret_access_key"]' "$secrets")"
              export CLOUDFLARE_API_TOKEN AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY

              cd "$work"
              echo "→ initializing state backend (Cloudflare R2)…" >&2
              tofu init -input=false >/dev/null
              exec tofu "$@"
            '';
          };
        in
        {
          devShells.default = pkgs.mkShell {
            buildInputs = with pkgs; [
              nixfmt-tree
              git
            ];
            # Use the tracked hooks so commits are auto-formatted (see .githooks/pre-commit).
            shellHook = ''
              git config core.hooksPath .githooks
            '';
          };
          apps.deploy-rs = deploy-rs.apps.${system}.default;
          apps.dns = {
            type = "app";
            program = "${dns}/bin/dns";
          };
          formatter = pkgs.nixfmt-tree;
          packages.deploy-rs = deploy-rs.packages.${system}.default;
          # `nix build .#dns-config` to inspect the generated terraform JSON.
          packages.dns-config = dnsConfig;
        };

      flake =
        let
          lib = nixpkgs.lib;

          mkHost = import ./lib/mkHost.nix {
            inherit
              nixpkgs
              home-manager
              sops-nix
              inputs
              self
              ;
          };
          mkDarwin = import ./lib/mkDarwin.nix {
            inherit
              nix-darwin
              home-manager
              inputs
              self
              ;
          };
          mkHome = import ./lib/mkHome.nix {
            inherit
              nixpkgs
              home-manager
              inputs
              self
              ;
          };

          # Single source of truth for the fleet: nixosConfigurations and
          # deploy.nodes are both derived from this attrset. Adding a host is
          # one entry here (plus its hosts/<name>/ directory).
          #   module — hosts/<name>/configuration.nix
          #   hm     — Home Manager profile
          #   system — defaults to x86_64-linux
          #   deploy — true = push via deploy-rs (`nix run .#deploy-rs -- .#<name>`)
          hosts = {
            alexpc = {
              module = ./hosts/pc/configuration.nix;
              hm = ./home/profiles/desktop.nix;
            };
            alexlaptop = {
              module = ./hosts/laptop/configuration.nix;
              hm = ./home/profiles/desktop.nix;
            };
            alexpad = {
              module = ./hosts/thinkpad/configuration.nix;
              hm = ./home/profiles/base.nix;
              deploy = true;
            };
            alexserver = {
              module = ./hosts/server/configuration.nix;
              hm = ./home/profiles/server.nix;
              deploy = true;
            };
            # Oracle Cloud free-tier Ampere A1 (aarch64). Installed via
            # nixos-anywhere; disko owns the disk layout (hosts/vps/disk-config.nix).
            alexvps = {
              module = ./hosts/vps/configuration.nix;
              hm = ./home/profiles/base.nix;
              system = "aarch64-linux";
              deploy = true;
            };
            alexwsl = {
              module = ./hosts/wsl/configuration.nix;
              hm = ./home/profiles/base.nix;
            };
            # Local AI inference guest: a libvirt domain on alexpc
            # (hosts/pc/vms/alexai.nix) with the RTX 4070 Super passed through,
            # running native services.llama-cpp. Its disk image is built from
            # this config by disko; not deploy-rs managed, rebuilt by hand via
            # ssh + the `sw` alias.
            alexai = {
              module = ./hosts/alexai/configuration.nix;
              hm = ./home/profiles/base.nix;
            };
          };
        in
        {
          nixosConfigurations = builtins.mapAttrs (
            _: host:
            mkHost {
              hostModule = host.module;
              hmModule = host.hm;
              system = host.system or "x86_64-linux";
            }
          ) hosts;

          darwinConfigurations = {
            alexmac = mkDarwin {
              hostModule = ./hosts/mac/configuration.nix;
              hmModule = ./home/profiles/base.nix;
            };
          };

          # Rootless Home Manager on the school Linux box (nix-user-chroot, no
          # sudo). `home-manager switch --impure --flake .#school`, or `sw`.
          homeConfigurations = {
            school = mkHome {
              name = "school";
              hmModule = ./home/profiles/school.nix;
            };
          };

          # CD: `nix run .#deploy-rs -- .#<host>` for every host flagged
          # `deploy = true` above. SSH is over tailnet MagicDNS; the runner
          # joins ephemerally via the Tailscale GH action. `magicRollback`
          # (deploy-rs default) reverts the activation if the post-switch
          # health check fails.
          deploy.nodes = lib.mapAttrs (name: host: {
            hostname = name;
            sudo = "sudo -n -u";
            profiles.system = {
              user = "root";
              sshUser = "deploy";
              path =
                deploy-rs.lib.${host.system or "x86_64-linux"}.activate.nixos
                  self.nixosConfigurations.${name};
            };
          }) (lib.filterAttrs (_: host: host.deploy or false) hosts);

          checks = builtins.mapAttrs (_: lib: lib.deployChecks self.deploy) deploy-rs.lib;
        };
    };
}
