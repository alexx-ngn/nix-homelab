{ config, pkgs, ... }:
let
  inherit (import ../../lib/constants.nix) domain;
  dataDir = "/var/lib/vaultwarden";
  # Same R2 account as the tofu state backend (dns/cloudflare.nix) and the
  # cloudflared tunnel AccountTag.
  r2Account = "7a79a702c3526e3b1dc977af4866a0dd";
  # Per-host R2 bucket; the R2 API token is scoped to this bucket name.
  bucket = "alexvps-backup";
  # alexvps is public-facing, so its secrets live in their OWN sops file (scoped
  # to alex_admin + alexvps_host in .sops.yaml) — NOT the shared secrets.yaml,
  # which is encrypted to the home server and must stay off this box.
  vpsSops = ../../secrets/vps.yaml;
in
{
  # ADMIN_TOKEN lives in an env file so it never lands in the nix store. The
  # decrypted file must contain a line:  ADMIN_TOKEN=<argon2 PHC hash>
  sops.secrets."vaultwarden/admin_token".sopsFile = vpsSops;
  # restic repo passphrase (encrypts the backup repo client-side).
  sops.secrets."vaultwarden/restic_password".sopsFile = vpsSops;
  # R2 S3 creds as a systemd EnvironmentFile (two lines):
  #   AWS_ACCESS_KEY_ID=...
  #   AWS_SECRET_ACCESS_KEY=...
  sops.secrets."vaultwarden/restic_env".sopsFile = vpsSops;

  # Bitwarden-compatible password manager. Bound to loopback only — the public
  # entry point is the cloudflared tunnel (vw.${domain}, see cloudflared-vps.nix),
  # which runs on this same host and connects to localhost:8222.
  services.vaultwarden = {
    enable = true;
    dbBackend = "sqlite";
    environmentFile = config.sops.secrets."vaultwarden/admin_token".path;
    config = {
      DOMAIN = "https://vw.${domain}";
      SIGNUPS_ALLOWED = false; # invite yourself via /admin (ADMIN_TOKEN) instead
      ROCKET_ADDRESS = "127.0.0.1"; # only the local cloudflared tunnel reaches it
      ROCKET_PORT = 8222;
      ROCKET_LOG = "critical";
    };
  };

  # Encrypted offsite backups to Cloudflare R2 (S3-compatible). restic does
  # client-side encryption + dedup + retention on a daily systemd timer. The
  # whole data dir (sqlite db, attachments, sends, rsa_key*, config.json) is the
  # restore set.
  services.restic.backups.vaultwarden = {
    paths = [ dataDir ];
    repository = "s3:https://${r2Account}.r2.cloudflarestorage.com/${bucket}";
    passwordFile = config.sops.secrets."vaultwarden/restic_password".path;
    environmentFile = config.sops.secrets."vaultwarden/restic_env".path;
    initialize = true; # `restic init` on first run if the repo is empty
    # The live db.sqlite3 may have an open WAL; take a consistent .backup
    # snapshot just before each run (captured in the same run) and remove it after.
    backupPrepareCommand = ''
      ${pkgs.sqlite}/bin/sqlite3 ${dataDir}/db.sqlite3 ".backup '${dataDir}/db.sqlite3.restic-snapshot'"
    '';
    backupCleanupCommand = ''
      rm -f ${dataDir}/db.sqlite3.restic-snapshot
    '';
    timerConfig = {
      OnCalendar = "01:00";
      Persistent = true;
    };
    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 4"
      "--keep-monthly 6"
    ];
  };
}
