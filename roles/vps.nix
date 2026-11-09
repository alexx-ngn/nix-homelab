let
  constants = import ../lib/constants.nix;
in
{
  imports = [
    ./common/managed.nix
    ../modules/services/sops.nix
    ../modules/services/vaultwarden.nix
    ../modules/services/caddy-vps.nix
    ../modules/services/ddns.nix
  ];

  # Track this instance's public IP. Oracle Cloud ephemeral public IPs change on
  # stop/start, so rather than hardcode one, ddclient keeps vpsddns.example.com
  # current and the service hostnames CNAME to it (see dns/cloudflare.nix) —
  # mirroring the ddns/mc pattern on alexserver. alexvps is public-facing and
  # cannot read the shared secrets.yaml, so its token copy lives in vps.yaml.
  modules.ddns = {
    enable = true;
    domain = "vpsddns.${constants.domain}";
    sopsFile = ../secrets/vps.yaml;
  };
}
