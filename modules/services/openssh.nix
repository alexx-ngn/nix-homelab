{ lib, config, ... }:
let
  hasTailscale = config.services.tailscale.enable;
in
{
  options.modules.openssh.lanAccess = lib.mkOption {
    type = lib.types.bool;
    default = !hasTailscale;
    description = ''
      Open port 22 on every interface instead of only `tailscale0`.

      Default: true on hosts without Tailscale (they have no other path in),
      false on hosts with Tailscale (tailnet-only is the safer default).
      Hosts that legitimately need LAN ssh despite running Tailscale (e.g.
      a home server reachable for recovery) can override this to true.
    '';
  };

  config = {
    services.openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
      };
    };

    networking.firewall = lib.mkMerge [
      (lib.mkIf config.modules.openssh.lanAccess {
        allowedTCPPorts = [ 22 ];
      })
      (lib.mkIf (!config.modules.openssh.lanAccess) {
        interfaces.tailscale0.allowedTCPPorts = [ 22 ];
      })
    ];
  };
}
