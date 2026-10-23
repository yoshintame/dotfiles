# dotfiles

Personal macOS / NixOS configuration managed declaratively via Nix (`nix-darwin` + `home-manager` on flake-parts), with live config symlinks via [nix-link](lib/nix-link.nix) and encrypted secrets via [SOPS](https://github.com/getsops/sops) + age.

## Installation

### Fresh macOS (one command)

On a freshly-installed Mac, after Setup Assistant and granting Full Disk Access to the terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/yoshintame/dotfiles/master/bootstrap.sh | bash -s -- lasthaze-mbp
```

This will:

1. Install Xcode Command Line Tools (interactive) and clone this repo with submodules to `~/.dotfiles`
2. Check Full Disk Access of the terminal and wait for the App Store sign-in that `mas` needs
3. Install Rosetta, Homebrew and Nix (Determinate Nix; `BOOTSTRAP_NIX=upstream` for upstream Nix)
4. Run the first `darwin-rebuild switch` with the Brewfile, using the nix-darwin revision pinned in `flake.lock`. The [sops-templates](lib/sops-templates) module gates secret rendering on the age key, so the first switch on a fresh machine succeeds without it
5. Install mise toolchains and the repo's bun dependencies
6. Restore the SOPS age key from 1Password (`op read`) — waits until 1Password is signed in with CLI integration enabled
7. Wire `~/.ssh/config` to the 1Password SSH Agent
8. Run `dot rebuild` — the second switch renders the secrets now that the key is present
9. Open System Settings panels for the TCC permissions that cannot be automated

The remaining manual steps are in the reinstall runbook of the Obsidian vault: `projects/mbp-clean-reinstall/knowledge/mbp-reinstall-runbook.md`.

`bootstrap.sh --test lasthaze-mbp` is the unattended mode for a Tart VM: it skips the App Store and Full Disk Access checks, `mas` entries of the Brewfile and TCC-protected defaults.

### Already-cloned repo

```bash
bash ~/.dotfiles/install.sh lasthaze-mbp
```

or just rebuild via mise:

```bash
mise run dot:rebuild
```

## Hosts

| Host               | Platform                | Configuration                           |
| ------------------ | ----------------------- | --------------------------------------- |
| `lasthaze-mbp`     | macOS aarch64           | nix-darwin + home-manager, `bootstrap.sh` |
| `lasthaze-homelab` | NixOS x86_64            | NixOS + home-manager, own deploy        |
| `lasthaze-edge`    | NixOS x86_64            | NixOS, own deploy                       |
| `lasthaze-ru`      | NixOS x86_64            | NixOS, own deploy                       |
| `lasthaze-gaming`  | NixOS-WSL on Windows    | NixOS-WSL + nix-win, `bootstrap.ps1`    |

## Architecture

Three-layer hybrid approach:

- **Nix layer** — packages and system defaults via nix-darwin / NixOS + home-manager
- **nix-link layer** — live symlinks from [modules/](modules) into `~/.config` so edits apply both ways
- **sops-templates layer** — templated configs rendered with decrypted secrets at activation time

Documentation lives in the Obsidian vault (`~/Documents/obsidian/yoshintame/`), entry point `areas/dotfiles.md`; the repo keeps only code artefacts.

## Common tasks

```bash
mise run dot:rebuild              # git add -A, darwin-rebuild switch, reload sops-nix, install MCP servers
mise run dot:rebuild-full         # same, and converge Homebrew to the Brewfile
mise run dot:link                 # home-manager links only, no sudo
mise run dot:bootstrap-age-key    # restore SOPS age key from 1Password
mise run dot:bootstrap-ssh        # wire ~/.ssh/config to 1Password SSH Agent
mise run dot:proxy-bindings       # regen proxy-binding files from YAML
mise run dot:dump-packages        # export unmanaged app list
```
