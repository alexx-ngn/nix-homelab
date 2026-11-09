{ pkgs, ... }:
{
  virtualisation.docker.enable = true;
  virtualisation.oci-containers.backend = "docker";

  users.users.alex.extraGroups = [ "docker" ];

  environment.systemPackages = with pkgs; [
    docker-compose
    lazydocker
  ];
}
