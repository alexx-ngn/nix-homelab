# Encrypted offsite ZFS backup: raw-send replication of the local datasets to
# a friend's TrueNAS over the wg-nas tunnel.
#
# Privacy model: the source datasets are ZFS-native encrypted (key lives only
# here, in sops at nas/zfs_key, auto-loaded at pool import — see
# boot.zfs.requestEncryptionCredentials, default true). syncoid raw-sends
# (`zfs send -w`), so the TrueNAS only ever stores ciphertext and can never
# decrypt it. See the runbook for the one-time dataset-encryption migration.
{ config, ... }:
let
  nasIp = "10.0.0.11"; # TrueNAS over the wg-nas tunnel
  # Destination: children of the `tank/nas/alexbackup` dataset on a friend's
  # TrueNAS. syncoid passes --no-privilege-elevation, so the `alex` account there
  # must hold the zfs perms directly — granted via `zfs allow` on this parent
  # dataset (see runbook).
  target = ds: "alex@${nasIp}:tank/nas/alexbackup/${ds}";
in
{
  imports = [ ./nas-wireguard.nix ]; # the tunnel this rides over

  # ZFS encryption passphrase for the source datasets. Materialized to
  # /run/secrets/nas/zfs_key (root/0400) before systemd starts (sops runs in the
  # activation script), so zfs-import-<pool>.service can `zfs load-key` from it at
  # boot (keylocation=file://…, boot.zfs.requestEncryptionCredentials default true).
  sops.secrets."nas/zfs_key" = { };

  # Private key syncoid uses to ssh into the TrueNAS. Public half goes in the
  # remote alex account's authorized_keys (see runbook).
  sops.secrets."nas/syncoid_ssh_key" = {
    owner = "syncoid";
    mode = "0400";
  };

  # TrueNAS SSH host key so syncoid verifies the host without prompting.
  # Scanned over the authenticated wg-nas tunnel (ssh-keyscan 10.0.0.11).
  programs.ssh.knownHosts."10.0.0.11".publicKey =
    "ssh-ed25519 AAAA_REPLACE_WITH_YOUR_PUBLIC_KEY";

  services.syncoid = {
    enable = true;
    interval = "daily";
    sshKey = config.sops.secrets."nas/syncoid_ssh_key".path;

    # Wait for the tunnel before each push (merges with the module's
    # after=[zfs.target]).
    service = {
      after = [ "wireguard-wg-nas.service" ];
      wants = [ "wireguard-wg-nas.service" ];
    };

    # sendOptions "w" = raw send (keeps the stream encrypted end to end);
    # recvOptions "u" = don't try to mount the locked dataset on the receiver.
    commands = {
      # The NAS data lives in the child dataset tank/nas/alex (tank/nas itself is
      # just a container).
      "tank/nas/alex" = {
        target = target "nas";
        sendOptions = "w";
        recvOptions = "u";
      };
      "tank/immich" = {
        target = target "immich";
        sendOptions = "w";
        recvOptions = "u";
      };
      "ssd/postgresql" = {
        target = target "postgresql";
        sendOptions = "w";
        recvOptions = "u";
      };
    };
  };
}
