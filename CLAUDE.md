# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repo purpose

Multi-host NixOS + nix-darwin + Home Manager flake for eight machines: `alexpc` (desktop with VFIO/QEMU GPU passthrough), `alexlaptop`, `alexpad` (ThinkPad, now a Tailscale exit node — not a GNOME laptop), `alexserver` (headless home server — Immich, NAS, nixflix arr/Jellyfin stack, ZFS pools + backup), `alexvps` (Oracle Cloud Ampere A1, `aarch64-linux` — Vaultwarden behind a public Caddy reverse proxy), `alexai` (headless local AI inference server, native `services.llama-cpp` with CUDA — a libvirt guest on `alexpc` with the RTX 4070 Super passed through, so it and the `win11` guest are mutually exclusive), `alexwsl` (NixOS-WSL guest), and `alexmac` (macOS, aarch64-darwin). Private — do not leak.

## Common commands

```bash
# Rebuild the current host (also available as the `sw` fish alias from home/profiles/base.nix)
sudo nixos-rebuild switch --impure --flake .#<hostname>

# macOS equivalent (alexmac)
sudo darwin-rebuild switch --flake .#alexmac

# Build without switching
sudo nixos-rebuild build --impure --flake .#<hostname>
darwin-rebuild build --flake .#alexmac

# Per-host evaluation sanity check (fast, no build)
nix eval --impure '.#nixosConfigurations.<hostname>.config.system.build.toplevel.drvPath'
nix eval '.#darwinConfigurations.alexmac.config.system.build.toplevel.drvPath'
nix flake check --impure --no-build

# Dev shell (nixfmt + git) and formatter
nix develop
nix fmt
```

`--impure` is **mandatory** for the out-of-tree hosts (`alexpc`, `alexlaptop`) because they import `/etc/nixos/hardware-configuration.nix`, which lives outside the flake tree (gitignored — see `.gitignore`). The other Linux hosts (`alexserver`, `alexpad`, `alexvps`) track their `hardware-configuration.nix` in-tree under `hosts/<name>/` and use `hardware.facter.reportPath = ./facter.json` for hardware detection; `--impure` is harmless there, so the `sw` alias (and these docs) pass it unconditionally on Linux. **Darwin hosts do not need `--impure`** — `alexmac` imports no out-of-tree hardware config.

## Architecture

Three-layer composition: **modules → roles → hosts**, wired together by two parallel helpers — `mkHost` (NixOS) and `mkDarwin` (macOS). `flake.nix` derives `nixosConfigurations` **and** `deploy.nodes` from a single `hosts` attrset (one entry per machine: `module`, `hm`, optional `system`, optional `deploy = true`).

- **`lib/constants.nix`** — identity constants (`username`, `domain` = example.com, `tailnetSuffix`, `acmeEmail`) imported directly by path from modules, roles, `lib/mk*.nix`, and `dns/cloudflare.nix`. Change the domain/tailnet/user in one place.

- **`lib/mkHost.nix`** — entry point for every `nixosConfigurations.<host>`. It calls `nixpkgs.lib.nixosSystem`, injects `sops-nix.nixosModules.sops` and `home-manager.nixosModules.home-manager`, sets `home-manager.users.${username} = <hmModule>` (username from `lib/constants.nix`), and threads `specialArgs = { inputs; self; }` through both the system and home-manager scopes. Takes an optional `system` arg (defaults to `x86_64-linux`); `alexvps` passes `aarch64-linux`.

- **`lib/mkDarwin.nix`** — parallel entry point for every `darwinConfigurations.<host>`. Calls `nix-darwin.lib.darwinSystem`, injects `home-manager.darwinModules.home-manager`, sets the same constants-driven `home-manager.users.${username}`, and threads the same `specialArgs`. No sops-nix on darwin (yet).

- **`lib/mkHome.nix`** — standalone Home Manager entry point for `homeConfigurations.<name>` on Linux machines the flake doesn't own (currently `school`: rootless Nix under nix-user-chroot, no sudo). Reads `home.username`/`home.homeDirectory` from `$USER`/`$HOME`, so it needs `--impure`, and passes `homeName` so `sw` runs `home-manager switch`. Profiles must treat `osConfig` as optional (`osConfig ? null`). Bootstrap steps are in `README.md`.

- **`modules/`** — single-purpose, opt-in modules (services, hardware, desktop, programs, network, containers, security). None enable themselves globally; they're imported by roles or hosts where needed. Darwin-specific modules live under `modules/darwin/` (`system.nix`, `packages.nix`, `homebrew.nix`, `fonts.nix`). `flake.nix` does **not** re-export modules as flake outputs — this is a private flake, and on-disk paths are the source of truth.

- **`roles/`** — import bundles for a class of host (service config lives in modules; roles only import modules and set role-level options):
  - `common/cli.nix` is the shared CLI baseline every NixOS role imports: base, nix-settings, user-alex, openssh, fish-shell.
  - `common/managed.nix` = `common/cli.nix` + ci-deploy + tailscale — what a remotely-managed (deploy-rs) host needs. Deliberately does **not** import sops (the exit node has no secrets); roles that need it add it themselves.
  - `workstation.nix` = `common/cli.nix` + tailscale, docker, libvirtd, gnome, chromium, firefox-librewolf, plus the zen kernel and `schedutil` cpu governor.
  - `laptop.nix` extends `workstation.nix` with Intel hardware and Syncthing.
  - `exit-node.nix` = `common/managed.nix` with `useRoutingFeatures = "both"` and `--advertise-exit-node` / `--advertise-routes`. Used by `alexpad`; deliberately no GNOME.
  - `server.nix` = `common/managed.nix` + sops + docker, plus the **currently enabled** services `nixflix`, `immich`, `zfs-backup`, `homepage-dashboard`, `minecraft`, and dynamic DNS via `modules.ddns` (domain `ddns.example.com`). `media-storage` (WireGuard NFS mount) stays commented out — it hung `nixos-rebuild switch`; nixflix now uses the local `tank` pool. Does **not** import workstation/GNOME.
  - `vps.nix` = `common/managed.nix` + sops + `vaultwarden` + `caddy-vps` (public reverse proxy that replaced the cloudflared tunnels) + `modules.ddns` (domain `vpsddns.example.com`, token from `secrets/vps.yaml`). Public Oracle Cloud A1 host.
  - `wsl.nix` = just `common/cli.nix`, for the NixOS-WSL guest.
  - `darwin.nix` is the macOS bundle: `modules/darwin/{system,packages,homebrew,fonts}.nix` + `mac-app-util` + `nix-homebrew`. No overlap with the NixOS roles — darwin uses launchd, brew, and macOS-native settings (TouchID sudo, dock layout, Finder defaults).

- **`hosts/<name>/configuration.nix`** — concrete machine config. Imports `/etc/nixos/hardware-configuration.nix` and the appropriate role, then layers on host-specific bits (hostname, networking profile, hardware-specific kernel params, etc.). `hosts/pc/configuration.nix` is the most distinctive: it enables the `gpu-passthrough` module (which owns AMD IOMMU/`vfio-pci` kernel params, NVIDIA driver blacklist, hugepages, the libvirt qemu hook, ddcutil) and the parameterized `network/br0` bridge.

- **`home/`** — Home Manager content, split into profiles + the user module:
  - `home/users/alex.nix` is the per-user definition imported by every profile.
  - `home/profiles/base.nix` is the CLI baseline (fish + starship + neovim + git + the `sw` alias) used by `alexpad`, `alexvps`, `alexwsl`, and `alexmac`.
  - `home/profiles/server.nix` extends base with `filebot`; used by `alexserver`.
  - `home/profiles/school.nix` is base with `programs.ssh` forced off; used by the rootless `homeConfigurations.school`. Shared box, so it must not own `~/.ssh/config` or carry the tailnet host list.
  - `home/profiles/desktop.nix` extends base with GUI apps; used by `alexpc` and `alexlaptop`.

## Secrets (sops-nix)

- `secrets/secrets.yaml` is the main encrypted store; `secrets/vps.yaml` holds `alexvps` secrets and `secrets/terraform.yaml` holds the Cloudflare/R2 creds used by the `dns` app (see below). `.sops.yaml` defines the key groups.
- Each host derives its sops age key from its SSH host key via `age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ]` (see `modules/services/sops.nix`), with `generateKey = true` writing to `/var/lib/sops-nix/key.txt`.
- Server-side consumers read secrets via `sops.secrets.<name>` and use the decrypted file at its `.path` under `/run/secrets`: `modules/services/ddns.nix` passes the Cloudflare token as ddclient's `passwordFile` (with a per-host `sopsFile` override on alexvps), `modules/services/vaultwarden.nix` reads its admin token and restic creds from `secrets/vps.yaml`, and `modules/services/nixflix.nix` feeds the Starr/Jellyfin services through nixflix's `_secret` mechanism.
- When adding a new encrypted value: edit the relevant `secrets/*.yaml` with `sops`, then reference it as `sops.secrets."path/to/key"` and/or `config.sops.placeholder."path/to/key"` from a module.

## DNS + CD tooling

- **DNS** — `dns/cloudflare.nix` declares Cloudflare DNS for `example.com` via `terranix`, compiled to Terraform JSON. `nix run .#dns -- plan|apply` decrypts `secrets/terraform.yaml`, writes the config to a gitignored workdir, and runs OpenTofu against a Cloudflare R2 state backend. `nix build .#dns-config` inspects the generated JSON.
- **CD** — `deploy.nodes` is generated from the `hosts` attrset in `flake.nix` for every host flagged `deploy = true` (currently `alexserver`, `alexvps`, `alexpad`) via `deploy-rs`: `nix run .#deploy-rs -- .#<host>`. SSH is over the tailnet as the `deploy` user (see `modules/security/ci-deploy.nix`); `magicRollback` reverts on a failed health check.
- **Install** — `alexvps` is installed via `nixos-anywhere` with `disko` owning the disk layout (`hosts/vps/disk-config.nix`); `alexwsl` uses the `nixos-wsl` module.

## Adding/changing things

- **New module**: drop a file under `modules/<category>/<name>.nix` and import it from whichever role(s) should pick it up. `flake.nix` does not re-export modules — on-disk paths are the source of truth.
- **New host**: create `hosts/<name>/configuration.nix` (import a hardware config — either `/etc/nixos/hardware-configuration.nix` out-of-tree or a tracked `./hardware-configuration.nix` + `facter.json` — plus a role), pick or create a Home Manager profile, then add one entry to the `hosts` attrset in `flake.nix` (`module`, `hm`, optional `system = "aarch64-linux"` for ARM, `deploy = true` to get a deploy-rs node). Remember `git add` — the flake only sees tracked files.
- **Fresh-machine install** flow is documented in `README.md`. The critical pre-install step is making sure your SSH pubkey is in the host's authorized keys (via `modules/security/ssh.nix` or the role) before running `nixos-install` — password auth is disabled.

## Conventions to preserve

- Hosts only ever import one role plus hardware-specific modules; don't import individual service modules directly from a host file when a role exists.
- Keep server config off the desktop path — `roles/server.nix` (and `vps`/`exit-node`/`wsl`) do not import GNOME/xserver and that's deliberate.
- For the out-of-tree hosts (`alexpc`, `alexlaptop`), don't try to "fix" the `--impure` requirement by inlining `/etc/nixos/hardware-configuration.nix`; it's machine-specific and intentionally untracked. The in-tree hosts track their hardware config under `hosts/<name>/` instead.
