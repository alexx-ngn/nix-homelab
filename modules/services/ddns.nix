# Cloudflare dynamic DNS via ddclient, parameterized per host. Replaces the
# old ddclient.nix / ddclient-vps.nix near-clones — set modules.ddns from the
# role instead.
{ lib, config, ... }:
let
  cfg = config.modules.ddns;
  constants = import ../../lib/constants.nix;
in
{
  options.modules.ddns = {
    enable = lib.mkEnableOption "Cloudflare dynamic DNS via ddclient";

    domain = lib.mkOption {
      type = lib.types.str;
      example = "ddns.example.com";
      description = "FQDN this host keeps pointed at its current public IP.";
    };

    sopsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Sops file holding `cloudflare/ddns_api_token` when it isn't in the
        host's defaultSopsFile (e.g. alexvps reads secrets/vps.yaml because
        the shared secrets.yaml must stay off the public box).
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Cloudflare API token with Zone:DNS:Edit on the zone. Store as a plain
    # token value (not key=value) under:
    #   cloudflare:
    #     ddns_api_token: <token>
    sops.secrets."cloudflare/ddns_api_token" = lib.optionalAttrs (cfg.sopsFile != null) {
      sopsFile = cfg.sopsFile;
    };

    services.ddclient = {
      enable = true;
      protocol = "cloudflare";
      username = "token"; # literal "token" = API-token auth (not global key)
      passwordFile = config.sops.secrets."cloudflare/ddns_api_token".path;
      zone = constants.domain;
      domains = [ cfg.domain ];
      # `ifconfig.me` returns the egress IP; on alexvps that equals the VNIC's
      # 1:1-NAT public IP.
      usev4 = "webv4, webv4=ifconfig.me";
      interval = "5min";
      ssl = true;
    };
  };
}
