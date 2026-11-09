{ config, pkgs, ... }:
{
  # NVIDIA GTX 1060 3GB (GP106, Pascal) — headless, used for NVENC/NVDEC
  # hardware transcoding (Jellyfin/Immich), not display output.

  # Loads the proprietary kernel module + sets up the userspace stack. On a
  # headless host this does not start X; it is the documented switch for
  # pulling in the nvidia driver.
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    # Pascal was moved to the 580 legacy branch; the production branch (590+)
    # drops it ("ignoring unsupported GPU" at load). Pin legacy_580.
    package = config.boot.kernelPackages.nvidiaPackages.legacy_580;

    # The open kernel module only supports Turing (RTX 20-series) and newer
    # GPUs with a GSP; Pascal must use the proprietary module.
    open = false;

    # Required for the modern driver to bind cleanly; harmless headless.
    modesetting.enable = true;

    # No GUI settings app on a headless server.
    nvidiaSettings = false;

    # Keep the driver resident so the GPU does not have to re-initialise
    # between transcode jobs on this always-on box.
    nvidiaPersistenced = true;
  };

  # VA-API shim over NVDEC so libva consumers (e.g. Jellyfin) can use the GPU.
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      nvidia-vaapi-driver
    ];
  };
}
