{ config, pkgs, ... }:
{
  # NVIDIA RTX 4070 Super (AD104, Ada Lovelace) — headless AI inference host,
  # no display output needed.

  # Loads the driver + userspace stack. On a headless host this does not
  # start X; it is the documented switch for pulling in the nvidia driver.
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.stable;

    # Ada Lovelace has a GSP and is well past the Turing cutoff where NVIDIA
    # supports/recommends the open kernel module — unlike alexserver's
    # Pascal card, which must use the proprietary module.
    open = true;

    # Required for the modern driver to bind cleanly; harmless headless.
    modesetting.enable = true;

    # No GUI settings app on a headless server.
    nvidiaSettings = false;

    # Keep the driver resident so the GPU does not have to re-initialise
    # between inference requests on this always-on box.
    nvidiaPersistenced = true;
  };

  hardware.graphics.enable = true;
}
