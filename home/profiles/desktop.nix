{ pkgs, lib, ... }:
{
  imports = [ ./base.nix ];

  nixpkgs = {
    overlays = [
      (final: prev: {
        gns3-server = prev.gns3-server.overrideAttrs (oldAttrs: {
          doCheck = false;
        });
        termius = prev.termius.overrideAttrs (oldAttrs: {
          buildInputs = (oldAttrs.buildInputs or [ ]) ++ [ prev.sqlite ];
        });
      })
    ];
    config = {
      android_sdk.accept_license = true;
      allowUnfreePredicate = _: true;
    };
  };

  home.packages = with pkgs; [
    anki-bin
    chromium
    google-chrome
    dconf2nix
    ddcutil
    ghostty
    github-desktop
    gnome-browser-connector
    gnomeExtensions.blur-my-shell
    gnomeExtensions.ip-finder
    gnomeExtensions.dash-to-dock
    jetbrains-toolbox
    jetbrains-mono
    jetbrains.idea
    jetbrains.phpstorm
    jetbrains.webstorm
    gns3-gui
    vista-fonts
    corefonts
    magic-wormhole
    moonlight-qt
    mpv
    nfs-utils
    ntfs3g
    onlyoffice-desktopeditors
    parsec-bin
    pavucontrol
    php
    php84Packages.composer
    powertop
    postman
    qemu
    qbittorrent
    spotify
    syncthing
    termius
    usbutils
    vesktop
    virt-manager
    vscode
    whitesur-cursors
    whitesur-gtk-theme
    whitesur-icon-theme
    wireguard-tools
  ];

  programs.fish.interactiveShellInit = lib.mkAfter ''
    set -l nix_shell_info (
      if test -n "$IN_NIX_SHELL"
        echo -n "<nix-shell> "
      end
    )
  '';

  programs.librewolf = {
    enable = true;
    settings = {
      "webgl.disabled" = false;
      "privacy.resistFingerprinting" = false;
      "privacy.clearOnShutdown.history" = false;
      "privacy.clearOnShutdown.cookies" = false;
      "network.cookie.lifetimePolicy" = 0;
    };
  };

  programs.ghostty = {
    enable = true;
    settings = {
      font-family = "JetBrains Mono";
      theme = "MaterialDarker";
    };
  };

  dconf = {
    enable = true;
    settings = {
      "org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
        cursor-theme = "WhiteSur-cursors";
        gtk-theme = "WhiteSur-Dark";
        icon-theme = "WhiteSur-dark";
      };
      "org/gnome/desktop/input-sources" = {
        sources = [
          (lib.hm.gvariant.mkTuple [
            "xkb"
            "us"
          ])
          (lib.hm.gvariant.mkTuple [
            "xkb"
            "ca+fr"
          ])
        ];
        xkb-options = [ "terminate:ctrl_alt_bksp" ];
      };
      "org/gnome/shell" = {
        disable-user-extensions = false;
        enabled-extensions = [
          "blur-my-shell@aunetx"
          "Ip-Finder@LinxGem33"
          "user-theme@gnome-shell-extensions.gcampax.github.com"
          "dash-to-dock@micxgx.gmail.com"
        ];
        favorite-apps = [
          "chromium-browser.desktop"
          "com.mitchellh.ghostty.desktop"
          "nautilus.desktop"
          "code.desktop"
          "virt-manager.desktop"
          "spotify.desktop"
          "vesktop.desktop"
        ];
      };
      "org/gnome/shell/extensions/blur-my-shell" = {
        brightness = 0.75;
        noise-amount = 0;
      };
      "org/gnome/shell/extensions/user-theme" = {
        name = "WhiteSur-Dark";
      };
      "org/gnome/desktop/wm/keybindings" = {
        close = [ "<Super>q" ];
        switch-input-source = [ "<Alt>space" ];
        switch-input-source-backward = [ "<Shift><Alt>space" ];
      };
      "org/gnome/settings-daemon/plugins/media-keys" = {
        custom-keybindings = [
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/"
        ];
      };
      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
        name = "Ghostty";
        command = "ghostty";
        binding = "<Super><Shift>Return";
      };
      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
        name = "Chromium";
        command = "chromium";
        binding = "<Super><Shift>w";
      };
      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2" = {
        name = "Nautilus";
        command = "nautilus";
        binding = "<Super><Shift>e";
      };
      "org/gnome/desktop/wm/preferences" = {
        button-layout = ":minimize,maximize,close";
      };
      "org/gnome/system/location" = {
        enabled = true;
      };
      "org/gnome/settings-daemon/plugins/color" = {
        night-light-enabled = true;
        night-light-schedule-automatic = true;
        night-light-temperature = "uint32 3333";
      };
      "org/gnome/mutter" = {
        experimental-features = [ "scale-monitor-framebuffer" ];
      };
      "org/gnome/mutter/wayland" = {
        xwayland-allow-grabs = true;
        xwayland-grab-access-rules = [ "parsecd" ];
      };
      "org/virt-manager/virt-manager/connections" = {
        autoconnect = [ "qemu:///system" ];
        uris = [ "qemu:///system" ];
      };
      "org/gnome/desktop/remote-desktop/rdp" = {
        screen-share-mode = "extend";
      };
    };
  };
}
