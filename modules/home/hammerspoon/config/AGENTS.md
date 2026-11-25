# AGENTS.md

Hammerspoon config of the dotfiles. `~/.hammerspoon` links to this directory through home-manager (nix-link), and Hammerspoon reloads when a file here is saved.

## Trying a worktree live

Only the main dotfiles tree is live. To run this config from a dotfiles worktree, use `dot dev hs <branch|path>`: it points `~/.hammerspoon` at the worktree's `modules/home/hammerspoon/config` and restarts Hammerspoon. When done, `dot dev hs off` restores the home-manager link; `dot dev hs` shows which config is live. `dot link` and `dot rebuild` also reset it.

Do not write `MJConfigFile` with `defaults` and do not copy worktree files into the main tree to try them.
