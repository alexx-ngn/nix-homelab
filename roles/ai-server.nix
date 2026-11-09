# Minimal headless role for alexai: CLI baseline + tailnet reachability +
# the RTX 4070 Super driver + native llama.cpp. Not built on common/managed.nix
# since this host isn't deploy-rs managed (no ci-deploy needed).
{
  imports = [
    ./common/cli.nix
    ../modules/services/tailscale.nix
    ../modules/hardware/nvidia-rtx4070.nix
    ../modules/services/llama-cpp.nix
  ];
}
