#!/usr/bin/env bash
# Restore the staged alexserver state on the NEW bare-metal box.
#
# Companion to scripts/stage-alexserver-migration.sh. Because the staged folder
# rode along inside the ZFS pool, it's already sitting at
# /tank/nas/migration/<stamp>/ once you've imported/received 'tank'.
#
# Ordering matters, so this runs in two phases:
#
#   sudo ./scripts/restore-alexserver-migration.sh pre   [migration_dir]
#       -> restores the SSH host key ONLY. Do this BEFORE the first
#          `nixos-rebuild switch`, so sops-nix can decrypt secrets on the very
#          first activation (cloudflared, samba, minecraft CF key all need it).
#
#   ... now run: sudo nixos-rebuild switch --impure --flake .#alexserver ...
#
#   sudo ./scripts/restore-alexserver-migration.sh post  [migration_dir]
#       -> loads the Immich Postgres dump and unpacks the minecraft / tailscale
#          state. Do this AFTER the rebuild has created postgres + the services.
#
# If migration_dir is omitted, the newest folder under /tank/nas/migration is used.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "error: run with sudo" >&2
  exit 1
fi

PHASE="${1:-}"
DIR="${2:-}"

if [[ "$PHASE" != "pre" && "$PHASE" != "post" ]]; then
  echo "usage: $0 {pre|post} [migration_dir]" >&2
  exit 1
fi

# Resolve the migration dir (newest under /tank/nas/migration if not given).
if [[ -z "$DIR" ]]; then
  DIR="$(find /tank/nas/migration -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | tail -1)"
fi
if [[ -z "$DIR" || ! -d "$DIR" ]]; then
  echo "error: no migration dir found (looked under /tank/nas/migration). Pass one explicitly." >&2
  exit 1
fi
echo "==> Using migration dir: $DIR"

# Verify integrity before trusting anything.
if [[ -f "$DIR/SHA256SUMS" ]]; then
  echo "==> Verifying checksums"
  ( cd "$DIR" && sha256sum -c SHA256SUMS )
else
  echo "    WARNING: no SHA256SUMS in $DIR — skipping integrity check" >&2
fi

# ---------------------------------------------------------------------------
if [[ "$PHASE" == "pre" ]]; then
  echo "==> [pre] Restoring SSH host key (the sops master)"
  if [[ ! -f "$DIR/ssh/ssh_host_ed25519_key" ]]; then
    echo "error: $DIR/ssh/ssh_host_ed25519_key missing — cannot continue" >&2
    exit 1
  fi
  install -d -m 755 /etc/ssh
  cp -a "$DIR/ssh/ssh_host_ed25519_key"     /etc/ssh/ssh_host_ed25519_key
  cp -a "$DIR/ssh/ssh_host_ed25519_key.pub" /etc/ssh/ssh_host_ed25519_key.pub
  chmod 600 /etc/ssh/ssh_host_ed25519_key
  chmod 644 /etc/ssh/ssh_host_ed25519_key.pub
  [[ -f "$DIR/ssh/ssh_host_rsa_key" ]] && cp -a "$DIR/ssh/ssh_host_rsa_key"* /etc/ssh/ && chmod 600 /etc/ssh/ssh_host_rsa_key || true

  # Make sops regenerate its age key from the restored host key on next activation.
  rm -f /var/lib/sops-nix/key.txt

  echo
  echo "==> [pre] Done. The box now has alexserver's identity."
  echo "Next:"
  echo "  sudo nixos-rebuild switch --impure --flake .#alexserver"
  echo "Then verify secrets decrypted:"
  echo "  ls -l /run/secrets/   # should contain samba/, cloudflared, minecraft/ ..."
  echo "Then run:  sudo $0 post '$DIR'"
  exit 0
fi

# ---------------------------------------------------------------------------
# PHASE == post
echo "==> [post] Restoring application state"

# Sanity: postgres must exist (created by the rebuild) before we load the dump.
if ! systemctl list-unit-files | grep -q '^postgresql\.service'; then
  echo "error: postgresql.service not found. Did you run the rebuild first?" >&2
  exit 1
fi
systemctl start postgresql
# wait for the socket to accept connections
for _ in $(seq 1 30); do
  if sudo -u postgres pg_isready -q; then break; fi
  sleep 1
done

# --- Immich Postgres dump ---------------------------------------------------
PG_DUMP="$DIR/pg_dumpall.sql.gz"
if [[ -f "$PG_DUMP" ]]; then
  echo "==> [post] Loading Immich database from $(basename "$PG_DUMP")"
  echo "    Stopping immich so it doesn't fight the restore..."
  systemctl stop immich-server.service 2>/dev/null || true

  # The rebuild already created an empty 'immich' DB + role. Drop the empty DB so
  # the dump's CREATE DATABASE + data lands cleanly. The CREATE ROLE lines will
  # warn 'already exists' — harmless, so we DON'T use ON_ERROR_STOP here.
  echo "    Dropping the freshly-created empty immich DB before restore..."
  sudo -u postgres dropdb --if-exists immich

  echo "    Restoring (role-already-exists warnings are expected)..."
  zcat "$PG_DUMP" | sudo -u postgres psql -v ON_ERROR_STOP=0 >/dev/null

  echo "    Restarting immich..."
  systemctl start immich-server.service
  echo "    NOTE: Immich version on this box should match the source box's"
  echo "          version, or it'll run schema migrations on first start."
else
  echo "    no pg_dumpall.sql.gz in $DIR — skipping DB restore" >&2
fi

# --- Minecraft world --------------------------------------------------------
if [[ -f "$DIR/minecraft.tar.gz" ]]; then
  echo "==> [post] Restoring minecraft world into /var/lib/minecraft"
  systemctl stop podman-minecraft.service docker-minecraft.service 2>/dev/null || true
  rm -rf /var/lib/minecraft
  tar -C /var/lib -xzf "$DIR/minecraft.tar.gz"
  chown -R 1000:1000 /var/lib/minecraft
  systemctl start podman-minecraft.service docker-minecraft.service 2>/dev/null || true
else
  echo "    no minecraft.tar.gz — skipping"
fi

# --- Tailscale identity -----------------------------------------------------
if [[ -f "$DIR/tailscale.tar.gz" ]]; then
  echo "==> [post] Restoring tailscale identity into /var/lib/tailscale"
  systemctl stop tailscaled.service 2>/dev/null || true
  rm -rf /var/lib/tailscale
  tar -C /var/lib -xzf "$DIR/tailscale.tar.gz"
  systemctl start tailscaled.service 2>/dev/null || true
else
  echo "    no tailscale.tar.gz — skipping (run 'tailscale up' to re-auth)"
fi

echo
echo "==> [post] Done. Spot-check:"
echo "  systemctl status immich-server postgresql"
echo "  immich:    open https://immich.example.com and confirm albums/timeline"
echo "  minecraft: journalctl -u podman-minecraft -f"
echo "  tailscale: tailscale status   (should show the same node, no re-auth)"
echo "  nas:       ls /tank/nas  &&  smbclient -L localhost -U alex"
