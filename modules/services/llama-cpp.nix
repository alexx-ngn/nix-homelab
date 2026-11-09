{ pkgs, ... }:
let
  modelsDir = "/var/lib/llama-models";
in
{
  # CUDA kernels for Ada (RTX 4070 Super, sm_89) only. `cudaSupport` stays off
  # globally — only llama-cpp gets it, via the override below — but the
  # capability pin has to live in nixpkgs.config for cudaPackages to see it.
  nixpkgs.config = {
    cudaCapabilities = [ "8.9" ];
    cudaForwardCompat = false;
  };

  services.llama-cpp = {
    enable = true;
    package = pkgs.llama-cpp.override { cudaSupport = true; };

    settings = {
      host = "0.0.0.0"; # reachable over the tailnet; firewall restricts to tailscale0
      port = 8080;
      models-dir = modelsDir; # router mode: hot-swap any GGUF found here
      n-gpu-layers = 999; # offload everything that fits into the 4070's VRAM
      flash-attn = "on";
      jinja = true; # chat templates + tool calling
    };

    # Not `openFirewall` — that opens the port on every interface.
    openFirewall = false;
  };

  # Models live outside the unit's StateDirectory: `DynamicUser = true` puts that
  # under /var/lib/private (root-only 0700), which makes dropping in GGUFs awkward.
  systemd.tmpfiles.rules = [ "d ${modelsDir} 0755 alex users -" ];

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 8080 ];
}
