{
  config,
  pkgs,
  lib,
  inputs,
  # null under standalone Home Manager (lib/mkHome.nix), which passes homeName.
  osConfig ? null,
  homeName ? null,
  ...
}:
let
  isDarwin = pkgs.stdenv.isDarwin;
  switchCommand =
    if osConfig == null then
      ''home-manager switch --impure -b hm-backup --flake "$flake_root#${homeName}"''
    else if isDarwin then
      ''sudo darwin-rebuild switch --flake "$flake_root#${osConfig.networking.hostName}"''
    else
      ''sudo nixos-rebuild switch --impure --flake "$flake_root#${osConfig.networking.hostName}"'';
  geminiApiKeyPath = config.sops.secrets."gemini/api_key".path;
in
{
  imports = [
    ../users/alex.nix
    inputs.lazyvim.homeManagerModules.default
    inputs.sops-nix.homeManagerModules.sops
  ];

  nixpkgs = {
    config.allowUnfree = true;
    overlays = [ (import ../../overlays/sops-install-secrets-go.nix) ];
  };

  sops = lib.mkIf isDarwin {
    defaultSopsFile = ../../secrets/secrets.yaml;
    age.keyFile = "/Users/alex/Library/Application Support/sops/age/keys.txt";
    secrets."gemini/api_key" = { };
  };

  home.packages = with pkgs; [
    btop
    tree
    claude-code
    direnv
    fish
    gh
    git
    htop
    fastfetch
    nixfmt
    nmap
    sops
    starship
    tmux
    wget
    zellij
  ];

  programs.fish = {
    enable = true;
    functions = {
      sw = ''
        set -l flake_root

        if set -q INFRA_FLAKE
          set flake_root $INFRA_FLAKE
        end

        if test -z "$flake_root"
          set -l git_root (command git rev-parse --show-toplevel 2>/dev/null)
          if test -f "$git_root/flake.nix"; and test -f "$git_root/home/profiles/base.nix"; and test -f "$git_root/lib/mkHost.nix"
            set flake_root $git_root
          end
        end

        if test -z "$flake_root"; and set -q __infra_private_flake_root
          if test -f "$__infra_private_flake_root/flake.nix"; and test -f "$__infra_private_flake_root/home/profiles/base.nix"; and test -f "$__infra_private_flake_root/lib/mkHost.nix"
            set flake_root $__infra_private_flake_root
          end
        end

        if test -z "$flake_root"
          for search_root in "$HOME" /etc/nixos /mnt/etc/nixos
            if test -d "$search_root"
              for flake in (command find "$search_root" -maxdepth 6 -name flake.nix 2>/dev/null)
                set -l candidate (command dirname "$flake")
                if test -f "$candidate/home/profiles/base.nix"; and test -f "$candidate/lib/mkHost.nix"
                  set flake_root $candidate
                  set -g __infra_private_flake_root $flake_root
                  break
                end
              end
            end

            if test -n "$flake_root"
              break
            end
          end
        end

        if test -z "$flake_root"
          echo "sw: could not locate infra-private; run from inside the repo or set INFRA_FLAKE" >&2
          return 1
        end

        ${switchCommand}
      '';
    };
    interactiveShellInit = ''
      set fish_greeting
      starship init fish | source
    ''
    + lib.optionalString isDarwin ''
      set -Ux PATH $PATH $HOME/.pub-cache/bin $HOME/.config/emacs/bin

      # TERN BCMS local dev: admin connection for the DB reset script.
      # Postgres runs in OrbStack/Docker over TCP, so peer auth won't work.
      set -gx PGHOST localhost
      set -gx PGADMINUSER postgres
      # PGPASSWORD is a secret; keep it in this unmanaged, gitignored file.
      test -f $HOME/.config/fish/secrets.fish; and source $HOME/.config/fish/secrets.fish

      # sops-nix decrypts this user secret during Home Manager activation.
      if test -r "${geminiApiKeyPath}"
        set -gx GEMINI_API_KEY (cat "${geminiApiKeyPath}")
      end
    '';
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    # OrbStack maintains its own host list at ~/.orbstack/ssh/config; the
    # Include is harmless on hosts without the file (ssh skips missing
    # includes silently).
    includes = [ "~/.orbstack/ssh/config" ];
    settings = {
      "*" = {
        ControlMaster = "auto";
        ControlPath = "~/.ssh/cm-%r@%h:%p";
        ControlPersist = "10m";
        ServerAliveInterval = 60;
        SetEnv.TERM = "xterm-256color";
      };

      # NixOS flake hosts — all reachable over tailnet MagicDNS.
      alexserver = {
        HostName = "alexserver.tailnet-name.ts.net";
        User = "alex";
        IdentityFile = "~/.ssh/ci-deploy";
      };
      alexlaptop = {
        HostName = "alexlaptop.tailnet-name.ts.net";
        User = "alex";
      };
      alexpad = {
        HostName = "alexpad.tailnet-name.ts.net";
        User = "alex";
        IdentityFile = "~/.ssh/ci-deploy";
      };
      alexpc = {
        HostName = "alexpc.tailnet-name.ts.net";
        User = "alex";
      };
      alexvps = {
        HostName = "alexvps.tailnet-name.ts.net";
        User = "opc";
        IdentityFile = "~/.ssh/ci-deploy";
      };
      alexai = {
        HostName = "alexai.tailnet-name.ts.net";
        User = "alex";
      };

      # Out-of-flake hosts pinned here for convenience.
      alexpi = {
        HostName = "alexpi.tailnet-name.ts.net";
        User = "alex";
        IdentityFile = "~/.ssh/alexpi";
      };

      # Legacy device on the LAN that only speaks ssh-rsa host keys.
      "192.168.1.57" = {
        HostKeyAlgorithms = "+ssh-rsa";
        PubkeyAcceptedAlgorithms = "+ssh-rsa";
      };
    };
  };

  programs.starship.enable = true;

  programs.git = {
    enable = true;
    settings.user = {
      name = "alex";
      email = "49459824+alexx-ngn@users.noreply.github.com";
    };
  };

  # The lazyvim module enables programs.neovim; alias vi/vim onto it so muscle
  # memory lands in the configured editor (on non-NixOS this shadows the
  # distro's own vim via ~/.nix-profile/bin).
  programs.neovim = {
    viAlias = true;
    vimAlias = true;
  };

  programs.lazyvim = {
    enable = true;
    extras = {
      lang.nix.enable = true;
    };
  };

  # Avoid making a system rebuild depend on the current user's D-Bus session
  # being reloadable. Home Manager will still report user units that need a
  # manual restart.
  systemd.user.startServices = lib.mkIf pkgs.stdenv.isLinux "suggest";
}
