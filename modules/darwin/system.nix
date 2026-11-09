{ pkgs, ... }:

{
  nixpkgs.config.allowUnfree = true;
  time.timeZone = "America/Toronto";
  nix.enable = false;

  system.primaryUser = "alex";

  security.pam.services.sudo_local.touchIdAuth = true;

  system.defaults = {
    dock.autohide = true;
    dock.persistent-apps = [
      "/Applications/Safari.app"
      "/Applications/Ghostty.app"
      "/Applications/Emacs.app"
      "/Applications/Termius.app"
    ];
    dock.wvous-tl-corner = 2;
    finder.FXPreferredViewStyle = "clmv";
    finder.AppleShowAllExtensions = true;
    NSGlobalDomain.AppleInterfaceStyle = "Dark";
    NSGlobalDomain.KeyRepeat = 2;
    screencapture.location = "~/Pictures/Screenshots";
    screencapture.target = "clipboard";
  };

  environment.shells = with pkgs; [ fish ];
  environment.variables = {
    EDITOR = "${pkgs.neovim}/bin/nvim";
  };

  users.users.alex = {
    home = "/Users/alex";
    shell = pkgs.fish;
  };
  programs.fish.enable = true;
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # GC is handled by Determinate Nix's built-in daemon (determinate-nixd),
  # which runs disk-pressure-based garbage collection automatically. nix-darwin's
  # nix.gc.automatic can't be used here (it asserts on nix.enable, which is off
  # because Determinate owns the daemon). Keep determinate-nixd up to date with
  # `sudo determinate-nixd upgrade`.
}
