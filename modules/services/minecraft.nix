# itzg/minecraft-server hosting the Prominence 2: Hasturian Era CurseForge
# modpack (Fabric 1.20.1). nix-minecraft can't serve this directly — a large
# CurseForge pack converted to packwiz hits the allowModDistribution=false
# wall inside fetchPackwizModpack's fixed-output derivation. itzg's
# TYPE=AUTO_CURSEFORGE handles the Fabric install + all mod downloads (incl.
# distribution-restricted ones) with a CurseForge API key.
{ config, ... }:
{
  # CF_API_KEY=<key> stored as an env-file fragment so the value is injected
  # into the container via environmentFiles instead of the Nix store.
  # Generate the key at https://console.curseforge.com/ then add via
  # `sops secrets/secrets.yaml`:
  #   minecraft:
  #     cf_api_key_env: |
  #       CF_API_KEY=$2a$10$...
  sops.secrets."minecraft/cf_api_key_env" = { };

  # itzg writes everything (world, mods, Fabric install, logs) under /data.
  # World DBs on NFS are slow/risky (same rationale as nixflix.stateDir in
  # modules/services/nixflix.nix), so this lives on the host's local disk.
  # itzg defaults to UID/GID 1000.
  systemd.tmpfiles.rules = [
    "d /var/lib/minecraft 0755 1000 1000 -"
  ];

  virtualisation.oci-containers.containers.minecraft = {
    image = "itzg/minecraft-server:java21"; # Prominence 2 (1.20.1) needs Java 21
    autoStart = true;
    ports = [ "25565:25565" ];
    volumes = [ "/var/lib/minecraft:/data" ];
    environmentFiles = [ config.sops.secrets."minecraft/cf_api_key_env".path ];
    environment = {
      EULA = "TRUE";
      TYPE = "AUTO_CURSEFORGE";
      CF_SLUG = "prominence-2-hasturian-era";
      # Main *client* file, NOT the "Server Pack" file: AUTO_CURSEFORGE parses
      # this pack's CurseForge manifest and builds the server itself (pulling
      # the server pack via the API). The Server Pack zip's manifest lists bare
      # folder strings instead of {projectID,fileID} and crashes the installer.
      CF_FILE_ID = "8070526"; # v3.9.27
      CF_FORCE_SYNCHRONIZE = "TRUE";

      # Extra mods layered on top of the pack, resolved by slug against the
      # pack's Fabric 1.20.1 (itzg picks the newest matching file).
      #   - knight-lib is Knight Quest's required dependency (not in the pack).
      #   - cosmetic-armor-fabric's deps (Trinkets, Fabric API) are bundled.
      #   - saints-dragons is omitted: 0.8.2 needs GeckoLib >=4.8.1 but the
      #     pack pins 4.7.4, which cascades into a Fabric API conflict that
      #     crashes the whole server. Re-add only alongside a GeckoLib override.
      CURSEFORGE_FILES = "knight-quest-fabric,knight-lib,cosmetic-armor-fabric";

      MEMORY = "8G"; # -Xmx8G; itzg derives -Xms from this
      USE_AIKAR_FLAGS = "TRUE"; # standard GC tuning for modded servers
      ONLINE_MODE = "TRUE";
      MOTD = "Prominence 2: Hasturian Era";
      ALLOW_FLIGHT = "TRUE"; # allow-flight=true (anti-cheat won't kick flying)

      # Suspends the JVM when no players are connected; a connection attempt
      # on 25565 resumes it. MAX_TICK_TIME must be disabled or the server
      # watchdog kills the paused process.
      ENABLE_AUTOPAUSE = "TRUE";
      AUTOPAUSE_TIMEOUT_EST = "1800"; # 30 min idle before pause
      MAX_TICK_TIME = "-1";
    };
    extraOptions = [ "--stop-timeout=120" ]; # let MC flush chunks before SIGKILL
  };

  # Public exposure (player access over WAN). Distinct from the arr stack,
  # which is tailscale0-only — see modules/services/nixflix.nix:228.
  networking.firewall.allowedTCPPorts = [ 25565 ];
}
