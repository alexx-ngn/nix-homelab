{ inputs, ... }:
{
  imports = [
    inputs.disko.nixosModules.disko
    ./disk-config.nix
    ./hardware-configuration.nix
    ../../roles/vps.nix
  ];

  networking.hostName = "alexvps";

  # Public VPS: keep port 22 reachable on the public interface (key-only auth,
  # root login disabled — see modules/services/openssh.nix), not tailnet-only.
  # Needed to bootstrap before Tailscale is up and for recovery.
  modules.openssh.lanAccess = true;
}
