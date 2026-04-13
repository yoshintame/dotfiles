# dotfiles

Personal macOS / Linux configuration managed declaratively via Nix (`nix-darwin` + `home-manager`), with live config symlinks via [nix-dotbot](https://github.com/yoshintame/nix-dotbot) and encrypted secrets via [SOPS](https://github.com/getsops/sops) + age.

## Installation

### Fresh macOS (one command)

On a freshly-installed Mac, after logging into Apple ID:

```bash
curl -fsSL https://raw.githubusercontent.com/yoshintame/dotfiles/master/bootstrap.sh | bash -s -- lasthaze-mbp
```

This will:

1. Install Xcode Command Line Tools (interactive)
2. Clone this repo to `~/.dotfiles`
3. Install Nix (Determinate Systems installer)
4. Run `darwin-rebuild switch --flake .#lasthaze-mbp` — installs all Nix packages + Brewfile apps. The [sops-templates](modules/sops-templates) module has a bootstrap guard that skips secret rendering when the age key is absent, so the first switch on a fresh machine succeeds cleanly
5. Restore the SOPS age key from 1Password (`op read`) — requires authorizing 1Password GUI + enabling CLI integration first
6. Wire `~/.ssh/config` to the 1Password SSH Agent
7. Re-run `darwin-rebuild switch` so sops-templates renders the secrets now that the key is present
8. Print a post-install checklist and open System Settings panels for the TCC permissions that cannot be automated

Then follow [docs/post-install-checklist.md](docs/post-install-checklist.md) for the ~5-minute manual cleanup (Accessibility, Input Monitoring, etc.).

### Already-cloned repo

If the repo is already at `~/.dotfiles`, use the thin wrapper:

```bash
bash ~/.dotfiles/install.sh lasthaze-mbp
```

or just rebuild via mise:

```bash
mise run dot:rebuild
```

## Hosts

Current and planned host configurations. See [docs/target-architecture.md](docs/target-architecture.md) for the full target state and roadmap.

| Host              | OS                      | Wrapper                        | Role                                    | Status              |
| ----------------- | ----------------------- | ------------------------------ | --------------------------------------- | ------------------- |
| `lasthaze-mbp`    | macOS aarch64           | `nix-darwin` + home-manager    | Primary MacBook Pro                     | exists              |
| `lasthaze-server` | Linux x86_64 (homelab)  | **NixOS** + home-manager       | Physical homelab server at home         | planned (priority)  |
| `lasthaze-wsl`    | Fedora WSL2 on Windows  | home-manager (+ sys-mgr future)| Work laptop WSL dev env                 | future              |
| `lasthaze-vps`    | Fedora x86_64 (generic) | home-manager (+ sys-mgr future)| Generic base config for any Fedora VPS  | future              |

> **Note:** Current `flake.nix` still has `homeConfigurations.lasthaze-server` pointing at `hosts/lasthaze-home/` as a legacy home-manager config. Migration to full NixOS (priority P2) will both rename the directory and switch the wrapper.

## Architecture

Three-layer hybrid approach:

- **Nix layer** — packages and system defaults via nix-darwin + home-manager
- **nix-dotbot layer** — live symlinks from [modules/](modules) into `~/.config` so edits apply both ways
- **sops-templates layer** — templated configs rendered with decrypted secrets at activation time

See [docs/architecture.md](docs/architecture.md) for a deeper dive.

## Key docs

- [docs/target-architecture.md](docs/target-architecture.md) — target architecture: 4 hosts, 3 wrappers, implementation roadmap with priorities
- [docs/architecture.md](docs/architecture.md) — current three-layer design and module patterns
- [docs/secrets-management.md](docs/secrets-management.md) — why SOPS, tradeoffs vs alternatives
- [docs/bootstrap-secret-strategies.md](docs/bootstrap-secret-strategies.md) — 1Password now, YubiKey later, Tailscale+selfhost as future option
- [docs/post-install-checklist.md](docs/post-install-checklist.md) — TCC permissions and manual steps macOS requires
- [docs/testing-bootstrap.md](docs/testing-bootstrap.md) — VM-based testing: Tart (macOS), Lima (Linux), NixOS build-vm, Parallels (Windows/WSL)
- [docs/homebrew-nix-integration.md](docs/homebrew-nix-integration.md) — how Brewfile ties into nix-darwin
- [docs/path-management.md](docs/path-management.md) — PATH organization (mise shims, nix, Homebrew)

## Common tasks

```bash
mise run dot:rebuild              # git add -A && darwin-rebuild switch
mise run dot:bootstrap-age-key    # restore SOPS age key from 1Password
mise run dot:bootstrap-ssh        # wire ~/.ssh/config to 1Password SSH Agent
mise run dot:proxy-bindings       # regen proxy-binding files from YAML
mise run dot:dump-packages        # export unmanaged app list
```
