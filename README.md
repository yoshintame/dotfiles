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

Then follow `projects/post-install-checklist.md` (vault) for the ~5-minute manual cleanup (Accessibility, Input Monitoring, etc.).

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

Current and planned host configurations. Full target state and roadmap live in the vault: `projects/dotfiles-target-architecture.md`.

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

A deeper dive lives in the vault: `projects/dotfiles-architecture/dotfiles-architecture.md`.

## Key docs

User-facing documentation lives in the Obsidian vault (`~/Documents/obsidian/yoshintame/`). The repo only keeps code-artefacts (module READMEs, SKILL.md, AGENTS.md, configs).

- `projects/dotfiles-target-architecture.md` (vault) — target architecture: 4 hosts, 3 wrappers, implementation roadmap with priorities
- `projects/dotfiles-architecture/dotfiles-architecture.md` (vault) — current three-layer design and module patterns
- `projects/dotfiles/secrets-management.md` (vault) — why SOPS, tradeoffs vs alternatives
- `opinions/bootstrap-secret-strategies.md` (vault) — 1Password now, YubiKey later, Tailscale+selfhost as future option
- `projects/post-install-checklist.md` (vault) — TCC permissions and manual steps macOS requires
- `projects/testing-bootstrap.md` (vault) — VM-based testing: Tart (macOS), Lima (Linux), NixOS build-vm, Parallels (Windows/WSL)
- `projects/dotfiles/homebrew-nix-integration.md` (vault) — how Brewfile ties into nix-darwin
- `projects/dotfiles/path-management.md` (vault) — PATH organization (mise shims, nix, Homebrew)

### Agent skills (Claude Code / Codex)

- `projects/ai-agent-config/git-commit-skill.md` (vault) — safe commits with per-session private index (Claude + Codex)
- `projects/ai-agent-config/deep-research-skill.md` (vault) — general research workflow with WebSearch-first + supplementary scripts
- `projects/ai-agent-config/find-best-skill.md` (vault) — "find the best X" specialization with long list + mandatory red flags
- `projects/ai-agent-config/web-research-scripts.md` (vault) — `search-reddit`/`search-hn`/`search-github` CLI infrastructure on `$PATH`

## Common tasks

```bash
mise run dot:rebuild              # git add -A && darwin-rebuild switch
mise run dot:bootstrap-age-key    # restore SOPS age key from 1Password
mise run dot:bootstrap-ssh        # wire ~/.ssh/config to 1Password SSH Agent
mise run dot:proxy-bindings       # regen proxy-binding files from YAML
mise run dot:dump-packages        # export unmanaged app list
```
