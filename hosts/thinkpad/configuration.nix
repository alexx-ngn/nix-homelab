{ pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../roles/exit-node.nix
  ];

  # Hardware detection (kernel modules, microcode, hostPlatform) comes from
  # facter.json. fileSystems / swap stay in hardware-configuration.nix.
  hardware.facter.reportPath = ./facter.json;

  networking.hostName = "alexpad";

  # Reachable for recovery without going through the tailnet.
  modules.openssh.lanAccess = true;

  services.logind.settings.Login.HandleLidSwitch = "ignore";

  systemd.services.tailscale-udp-gro-forwarding = {
    description = "Configure UDP GRO forwarding for Tailscale exit-node traffic";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      ${pkgs.ethtool}/bin/ethtool -K enp0s31f6 rx-udp-gro-forwarding on rx-gro-list off
    '';
  };

  networking.networkmanager.dispatcherScripts = [
    {
      source = pkgs.writeShellScript "tailscale-udp-gro-forwarding" ''
        if [ "$1" != "enp0s31f6" ] || [ "$2" != "up" ]; then
          exit 0
        fi

        ${pkgs.ethtool}/bin/ethtool -K "$1" rx-udp-gro-forwarding on rx-gro-list off
      '';
      type = "basic";
    }
  ];
}
