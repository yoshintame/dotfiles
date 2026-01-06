# Nix
fish_add_path --prepend --move /nix/var/nix/profiles/default/bin
fish_add_path --prepend --move ~/.nix-profile/bin
fish_add_path --prepend --move /etc/profiles/per-user/$USER/bin

# Local
fish_add_path --prepend --move ~/.local/bin
fish_add_path --prepend --move ~/bin
fish_add_path --prepend --move bin
