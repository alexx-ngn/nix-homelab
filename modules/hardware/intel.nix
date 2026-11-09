{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    microcode-intel
    auto-cpufreq
    sbctl
    libva-vdpau-driver
  ];

  services.power-profiles-daemon.enable = false;
  services.auto-cpufreq.enable = true;
}
