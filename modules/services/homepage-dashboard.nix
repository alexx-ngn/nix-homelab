{ config, ... }:
let
  port = 8082; # NixOS module default; kept explicit so the firewall rule lines up.
  # Cloudflare tunnel ID — mirrors the one in modules/services/cloudflared.nix.
  tunnelId = "1d22a475-17e3-4c86-a86c-217aa5f9be97";

  # Per-credential mapping: Homepage placeholder name -> sops secret path.
  # Reused via systemd LoadCredential below so the homepage-dashboard unit (which
  # runs with DynamicUser=true) can read the existing root-owned 0400 secrets
  # without us having to duplicate values into a homepage-only env blob.
  secretSources = {
    jellyfin_api_key = config.sops.secrets."jellyfin/api_key".path;
    sonarr_api_key = config.sops.secrets."sonarr/api_key".path;
    sonarr_anime_api_key = config.sops.secrets."sonarr-anime/api_key".path;
    radarr_api_key = config.sops.secrets."radarr/api_key".path;
    prowlarr_api_key = config.sops.secrets."prowlarr/api_key".path;
    qbittorrent_password = config.sops.secrets."qbittorrent/password".path;
    cf_account_id = config.sops.secrets."cloudflare/account_id".path;
    cf_api_token = config.sops.secrets."cloudflare/api_token".path;
  };
in
{
  # New secrets unique to Homepage (everything else is reused from nixflix.nix).
  # restartUnits ensures the service picks up rotated values on the next switch.
  sops.secrets."cloudflare/account_id".restartUnits = [ "homepage-dashboard.service" ];
  sops.secrets."cloudflare/api_token".restartUnits = [ "homepage-dashboard.service" ];

  # Have the existing nixflix-owned secrets also bounce homepage when they rotate.
  # (The base sops.secrets."*" = { } declarations live in modules/services/nixflix.nix;
  # this only extends restartUnits — module merging makes the union.)
  sops.secrets."jellyfin/api_key".restartUnits = [ "homepage-dashboard.service" ];
  sops.secrets."sonarr/api_key".restartUnits = [ "homepage-dashboard.service" ];
  sops.secrets."sonarr-anime/api_key".restartUnits = [ "homepage-dashboard.service" ];
  sops.secrets."radarr/api_key".restartUnits = [ "homepage-dashboard.service" ];
  sops.secrets."prowlarr/api_key".restartUnits = [ "homepage-dashboard.service" ];
  sops.secrets."qbittorrent/password".restartUnits = [ "homepage-dashboard.service" ];

  # Load each sops secret as a systemd credential, then expose its in-sandbox
  # path to Homepage via HOMEPAGE_FILE_*. Homepage reads the file at request
  # time and substitutes its contents wherever {{HOMEPAGE_FILE_<NAME>}} appears
  # in the rendered YAML — values never enter the Nix store or env-var space.
  systemd.services.homepage-dashboard = {
    serviceConfig.LoadCredential = builtins.map (n: "${n}:${secretSources.${n}}") (
      builtins.attrNames secretSources
    );
    environment = {
      HOMEPAGE_FILE_JELLYFIN_API_KEY = "%d/jellyfin_api_key";
      HOMEPAGE_FILE_SONARR_API_KEY = "%d/sonarr_api_key";
      HOMEPAGE_FILE_SONARR_ANIME_API_KEY = "%d/sonarr_anime_api_key";
      HOMEPAGE_FILE_RADARR_API_KEY = "%d/radarr_api_key";
      HOMEPAGE_FILE_PROWLARR_API_KEY = "%d/prowlarr_api_key";
      HOMEPAGE_FILE_QBITTORRENT_PASSWORD = "%d/qbittorrent_password";
      HOMEPAGE_FILE_CF_ACCOUNT_ID = "%d/cf_account_id";
      HOMEPAGE_FILE_CF_API_TOKEN = "%d/cf_api_token";
    };
  };

  services.homepage-dashboard = {
    enable = true;
    listenPort = port;
    openFirewall = false; # tailnet-only rule below
    allowedHosts = "alexserver:${toString port},localhost:${toString port},127.0.0.1:${toString port}";

    settings = {
      title = "alexserver";
      theme = "dark";
      headerStyle = "clean";
    };

    services = [
      {
        Media = [
          {
            Jellyfin = {
              href = "http://alexserver:8096";
              icon = "jellyfin.svg";
              widget = {
                type = "jellyfin";
                url = "http://alexserver:8096";
                key = "{{HOMEPAGE_FILE_JELLYFIN_API_KEY}}";
                enableBlocks = true;
                enableNowPlaying = true;
              };
            };
          }
          {
            Sonarr = {
              href = "http://alexserver:8989";
              icon = "sonarr.svg";
              widget = {
                type = "sonarr";
                url = "http://alexserver:8989";
                key = "{{HOMEPAGE_FILE_SONARR_API_KEY}}";
              };
            };
          }
          {
            "Sonarr Anime" = {
              href = "http://alexserver:8990";
              icon = "sonarr.svg";
              widget = {
                type = "sonarr";
                url = "http://alexserver:8990";
                key = "{{HOMEPAGE_FILE_SONARR_ANIME_API_KEY}}";
              };
            };
          }
          {
            Radarr = {
              href = "http://alexserver:7878";
              icon = "radarr.svg";
              widget = {
                type = "radarr";
                url = "http://alexserver:7878";
                key = "{{HOMEPAGE_FILE_RADARR_API_KEY}}";
              };
            };
          }
          {
            Prowlarr = {
              href = "http://alexserver:9696";
              icon = "prowlarr.svg";
              widget = {
                type = "prowlarr";
                url = "http://alexserver:9696";
                key = "{{HOMEPAGE_FILE_PROWLARR_API_KEY}}";
              };
            };
          }
          {
            qBittorrent = {
              href = "http://alexserver:8282";
              icon = "qbittorrent.svg";
              widget = {
                type = "qbittorrent";
                url = "http://alexserver:8282";
                username = "admin";
                password = "{{HOMEPAGE_FILE_QBITTORRENT_PASSWORD}}";
              };
            };
          }
        ];
      }
      {
        System = [
          {
            "Cloudflare Tunnel" = {
              icon = "cloudflare.svg";
              widget = {
                type = "cloudflared";
                accountid = "{{HOMEPAGE_FILE_CF_ACCOUNT_ID}}";
                tunnelid = tunnelId;
                key = "{{HOMEPAGE_FILE_CF_API_TOKEN}}";
              };
            };
          }
        ];
      }
    ];

    widgets = [
      {
        resources = {
          cpu = true;
          memory = true;
          disk = "/";
        };
      }
      {
        resources = {
          disk = "/tank/media"; # local nixflix media dataset (tank/media)
          label = "Media";
        };
      }
      {
        datetime = {
          format = {
            dateStyle = "short";
            timeStyle = "short";
          };
        };
      }
    ];

    bookmarks = [
      {
        Hosts = [
          { alexpc = [ { href = "http://alexpc"; } ]; }
          { alexlaptop = [ { href = "http://alexlaptop"; } ]; }
          { alexpad = [ { href = "http://alexpad"; } ]; }
        ];
      }
      {
        Admin = [
          { Tailscale = [ { href = "https://login.tailscale.com/admin"; } ]; }
          { Cloudflare = [ { href = "https://dash.cloudflare.com"; } ]; }
        ];
      }
    ];
  };

  # Tailnet-only exposure — merges with the list in modules/services/nixflix.nix.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ port ];
}
