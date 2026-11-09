{ config, ... }:
{
  # Immich runs natively: server + redis + its DB on the shared postgres instance.
  # AI/ML (smart search / face recognition / object tagging) runs in a separate
  # GPU container (see below) since the native package is CPU-only. The GPU also
  # does video transcoding (NVENC/NVDEC) for the native server.
  services.immich = {
    enable = true;
    host = "0.0.0.0"; # reachable over the tailnet; firewall restricts to tailscale0
    port = 2283;
    # Dedicated, Immich-owned library at the root of the local ZFS 'tank' pool.
    # Deliberately kept OUT of any user's home tree: the immich service owns the
    # whole path top-to-bottom, so it can create/recreate all of its own subfolders
    # (upload/, library/, thumbs/, encoded-video/, ...) without traversing or
    # writing into a foreign-owned parent.
    mediaLocation = "/tank/immich";

    # Native CPU ML is OFF: the nixpkgs immich-machine-learning package links the
    # plain (CPU) onnxruntime with no CUDA execution provider, so it can't use the
    # GTX 1060. We instead run upstream's prebuilt :cuda ML image as a container
    # (see oci-containers below), which DOES use the GPU. The native server still
    # points at http://localhost:3003 (set unconditionally by the module), so it
    # reaches the container transparently.
    machine-learning.enable = false;

    # Expose the NVIDIA GPU (GTX 1060, Pascal) for NVENC/NVDEC video transcoding.
    # immich bundles jellyfin-ffmpeg, which is built with the NVIDIA hwaccel
    # codecs, so it can drive these nodes directly. The default `[ ]` sets
    # PrivateDevices=true and hides ALL devices — hence the explicit list.
    # The matching runtime switch (Administration -> Settings -> Video
    # Transcoding -> Hardware Acceleration = NVENC) must be flipped in the UI;
    # it lives in immich's DB, not here.
    accelerationDevices = [
      "/dev/nvidia0"
      "/dev/nvidiactl"
      "/dev/nvidia-uvm"
      "/dev/nvidia-uvm-tools"
    ];
    # database.enable + redis.enable default true. On 25.11 the DB uses VectorChord
    # automatically (pgvecto.rs is gone). Auth is over the local socket, so no
    # secret needed.
  };

  # GPU-accelerated machine learning. Upstream only ships CUDA ML as a prebuilt
  # image (onnxruntime-gpu can't be cleanly built in nixpkgs), so we run it as a
  # container and let the native immich-server reach it on localhost:3003.
  #
  # Exposes the GPU to docker via CDI: with the toolkit enabled and docker >= 25,
  # the toolkit module flips `features.cdi = true` on the daemon, so the
  # `--device=nvidia.com/gpu=all` below resolves. Bound to loopback only — the
  # ML server has no auth and must never be LAN/WAN reachable.
  hardware.nvidia-container-toolkit.enable = true;

  virtualisation.oci-containers.containers.immich-machine-learning = {
    # Pin to the SAME version as the native server (config.services.immich) so the
    # two never drift out of API compatibility. `-cuda` is the GPU variant.
    image = "ghcr.io/immich-app/immich-machine-learning:v${config.services.immich.package.version}-cuda";
    ports = [ "127.0.0.1:3003:3003" ];
    # Model weights are downloaded on first use; persist them across restarts.
    volumes = [ "immich-model-cache:/cache" ];
    extraOptions = [ "--device=nvidia.com/gpu=all" ];
  };

  # /tank is root:root 0755 (world-traversable), so the only dir that needs
  # creating is the library root itself. tmpfiles (root) creates it and hands
  # ownership to immich on every boot/switch; immich manages everything beneath it.
  # Non-recursive, so an existing library isn't re-chowned on every boot.
  systemd.tmpfiles.rules = [
    "d /tank/immich 0700 immich immich - -"
  ];

  # Admin/photo access over the tailnet only (mirrors the nixflix UIs). Public
  # viewing goes through cloudflared (immich.example.com). openFirewall stays false so
  # 2283 is never opened on the LAN/WAN.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 2283 ];
}
