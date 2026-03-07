default:
    just --list

# --- Bootstrap ---

# Restore sops age key from 1Password (run once on a new machine before darwin-rebuild)
bootstrap-age-key:
    #!/usr/bin/env sh
    KEY_DIR="$HOME/.config/sops/age"
    KEY_FILE="$KEY_DIR/keys.txt"
    if [ -f "$KEY_FILE" ]; then
        echo "Age key already exists at $KEY_FILE, skipping."
    else
        mkdir -p "$KEY_DIR"
        /opt/homebrew/bin/op read 'op://Private/sops-age-key/private key' > "$KEY_FILE"
        chmod 600 "$KEY_FILE"
        echo "Age key restored to $KEY_FILE"
    fi
