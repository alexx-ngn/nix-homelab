> Operations notes copied from the private repo. References to `secrets/`, `.sops.yaml` and `dns/` point at files that are not published here.


## Hosts

| Flake target | Hostname     | Platform         | Role (`roles/`)                | Home Manager profile        |
| ------------ | ------------ | ---------------- | ------------------------------ | --------------------------- |
| `alexpc`     | `alexpc`     | x86_64-linux     | `workstation` + VFIO/QEMU      | `home/profiles/desktop.nix` |
| `alexlaptop` | `alexlaptop` | x86_64-linux     | `laptop` (GNOME)               | `home/profiles/desktop.nix` |
| `alexpad`    | `alexpad`    | x86_64-linux     | `exit-node` (ThinkPad, Tailscale exit node) | `home/profiles/base.nix`    |
| `alexserver` | `alexserver` | x86_64-linux     | `server` (headless home server) | `home/profiles/server.nix` |
| `alexvps`    | `alexvps`    | aarch64-linux    | `vps` (Oracle Cloud A1)        | `home/profiles/base.nix`    |
| `alexwsl`    | `alexwsl`    | x86_64-linux     | `wsl` (NixOS-WSL)              | `home/profiles/base.nix`    |
| `alexmac`    | `alexmac`    | aarch64-darwin   | `darwin` (nix-darwin)          | `home/profiles/base.nix`    |

NixOS system configs live under `hosts/<name>/configuration.nix` and import a
role from `roles/`:

- `workstation.nix` — desktop base (GNOME, docker, libvirtd, tailscale, browsers).
- `laptop.nix` — extends `workstation` with Intel hardware + Syncthing.
- `exit-node.nix` — headless CLI base + Tailscale advertising an exit node and a
  LAN route (used by `alexpad`, no GNOME).
- `server.nix` — standalone headless server (no GNOME); see below.
- `vps.nix` — standalone public VPS (Vaultwarden + cloudflared ingress).
- `wsl.nix` — minimal CLI base for the NixOS-WSL guest.
- `darwin.nix` — macOS bundle: `modules/darwin/*` (system, packages, homebrew,
  fonts) plus the third-party `mac-app-util` and `nix-homebrew` modules.

Roles compose the single-purpose modules in `modules/`. The `server`, `vps`,
`exit-node`, and `wsl` roles are intentionally standalone — they do not pull in
GNOME or any desktop bits.

## Hardware configuration

There are two patterns in this repo:

- **Out-of-tree (`alexpc`, `alexlaptop`):** `hardware-configuration.nix` is
  **not tracked** — it's machine-specific (block-device UUIDs, kernel modules,
  boot loader detection), generated locally by `nixos-generate-config`, and
  imported from its canonical system path:

  ```nix
  imports = [ /etc/nixos/hardware-configuration.nix ];
  ```

  Because that path is outside the flake's git tree, evaluation is impure and
  these hosts **must** pass `--impure` to every `nixos-rebuild` / `nix eval` /
  `nix flake check`. The `sw` alias (in `home/profiles/base.nix`) includes the
  flag on Linux.

- **In-tree (`alexserver`, `alexpad`, `alexvps`):** a tracked
  `hosts/<name>/hardware-configuration.nix` (filesystems/swap/boot loader) plus
  a `facter.json` consumed via `hardware.facter.reportPath` for kernel-module /
  microcode / platform detection. `alexvps` additionally uses
  [disko](https://github.com/nix-community/disko) (`hosts/vps/disk-config.nix`)
  to own its disk layout. `alexwsl` ships no hardware config (the NixOS-WSL
  module handles it).

`--impure` is harmless on the in-tree hosts and required for the out-of-tree
ones, so the docs use it throughout. macOS (`alexmac`) imports no hardware
config and does **not** need `--impure`.

## Rebuilding an existing host

NixOS hosts:

```bash
sudo nixos-rebuild switch --impure --flake .#<hostname>
# or, from any host with the alex user:
sw
```

macOS (`alexmac`):

```bash
sudo darwin-rebuild switch --flake .#alexmac
# or:
sw
```

## Installing on a fresh machine

1. Boot the NixOS minimal installer; bring up networking.
2. Partition + mount your disks under `/mnt`.
3. Generate the hardware config:
   ```bash
   sudo nixos-generate-config --root /mnt
   ```
4. Get this flake onto the installer (clone or `rsync` it to e.g.
   `/mnt/etc/nixos/infra-private`).
5. **Verify your SSH pubkey is in the host's authorized keys.** Edit
   `modules/security/ssh.nix` (or the relevant role) before installing —
   password auth is disabled, so a missing key means you're locked out.
6. Install:
   ```bash
   sudo nixos-install --flake /mnt/etc/nixos/infra-private#<hostname> --impure
   sudo reboot
   ```

## Installing on a fresh Mac

1. Install Nix (Determinate or upstream) and clone this flake.
2. Bootstrap nix-darwin:
   ```bash
   nix run nix-darwin/master#darwin-rebuild -- switch --flake .#alexmac
   ```
3. Subsequent rebuilds: `sudo darwin-rebuild switch --flake .#alexmac` (or `sw`).

## Rootless Home Manager (school Linux box)

`homeConfigurations.school` (`lib/mkHome.nix`) applies `home/profiles/school.nix`
(base minus `programs.ssh`, so the box's own `~/.ssh/config` and the tailnet host
list stay untouched) on a Linux machine without root. Nix runs inside
[nix-user-chroot](https://github.com/nix-community/nix-user-chroot), which
bind-mounts `~/.nix` over `/nix` in a user namespace. Username and home directory
are read from `$USER`/`$HOME`, so switches need `--impure`.

1. Check that unprivileged user namespaces work. If this fails (Ubuntu 24.04+
   blocks them via AppArmor), fall back to
   [nix-portable](https://github.com/DavHau/nix-portable) with `NP_RUNTIME=proot`:
   ```bash
   unshare --user --map-root-user --mount echo ok
   ```
2. Install nix-user-chroot, then single-user Nix inside it:
   ```bash
   mkdir -p ~/.local/bin && mkdir -m 0755 ~/.nix
   curl -L -o ~/.local/bin/nix-user-chroot \
     https://github.com/nix-community/nix-user-chroot/releases/download/2.1.1/nix-user-chroot-bin-2.1.1-x86_64-unknown-linux-musl
   chmod +x ~/.local/bin/nix-user-chroot
   ~/.local/bin/nix-user-chroot ~/.nix bash -c 'curl -L https://nixos.org/nix/install | sh -s -- --no-daemon'
   mkdir -p ~/.config/nix && echo 'experimental-features = nix-command flakes' >> ~/.config/nix/nix.conf
   ```
3. Enter the chroot, clone this flake, and do the first switch:
   ```bash
   ~/.local/bin/nix-user-chroot ~/.nix bash -l
   git clone <this repo> ~/infra-private && cd ~/infra-private
   nix run --inputs-from . home-manager -- switch --impure -b hm-backup --flake .#school
   ```
4. Store paths only resolve inside the chroot, so make interactive logins enter
   it and hand off to Home Manager's fish. Add to `~/.bashrc` (which Home
   Manager does not own here):
   ```bash
   if [[ $- == *i* && -z $IN_NIX_CHROOT && -x ~/.local/bin/nix-user-chroot ]]; then
     export IN_NIX_CHROOT=1 PATH="$HOME/.nix-profile/bin:$PATH"
     exec ~/.local/bin/nix-user-chroot ~/.nix "$HOME/.nix-profile/bin/fish" -l
   fi
   ```
5. Subsequent switches: `sw` from inside the chroot.

Caveats: the school's admins have root and can read your home directory, so
clone with a read-only deploy key scoped to this repo, not your main SSH key.
The store counts against your home quota, and a Nix store on an NFS-mounted
home can hit SQLite locking problems.

## Adding a new host

NixOS:

1. Create `hosts/<name>/configuration.nix` (start from an existing host as a
   template; import `/etc/nixos/hardware-configuration.nix` + a role).
2. Pick or create a Home Manager profile under `home/profiles/`.
3. Add a `nixosConfigurations.<name> = mkHost { hostModule = ...; hmModule = ...; }`
   entry in `flake.nix`.
4. Sanity-check evaluation locally:
   ```bash
   nix flake check --impure --no-build
   # or per-host:
   nix eval --impure '.#nixosConfigurations.<name>.config.system.build.toplevel.drvPath'
   ```

darwin:

1. Create `hosts/<name>/configuration.nix` importing `../../roles/darwin.nix`
   (or a new role).
2. Add a `darwinConfigurations.<name> = mkDarwin { hostModule = ...; hmModule = ...; }`
   entry in `flake.nix`.
3. Sanity-check:
   ```bash
   nix eval '.#darwinConfigurations.<name>.config.system.build.toplevel.drvPath'
   ```

## Secrets (sops-nix)

Encrypted secrets live in `secrets/secrets.yaml`; recipients are declared in
`.sops.yaml`. Each host's age key is derived from its SSH host key
(`/etc/ssh/ssh_host_ed25519_key`) — see `modules/services/sops.nix`. Consumers
reference values as `sops.secrets."path/to/key"` and read the decrypted file at
its `.path` under `/run/secrets`. See `modules/services/cloudflared.nix`
(`credentialsFile`), `modules/services/media-storage.nix` (WireGuard
`privateKeyFile`), or `modules/services/nixflix.nix` (nixflix's `_secret`
mechanism) for examples.

## Home server (`alexserver`)

`alexserver` is the headless home server. Its role (`roles/server.nix`) is a
standalone CLI base (no GNOME) plus, **currently enabled:**

- **`immich.nix`** — self-hosted photo backup (Postgres on the SSD ZFS mirror).
- **`nas-server.nix`** — NFS/file serving off the `tank` ZFS pool.
- **`cloudflared.nix`** — native `services.cloudflared` (no container) running a
  locally-managed tunnel; ingress rules map `<svc>.<domain>` →
  `http://localhost:<port>` declaratively, credentials from sops.
- **`homepage-dashboard.nix`** — service dashboard.
- **`minecraft.nix`** — game server.
- **`ddclient.nix`** — dynamic DNS.

The host config (`hosts/server/configuration.nix`) imports
`modules/hardware/nvidia.nix` and manages two ZFS pools — `tank` (HDD) and `ssd`
(SSD) — with autoScrub, trim, and autoSnapshot retention. Hot service state
(Postgres, future \*arr DBs) lives on `ssd` datasets mounted at the canonical
`/var/lib` paths; the kernel is pinned to LTS 6.18 to stay in lockstep with the
OpenZFS build.

### Media stack — currently disabled

The [`nixflix`](https://github.com/kiriwalawren/nixflix) stack (Jellyfin,
Sonarr, Radarr, Prowlarr, qBittorrent + Postgres — `modules/services/nixflix.nix`)
and its storage backend (`modules/services/media-storage.nix`, a host WireGuard
interface to the NAS + NFS mount) are **commented out** in `roles/server.nix`:
the NFS mount was hanging `nixos-rebuild switch`. Re-enable both together once
the `mnt-storage.mount` deps are sorted, and create the `ssd/arr/*` datasets
first (see the comments in `hosts/server/configuration.nix`).

When re-enabled, two WireGuard tunnels are in play (don't conflate them):

- `wireguard/conf` — the **commercial VPN** confining qBittorrent's download
  traffic to a network namespace (nixflix's `vpn` / vpn-confinement).
- `nas/wg_private_key` — the **host tunnel to the NAS** backing the NFS mount.

Secrets the media stack expects: `sonarr|radarr|prowlarr/{api_key,password}`,
`jellyfin/{api_key,admin_password}`, `qbittorrent/password`, `wireguard/conf`,
`nas/wg_private_key`, and `cloudflared/credentials`. Non-secret tunnel/export
values go in `media-storage.nix`; the `tunnelId` + `domain` go in
`cloudflared.nix`.

## Public VPS (`alexvps`)

Oracle Cloud free-tier Ampere A1 (`aarch64-linux`), installed via
[`nixos-anywhere`](https://github.com/nix-community/nixos-anywhere) with disko
owning the disk layout. The `vps` role runs **Vaultwarden**
(`modules/services/vaultwarden.nix`) behind a dedicated cloudflared tunnel
(`modules/services/cloudflared-vps.nix`). SSH stays reachable on the public
interface (key-only, root disabled) to bootstrap before Tailscale is up.

## DNS (terranix + OpenTofu)

Cloudflare DNS for `example.com` is declarative in `dns/cloudflare.nix`, compiled to
Terraform JSON by [terranix](https://github.com/terranix/terranix). Apply with:

```bash
nix run .#dns -- plan
nix run .#dns -- apply
```

The `dns` app decrypts the Cloudflare/R2 credentials from
`secrets/terraform.yaml`, writes the generated config to a gitignored workdir,
runs `tofu init` against the Cloudflare R2 state backend, then your subcommand.
`nix build .#dns-config` inspects the generated JSON without applying.

## Continuous deployment (deploy-rs)

`alexserver`, `alexvps`, and `alexpad` are CD targets via
[deploy-rs](https://github.com/serokell/deploy-rs):

```bash
nix run .#deploy-rs -- .#alexserver
```

SSH is over the tailnet (MagicDNS) as the `deploy` user; `magicRollback`
(default) reverts the activation if the post-switch health check fails. CI joins
the tailnet ephemerally via the Tailscale GitHub Action.

## Repository layout

```
flake.nix                       # inputs + nixos/darwinConfigurations + deploy + devShell + dns app
flake.lock
lib/
  mkHost.nix                    # entry point for every NixOS host
  mkDarwin.nix                  # entry point for every darwin host
hosts/
  pc/configuration.nix          # alexpc — also carries VFIO/qemu-hook
  laptop/configuration.nix
  thinkpad/configuration.nix    # alexpad — exit node; tracked hw-config + facter.json
  server/configuration.nix      # alexserver — ZFS; tracked hw-config + facter.json
  vps/                          # alexvps — configuration.nix + disk-config.nix (disko) + hw-config
  wsl/configuration.nix         # alexwsl — NixOS-WSL guest
  mac/configuration.nix         # alexmac (aarch64-darwin)
roles/                          # bundles of modules per class of host
  workstation.nix
  laptop.nix                    # extends workstation
  exit-node.nix                 # standalone — Tailscale exit node (alexpad)
  server.nix                    # standalone (no GNOME)
  vps.nix                       # standalone — public VPS
  wsl.nix                       # standalone — minimal WSL base
  darwin.nix                    # macOS bundle
modules/                        # single-purpose, opt-in modules
  base.nix
  nix-settings.nix
  darwin/                       # system, packages, homebrew, fonts (nix-darwin)
  desktop/                      # gnome, gpu-passthrough
  hardware/                     # intel, amd, nvidia
  network/                      # br0 (libvirt bridge)
  programs/                     # chromium, firefox-librewolf, fish-shell
  security/                     # user-alex, ssh, ci-deploy
  services/                     # openssh, tailscale, syncthing, docker, sops, libvirtd,
                                #   nixflix, media-storage, nas-server, cloudflared,
                                #   cloudflared-vps, immich, homepage-dashboard,
                                #   minecraft, ddclient, vaultwarden
home/
  users/alex.nix
  profiles/
    base.nix                    # CLI baseline (alexpad, alexvps, alexwsl, alexmac)
    server.nix                  # extends base (+filebot) — alexserver
    desktop.nix                 # extends base with GUI apps — alexpc, alexlaptop
dns/
  cloudflare.nix                # terranix → Cloudflare DNS for example.com (nix run .#dns)
secrets/
  secrets.yaml                  # sops-encrypted host/service secrets
  vps.yaml                      # sops-encrypted alexvps secrets
  terraform.yaml                # sops-encrypted Cloudflare/R2 creds for the dns app
.sops.yaml                      # age recipients
qemu.conf  qemu-hook.sh         # libvirt/QEMU host config (alexpc VFIO)
win10.xml  win11.xml            # libvirt domain definitions
```

## Dev shell

```bash
nix develop   # nixfmt + git
nix fmt       # format all .nix files
```
