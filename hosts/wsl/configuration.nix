{ inputs, lib, ... }:
{
  imports = [
    inputs.nixos-wsl.nixosModules.wsl
    ../../roles/wsl.nix
  ];

  networking.hostName = "alexwsl";

  wsl = {
    enable = true;
    defaultUser = "alex";
  };

  # base.nix sets systemd-boot; WSL provides its own no-op boot loader
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

  # Emulate aarch64 so we can build aarch64-linux closures locally (e.g. for the
  # Oracle Cloud `alexvps` host) without `--build-on-remote`. Slow (qemu-user),
  # but sidesteps the kexec installer's unsigned-path signature rejection.
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  # WSL networking is managed by the Windows hypervisor; NetworkManager and
  # wpa_supplicant have no interfaces to manage and will fail on every switch.
  networking.networkmanager.enable = lib.mkForce false;
  networking.wireless.enable = false;

  # base.nix sets "suggest" but that mode still queries systemctl --user via
  # dbus, which fails in WSL when no user session is active during rebuild.
  home-manager.users.alex =
    { lib, ... }:
    {
      systemd.user.startServices = lib.mkForce false;

      # On WSL, fetchgit's post-fetch `.git` cleanup fails ("rm: cannot remove
      # '.git': Directory not empty"), leaving artifacts that change the output's
      # NAR hash and break every from-source treesitter grammar with a fixed-
      # output hash mismatch. Use nixpkgs' prebuilt grammar plugins instead.
      programs.lazyvim.pluginSource = "nixpkgs";
    };
}
