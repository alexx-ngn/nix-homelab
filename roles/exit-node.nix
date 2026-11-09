{ lib, ... }:
{
  imports = [ ./common/managed.nix ];

  # An exit node forwards traffic for other tailnet peers, which requires the
  # "server" side of useRoutingFeatures (enables IP forwarding). The box is
  # also a regular tailnet client, so "both" rather than "server" — that
  # additionally sets net.ipv4.conf.all.rp_filter = 0 needed for client use.
  services.tailscale.useRoutingFeatures = lib.mkForce "both";

  services.tailscale.extraSetFlags = [
    "--advertise-exit-node"
    "--advertise-routes=192.168.2.0/24"
  ];
}
