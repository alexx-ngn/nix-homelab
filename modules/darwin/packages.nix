{ pkgs, ... }:

{
  # GUI apps with built-in self-updaters (Sparkle/Squirrel/Keystone) are NOT
  # installed from nixpkgs — their bundles land in the read-only store, the
  # updater's in-place replace fails, and the app nags (or loops) forever.
  # Those live in modules/darwin/homebrew.nix as casks instead.
  environment.systemPackages = [
    pkgs.neovim
    pkgs.anki-bin
    pkgs.btop
    pkgs.direnv
    pkgs.fish
    pkgs.git
    pkgs.htop
    pkgs.magic-wormhole
    pkgs.mkalias
    pkgs.moonlight-qt
    pkgs.mpv
    pkgs.fastfetch
    pkgs.nodejs_24
    pkgs.nixfmt
    pkgs.nmap
    pkgs.ntfs3g
    pkgs.starship
    pkgs.tmux
    pkgs.wget
    pkgs.php
    pkgs.php84Packages.composer
    pkgs.tealdeer
    pkgs.yt-dlp
    pkgs.mas
    pkgs.mysql84
    pkgs.claude-code
    pkgs.codex
    pkgs.hledger
    pkgs.tailscale
    pkgs.gnupg
    pkgs.rclone
    pkgs.vencord
    pkgs.postgresql
    (pkgs.maven.override { jdk_headless = pkgs.javaPackages.compiler.temurin-bin.jdk-25; })
    pkgs.javaPackages.compiler.temurin-bin.jdk-25
    pkgs.ripgrep
    pkgs.fontconfig
    pkgs.fd
    pkgs.coreutils-prefixed
    pkgs.pandoc
    pkgs.shellcheck
    pkgs.act
    pkgs.orbstack
  ];
}
