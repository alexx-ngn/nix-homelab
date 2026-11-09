{
  services.syncthing = {
    enable = true;
    user = "alex";
    group = "users";
    dataDir = "/home/alex/Documents";
    configDir = "/home/alex/.config/syncthing";
  };
}
