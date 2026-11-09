# nix-homelab

One Nix flake that defines all 8 of my machines: Linux desktops and laptops, a home server, a public VPS, a GPU VM, WSL, and a Mac. Every host is built from the same set of roles and modules, and the server and ThinkPad redeploy automatically from CI on every push to `main`.

This is a public snapshot of a private repo. Secrets, DNS records, real SSH keys, and personal details have been removed (see [What's not here](#whats-not-here)), so it is meant to be read, not deployed as-is.

## Hosts

| Host | Platform | Role | What it does |
|---|---|---|---|
| `alexpc` | x86_64-linux | `workstation` | GNOME desktop, VFIO GPU passthrough to VMs |
| `alexai` | x86_64-linux | `ai-server` | libvirt guest on `alexpc` holding the GPU; local LLM via llama.cpp |
| `alexlaptop` | x86_64-linux | `laptop` | GNOME laptop, Syncthing |
| `alexpad` | x86_64-linux | `exit-node` | ThinkPad acting as a Tailscale exit node and LAN router |
| `alexserver` | x86_64-linux | `server` | Headless home server on ZFS |
| `alexvps` | aarch64-linux | `vps` | Oracle Cloud A1, public reverse proxy and Vaultwarden |
| `alexwsl` | x86_64-linux | `wsl` | NixOS-WSL guest |
| `alexmac` | aarch64-darwin | `darwin` | nix-darwin plus Homebrew |

All hosts share one Home Manager setup (`home/profiles/`) and talk to each other over Tailscale.

## Layout

```
flake.nix        fleet definition: one entry per host, built with lib/mkHost.nix / mkDarwin.nix
lib/             host builders and shared constants (username, domain, tailnet)
roles/           what a machine is (server, vps, workstation, ...), composed from modules
modules/         single-purpose modules: services/, security/, hardware/, programs/, darwin/
hosts/<name>/    per-host config, hardware config, disko layouts, facter reports
home/profiles/   Home Manager profiles (base, desktop, server, ...)
scripts/         migration and restore helpers
docs/            longer operations notes
```

A host is a short file: hardware plus one role. Roles import modules, so adding a service to every server is a one-line change in `roles/server.nix`.

## Services

All declared in `modules/services/` and enabled per role:

- **Immich:** photo backup, with Postgres on an SSD ZFS mirror
- **Vaultwarden:** password manager on the VPS, behind Caddy
- **NAS:** NFS file serving from the `tank` ZFS pool
- **Media stack** ([nixflix](https://github.com/kiriwalawren/nixflix)): Jellyfin and the *arr apps, with downloads confined to a VPN network namespace
- **llama.cpp:** local LLM on the GPU VM
- **Homepage dashboard** and **Minecraft** on the server, **Syncthing** on the laptop
- **Dynamic DNS:** a Cloudflare record kept pointed at each host
- **Encrypted ZFS backups:** raw `zfs send` to an off-site NAS over a dedicated WireGuard tunnel

Storage runs on two ZFS pools (HDD `tank`, SSD `ssd`) with scrubs, trim and snapshot retention. Hot service state lives on SSD datasets at the usual `/var/lib` paths.

## CI/CD

`.github/workflows/ci.yml`:

1. **Lint:** `nix fmt -- --ci` checks formatting.
2. **Build:** each deploy target is built on GitHub Actions, with a Cachix binary cache to skip rebuilds.
3. **Deploy:** the runner joins the tailnet through a Tailscale OAuth client tagged `tag:ci`, loads a deploy-only SSH key, pins the host key, and runs [deploy-rs](https://github.com/serokell/deploy-rs). deploy-rs's magic rollback reverts the switch if the post-activation health check fails.

Deploys are serialized per host, and a `main` run is never cancelled mid-deploy. In this public copy the workflow is set to manual-only, so pushes here never try to reach the hosts.

## Secrets

Secrets are encrypted with [sops-nix](https://github.com/Mic92/sops-nix) and age, and decrypted on the host at activation. The VPS has its own secrets file, so the public box never holds the home server's keys. Modules reference secrets by name only (`config.sops.secrets."<name>".path`), which is why they read cleanly without the encrypted files.

## Other tools used

[disko](https://github.com/nix-community/disko) for declarative disk layouts, [nixos-anywhere](https://github.com/nix-community/nixos-anywhere) for installs over SSH, [nixos-facter](https://github.com/nix-community/nixos-facter) for hardware detection, terranix and OpenTofu for Cloudflare DNS (not included), and VFIO/QEMU for GPU passthrough.

## What's not here

- `secrets/` and `.sops.yaml` (encrypted secrets and age recipients)
- `dns/` (Cloudflare records)
- Real domain, tailnet name and contact email: these are replaced with `example.com`, `tailnet-name.ts.net` and `admin@example.com`
- SSH public keys and the WireGuard peer key: replaced with placeholders
- Disk and device serial numbers in `facter.json`: redacted
- Git history

Because the secrets and DNS are missing, `nix flake check` and host builds won't pass as-is. To reuse a piece, copy the module and supply your own values.
