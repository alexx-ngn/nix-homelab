# Host WireGuard tunnel to a friend's NAS (the `wg-nas` interface). Split out of
# media-storage.nix so consumers that only need the tunnel — e.g. the encrypted
# ZFS backup in zfs-backup.nix — can pull it in without the (currently disabled)
# NFS mount. The interface carries the auth/encryption for everything that talks
# to the NAS over 10.0.0.11.
{ config, ... }:
let
  # --- Non-secret values to fill in for your setup ---
  hostWgAddress = "10.8.0.3/32"; # this host's address on the WG tunnel
  peerPublicKey = "REPLACE_WITH_PEER_PUBLIC_KEY=";
  peerEndpoint = "nas-peer.example.net:51820"; # NAS/relay public WG endpoint
  nasIp = "10.0.0.11"; # NAS address reachable over the tunnel
in
{
  # WireGuard private key + preshared key are secret.
  sops.secrets."nas/wg_private_key" = { };
  sops.secrets."nas/wg_preshared_key" = { };

  # Let NetworkManager leave the wg interface alone; systemd manages it.
  networking.networkmanager.unmanaged = [ "interface-name:wg-nas" ];

  networking.wireguard.interfaces.wg-nas = {
    ips = [ hostWgAddress ];
    privateKeyFile = config.sops.secrets."nas/wg_private_key".path;
    peers = [
      {
        publicKey = peerPublicKey;
        # Symmetric PSK layered on top of the keypair; must match the NAS peer.
        presharedKeyFile = config.sops.secrets."nas/wg_preshared_key".path;
        endpoint = peerEndpoint;
        # Scope to the NAS only — 0.0.0.0/0 would tunnel ALL host traffic.
        allowedIPs = [ "${nasIp}/32" ];
        persistentKeepalive = 25;
      }
    ];
  };
}
