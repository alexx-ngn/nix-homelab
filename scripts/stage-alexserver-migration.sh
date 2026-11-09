#!/usr/bin/env bash
# Stage the forget-prone state for the alexserver VM -> bare-metal migration.
#
# This collects the three things that DON'T live on the ZFS 'tank' pool (and so
# would NOT come along with a `zfs send`), plus the Tailscale identity, into a
# single dated folder on tank. Run this BEFORE snapshotting/sending the pool so
# the staged folder is captured in the same snapshot.
#
#   sudo ./scripts/stage-alexserver-migration.sh
#
# What it captures, and why it matters:
#   1. SSH host ed25519 key  -> sops-nix derives the age decryption key from it.
#                               Without it the metal box can't decrypt ANY secret
#                               (samba pw, cloudflared creds, CF API key).
#   2. pg_dumpall            -> Immich's database (albums/users/metadata). Lives
#                               in /var/lib/postgresql on the ROOT fs, not tank.
#   3. /var/lib/minecraft    -> Linggango world + mods + Forge install.
#   4. /var/lib/tailscale    -> node identity (optional; skip = just re-auth once).
#
# It does NOT touch /tank/immich or /tank/nas — those ride along with the pool.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "error: run with sudo (needs to read /etc/ssh host keys and stop containers)" >&2
  exit 1
fi

DEST_ROOT="/tank/nas/migration"
STAMP="$(date +%Y-%m-%d_%H%M%S)"
DEST="${DEST_ROOT}/${STAMP}"
mkdir -p "$DEST"
chmod 700 "$DEST"

echo "==> Staging into ${DEST}"

# --- 1. SSH host key (the sops master) -------------------------------------
echo "==> [1/4] SSH host key"
install -d -m 700 "${DEST}/ssh"
cp -a /etc/ssh/ssh_host_ed25519_key     "${DEST}/ssh/"
cp -a /etc/ssh/ssh_host_ed25519_key.pub "${DEST}/ssh/"
# rsa too, if present, so client known_hosts don't complain post-migration
[[ -f /etc/ssh/ssh_host_rsa_key ]] && cp -a /etc/ssh/ssh_host_rsa_key* "${DEST}/ssh/" || true
chmod 600 "${DEST}/ssh/"*_key

# --- 2. Postgres logical dump (Immich DB) ----------------------------------
echo "==> [2/4] Postgres pg_dumpall (Immich database)"
if systemctl is-active --quiet postgresql; then
  # -u postgres: peer auth over the local socket (matches immich.nix setup)
  sudo -u postgres pg_dumpall > "${DEST}/pg_dumpall.sql"
  gzip -f "${DEST}/pg_dumpall.sql"
  echo "    wrote pg_dumpall.sql.gz ($(du -h "${DEST}/pg_dumpall.sql.gz" | cut -f1))"
else
  echo "    WARNING: postgresql not active — skipping DB dump. Immich will have" >&2
  echo "             media files but no albums/metadata if you proceed!" >&2
fi

# --- 3. Minecraft world ----------------------------------------------------
echo "==> [3/4] Minecraft world (/var/lib/minecraft)"
if [[ -d /var/lib/minecraft ]]; then
  MC_WAS_RUNNING=0
  if systemctl is-active --quiet podman-minecraft.service 2>/dev/null \
     || systemctl is-active --quiet docker-minecraft.service 2>/dev/null; then
    MC_WAS_RUNNING=1
    echo "    stopping minecraft container to flush chunks (up to 120s)..."
    systemctl stop podman-minecraft.service docker-minecraft.service 2>/dev/null || true
  fi
  tar -C /var/lib -czf "${DEST}/minecraft.tar.gz" minecraft
  echo "    wrote minecraft.tar.gz ($(du -h "${DEST}/minecraft.tar.gz" | cut -f1))"
  if [[ $MC_WAS_RUNNING -eq 1 ]]; then
    echo "    restarting minecraft container..."
    systemctl start podman-minecraft.service docker-minecraft.service 2>/dev/null || true
  fi
else
  echo "    /var/lib/minecraft not found — skipping"
fi

# --- 4. Tailscale identity (optional) --------------------------------------
echo "==> [4/4] Tailscale state (/var/lib/tailscale)"
if [[ -d /var/lib/tailscale ]]; then
  tar -C /var/lib -czf "${DEST}/tailscale.tar.gz" tailscale
  echo "    wrote tailscale.tar.gz ($(du -h "${DEST}/tailscale.tar.gz" | cut -f1))"
else
  echo "    /var/lib/tailscale not found — skipping (you'll just re-auth once)"
fi

# --- Manifest + checksums --------------------------------------------------
( cd "$DEST" && find . -type f ! -name SHA256SUMS -exec sha256sum {} + > SHA256SUMS )

echo
echo "==> Done. Staged migration set:"
ls -lah "$DEST"
echo
echo "Next steps:"
echo "  1. zfs snapshot -r tank@migrate        # captures this folder too"
echo "  2. zfs send -R tank@migrate | ssh metalbox zfs recv -F tank"
echo "     (or export the pool and move the disks)"
echo
echo "On the metal box, BEFORE the first nixos-rebuild:"
echo "  - restore ${DEST}/ssh/ssh_host_ed25519_key* into /etc/ssh (chmod 600),"
echo "    so sops-nix can decrypt secrets on the very first boot"
echo "  - after postgres is up:  sudo -u postgres psql < <(zcat pg_dumpall.sql.gz)"
echo "  - restore minecraft.tar.gz / tailscale.tar.gz into /var/lib"
