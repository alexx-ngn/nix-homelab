{ ... }:
let
  inherit (import ../../lib/constants.nix) domain tailnetSuffix acmeEmail;
  # alexserver over the tailnet (MagicDNS). The VPS is just public ingress; the
  # data path to the home server rides Tailscale, so no home ports are opened.
  # If the headless VPS ever fails to resolve MagicDNS, swap this for
  # alexserver's static 100.x tailnet IP.
  server = "alexserver.${tailnetSuffix}";
in
{
  # Public reverse proxy — replaces the cloudflared tunnels (whose free tier
  # caps proxied request bodies at ~100 MB, breaking large Immich uploads).
  # Caddy terminates real Let's Encrypt TLS and forwards: alexserver services
  # over the tailnet, and Vaultwarden to its own loopback on this host.
  # Caddy sets X-Forwarded-* and handles websocket upgrades automatically, so
  # Immich and Vaultwarden need no extra config.
  #
  # NOTE: the matching DNS records (dns/cloudflare.nix) must be DNS-only
  # (grey cloud) A records at this host's IP — keeping Cloudflare's orange-cloud
  # proxy in front would just re-impose the same 100 MB cap.
  services.caddy = {
    enable = true;
    email = acmeEmail; # ACME registration / expiry notices
    virtualHosts = {
      "immich.${domain}".extraConfig = "reverse_proxy http://${server}:2283";
      "jellyfin.${domain}".extraConfig = "reverse_proxy http://${server}:8096";
      "sonarr.${domain}".extraConfig = "reverse_proxy http://${server}:8989";
      "vw.${domain}".extraConfig = "reverse_proxy http://localhost:8222";
    };
  };

  # Public HTTPS ingress. ACME HTTP-01 + HTTP->HTTPS redirect needs 80; TLS on
  # 443. Oracle Cloud's VCN security list is a SEPARATE firewall — TCP 80/443
  # must also be opened there in the OCI console or this all times out.
  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
}
