{
  config,
  pkgs,
  inputs,
  ...
}:
let
  # nixflix's prowlarr-{indexers,applications,tags,indexer-proxies} oneshots only
  # order themselves after prowlarr-config/-tags, not after prowlarr.service. When
  # Prowlarr restarts during a switch while those oneshots stay active, they race a
  # dead API (curl exit 7) and fail the whole rebuild. Gate each on Prowlarr's
  # unauthenticated /ping so they wait for the API to actually answer.
  waitForProwlarr = pkgs.writeShellScript "wait-for-prowlarr" ''
    url="http://${config.nixflix.prowlarr.connectionAddress}:${toString config.nixflix.prowlarr.config.hostConfig.port}${config.nixflix.prowlarr.config.hostConfig.urlBase}/ping"
    for _ in $(seq 1 150); do
      ${pkgs.curl}/bin/curl -sf -o /dev/null "$url" && exit 0
      sleep 1
    done
    echo "Prowlarr API at $url not reachable after 150s" >&2
    exit 1
  '';
in
{
  imports = [ inputs.nixflix.nixosModules.default ];

  sops.secrets = {
    "sonarr/api_key" = { };
    "sonarr/password" = { };
    "sonarr-anime/api_key" = { };
    "sonarr-anime/password" = { };
    "radarr/api_key" = { };
    "radarr/password" = { };
    "prowlarr/api_key" = { };
    "prowlarr/password" = { };
    "jellyfin/api_key" = { };
    "jellyfin/admin_password" = { };
    "jellyfin/friend_password" = { };
    "wireguard/conf" = { }; # wg-quick .conf from the VPN provider
    "qbittorrent/password" = { }; # password the arr services use to reach qbt
  };

  nixflix = {
    enable = true;

    # media + downloads live on a single local ZFS dataset (tank/media -> the
    # media/ and downloads/ subdirs below) so *arr hardlink imports stay instant;
    # state stays local on the SSD (DBs over a network share are slow/risky).
    # No serviceDependencies / mnt-storage.mount gating: the `tank` pool is
    # imported at boot (boot.zfs.extraPools) and zfs-mount.service runs before
    # local-fs.target, so /tank/media is mounted before these units start.
    mediaDir = "/tank/media/media";
    downloadsDir = "/tank/media/downloads";
    stateDir = "/var/lib";
    mediaUsers = [ "alex" ];

    postgres.enable = true;

    # TRaSH-guide quality profiles / custom formats for every enabled instance:
    # sonarr -> WEB-1080p, radarr -> SQP-1080p, sonarr-anime -> Anime Remux-1080p
    # (grabs WEB simulcasts now, upgrades to BD remux later). Prunes unmanaged CFs.
    recyclarr.enable = true;
    recyclarr.cleanupUnmanagedProfiles.enable = true;
    recyclarr.config.sonarr.sonarr_anime.custom_formats = [
      {
        trash_ids = [ "3bc5f395426614e155e585a2f056cdf1" ]; # Season Pack
        assign_scores_to = [
          {
            trash_id = "20e0fc959f1f1704bed501f23bdae76f"; # [Anime] Remux-1080p
            score = 10;
          }
        ];
      }
      {
        trash_ids = [ "c9eafd50846d299b862ca9bb6ea91950" ]; # x265 (non-remux WEB releases)
        assign_scores_to = [
          {
            trash_id = "20e0fc959f1f1704bed501f23bdae76f"; # [Anime] Remux-1080p
            score = 100;
          }
        ];
      }
    ];

    sonarr.enable = true;
    sonarr.config = {
      apiKey._secret = config.sops.secrets."sonarr/api_key".path;
      hostConfig.password._secret = config.sops.secrets."sonarr/password".path;
    };

    # Dedicated anime instance (absolute episode numbering). Defaults give it
    # port 8990 and root folder ${mediaDir}/anime; Prowlarr registers it as
    # "Sonarr Anime" and qBittorrent gets a "sonarr-anime" category automatically.
    sonarr-anime.enable = true;
    sonarr-anime.config = {
      apiKey._secret = config.sops.secrets."sonarr-anime/api_key".path;
      hostConfig.password._secret = config.sops.secrets."sonarr-anime/password".path;
      mediaManagement = {
        episodeTitleRequired = "never"; # anime titles are often TBA
        importExtraFiles = true;
        extraFileExtensions = "srt,ass,ssa"; # external subs common for anime
      };
    };

    radarr.enable = true;
    radarr.config = {
      apiKey._secret = config.sops.secrets."radarr/api_key".path;
      hostConfig.password._secret = config.sops.secrets."radarr/password".path;
    };

    # Headless Cloudflare solver (127.0.0.1:8191). nixflix auto-registers it as a
    # Prowlarr indexer proxy tagged "flaresolverr"; tag an indexer with the same
    # tag to route it through the solver (see Anidex below).
    flaresolverr.enable = true;

    prowlarr.enable = true;
    prowlarr.config = {
      apiKey._secret = config.sops.secrets."prowlarr/api_key".path;
      hostConfig.password._secret = config.sops.secrets."prowlarr/password".path;
      # Keep anime tracker sync isolated to the anime Sonarr instance. Prowlarr's
      # Sonarr defaults include both regular TV categories and TV/Anime, so make
      # the category split explicit here.
      applications = [
        {
          name = "Radarr";
          implementationName = "Radarr";
          apiKey._secret = config.sops.secrets."radarr/api_key".path;
          baseUrl = "http://${config.nixflix.radarr.connectionAddress}:${toString config.nixflix.radarr.config.hostConfig.port}${config.nixflix.radarr.config.hostConfig.urlBase}";
          prowlarrUrl = "http://${config.nixflix.prowlarr.connectionAddress}:${toString config.nixflix.prowlarr.config.hostConfig.port}${config.nixflix.prowlarr.config.hostConfig.urlBase}";
        }
        {
          name = "Sonarr";
          implementationName = "Sonarr";
          apiKey._secret = config.sops.secrets."sonarr/api_key".path;
          baseUrl = "http://${config.nixflix.sonarr.connectionAddress}:${toString config.nixflix.sonarr.config.hostConfig.port}${config.nixflix.sonarr.config.hostConfig.urlBase}";
          prowlarrUrl = "http://${config.nixflix.prowlarr.connectionAddress}:${toString config.nixflix.prowlarr.config.hostConfig.port}${config.nixflix.prowlarr.config.hostConfig.urlBase}";
          syncCategories = [
            5000
            5010
            5020
            5030
            5040
            5045
            5050
            5090
          ];
          animeSyncCategories = [ ];
        }
        {
          name = "Sonarr Anime";
          implementationName = "Sonarr";
          apiKey._secret = config.sops.secrets."sonarr-anime/api_key".path;
          baseUrl = "http://${config.nixflix.sonarr-anime.connectionAddress}:${toString config.nixflix.sonarr-anime.config.hostConfig.port}${config.nixflix.sonarr-anime.config.hostConfig.urlBase}";
          prowlarrUrl = "http://${config.nixflix.prowlarr.connectionAddress}:${toString config.nixflix.prowlarr.config.hostConfig.port}${config.nixflix.prowlarr.config.hostConfig.urlBase}";
          syncCategories = [ ];
          animeSyncCategories = [ 5070 ];
          syncAnimeStandardFormatSearch = false;
        }
      ];
      # This list is the source of truth: prowlarr-indexers.service deletes any
      # indexer not present here. Public anime trackers need no auth.
      indexers = [
        { name = "Nyaa.si"; }
        # Anidex is behind Cloudflare (cleared via FlareSolverr) but its origin is
        # flaky (502s). Keep it LAST so a failure doesn't block earlier indexers,
        # and see the SuccessExitStatus override below that stops a down indexer
        # from failing the unit / the rebuild.
        {
          name = "Anidex";
          tags = [ "flaresolverr" ];
        }
        # --- add later ---
        # AnimeTosho (better retention; not a built-in def -> Generic Torznab
        #   against https://feed.animetosho.org , torznab category 5070).
        # AnimeBytes (private, needs passkey):
        # { name = "AnimeBytes";
        #   passkey._secret = config.sops.secrets."indexer-api-keys/animebytes".path; }
      ];
    };

    jellyfin.enable = true;
    jellyfin.apiKey._secret = config.sops.secrets."jellyfin/api_key".path;
    jellyfin.users.admin = {
      mutable = false;
      policy.isAdministrator = true;
      password._secret = config.sops.secrets."jellyfin/admin_password".path;
    };
    jellyfin.users.friend = {
      mutable = false;
      password._secret = config.sops.secrets."jellyfin/friend_password".path;
    };

    # Hardware transcoding on the NVIDIA GTX 1060 (Pascal) — see
    # modules/hardware/nvidia.nix. nixflix writes this to encoding.xml and, with
    # enableHardwareEncoding, drops PrivateDevices + adds the video/render groups
    # to jellyfin.service, so no extra device wiring is needed here.
    jellyfin.encoding = {
      enableHardwareEncoding = true;
      hardwareAccelerationType = "nvenc";
      # GP106 NVENC encodes H.264 and HEVC (incl. 10-bit) but NOT AV1.
      allowHevcEncoding = true;
      allowAv1Encoding = false;
      # NVDEC decode codecs the 1060 supports (no AV1 decode on Pascal).
      hardwareDecodingCodecs = [
        "h264"
        "hevc"
        "mpeg2video"
        "vc1"
        "vp8"
        "vp9"
      ];
      enableEnhancedNvdecDecoder = true;
    };

    vpn = {
      enable = true;
      wgConfFile = config.sops.secrets."wireguard/conf".path;
      # accessibleFrom both firewalls the namespace AND adds return routes inside
      # it (`ip route add <subnet> via bridge`); without a matching entry the
      # reply to a DNAT'd WebUI request is sent out the VPN tunnel instead of back
      # to the client, so the connection hangs. Hence every source that reaches
      # qbt's WebUI must be listed:
      #   192.168.1.0/24 — LAN + cloudflared (host net namespace)
      #   127.0.0.1/32   — host-local widgets (homepage-dashboard qbt widget)
      #   100.64.0.0/10  — tailnet admin access to the WebUI on :8282
      accessibleFrom = [
        "192.168.1.0/24"
        "127.0.0.1/32"
        "100.64.0.0/10"
      ];
    };

    torrentClients.qbittorrent = {
      enable = true; # vpn.enable defaults to nixflix.vpn.enable -> auto-confined
      torrentingPort = 28259;
      password._secret = config.sops.secrets."qbittorrent/password".path;
      # The password above is only for Arr integration; qBittorrent itself
      # needs WebUI\Password_PBKDF2 in serverConfig.
      serverConfig = {
        BitTorrent.Session.Port = 28259;
        LegalNotice.Accepted = true;
        Network.PortForwardingEnabled = false;
        Preferences = {
          Connection = {
            PortRangeMin = 28259;
            UPnP = false;
          };
          WebUI = {
            Username = "admin";
            Password_PBKDF2 = "@ByteArray(47aymIXO6K8biweYr3oqRA==:hnh1G3vZGiVKXF0xssz5p0xIT2nNtIICYjNauuRVtJ02PKu4sdMbIvLq7FPQelqUa/sXORXt1ADkSQaHHnWKgA==)";
            LocalHostAuth = false;
            UseUPnP = false;
          };
        };
      };
    };
  };

  # Expose the media-stack web UIs over the tailnet only (mirrors the SSH
  # pattern in modules/services/openssh.nix). Not opened on the LAN/WAN — remote
  # viewing goes through cloudflared; these are for admin access via Tailscale.
  # qBittorrent is VPN-confined but its WebUI is mapped back onto the host port.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
    9696 # prowlarr
    8989 # sonarr
    8990 # sonarr-anime
    7878 # radarr
    8282 # qbittorrent webui
    8096 # jellyfin http
    8920 # jellyfin https
  ];

  # Wait for the Prowlarr API before the reconcile oneshots hit it (see comment
  # on waitForProwlarr above). Distinct service names merge cleanly with the
  # nixflix-setup-dirs definition higher up.
  systemd.services.prowlarr-tags.serviceConfig.ExecStartPre = waitForProwlarr;
  systemd.services.prowlarr-indexers.serviceConfig.ExecStartPre = waitForProwlarr;
  systemd.services.prowlarr-applications.serviceConfig.ExecStartPre = waitForProwlarr;
  systemd.services.prowlarr-indexer-proxies.serviceConfig.ExecStartPre = waitForProwlarr;

  # The reconcile script exits 1 when an indexer can't be validated (e.g. a down
  # tracker 502-ing). Treat exit 1 as success so one flaky indexer doesn't fail
  # the unit or the rebuild. Trade-off: real errors (e.g. a typo'd indexer name
  # -> "No schema found") are also no longer fatal — check the journal:
  #   journalctl -u prowlarr-indexers
  # Indexers listed before the failing one are already persisted, so keep flaky
  # ones last. The ExecStartPre gate still hard-fails if Prowlarr itself is down.
  systemd.services.prowlarr-indexers.serviceConfig.SuccessExitStatus = "1";
}
