{ pkgs, ... }:

{
  nix-homebrew.autoMigrate = true;
  nix-homebrew = {
    enable = true;
    enableRosetta = true;
    user = "alex";
  };

  homebrew = {
    enable = true;
    taps = [
      "d12frosted/emacs-plus"
    ];
    # Self-updating GUI apps belong here, not in modules/darwin/packages.nix —
    # a nix-store bundle is read-only, so their updaters fail in place.
    casks = [
      "github"
      "claude"
      "codex-app"
      "discord"
      "google-chrome"
      "spotify"
      "visual-studio-code"
      "obsidian"
      "raycast"
      "slack"
      "intellij-idea"
      "clion"
      "tailscale-app"
      "termius"
      "microsoft-office"
      "postman"
      "linearmouse"
      "ghostty"
      "parsec"
      "steam"
      "signal"
      "notunes"
      "vibe-notch"
      "thaw"
      {
        name = "d12frosted/emacs-plus/emacs-plus-app";
        trusted = true;
      }
    ];
    masApps = {
    };
    onActivation = {
      cleanup = "zap";
      autoUpdate = true;
      upgrade = true;
    };
  };
}
