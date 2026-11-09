{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    microcode-amd
  ];
}
