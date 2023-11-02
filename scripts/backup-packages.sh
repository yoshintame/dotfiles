#!/bin/bash

####################################################################################
# Set up paths
####################################################################################
BACKUP_DIR="$HOME/.dotfiles"
mkdir -p "$BACKUP_DIR"

PACKAGE_DUMP_DIR="$BACKUP_DIR/packages_dump"
mkdir -p "$PACKAGE_DUMP_DIR"

echo "🛳  Cruising over to $BACKUP_DIR"
cd $BACKUP_DIR

####################################################################################
# Dump from package managers
####################################################################################
echo "💿 Dumping package managers on $HOSTNAME to the $PACKAGE_DUMP_DIR directory"

# Export NPM global packages
if npm list --global --parseable --depth=0 | sed '1d' | awk '{gsub(/\/.*\//,"",$1); print}' >"$PACKAGE_DUMP_DIR/node"; then
    echo "✅ Exported NPM global packages"
else
    echo "⛔️ Could not export NPM global packages"
fi

# Export brew packages
if brew bundle dump --force --file="$PACKAGE_DUMP_DIR/homebrew"; then
    echo "✅ Exported Brew packages"
else
    echo "⛔️ Could not export Brew packages"
fi

# Export pip packages
if pip list --format freeze >"$PACKAGE_DUMP_DIR/pip"; then
    echo "✅ Exported Pip packages"
else
    echo "⛔️ Could not export Pip packages"
fi

# Export composer packages
if composer global show | cut -d ' ' -f1 >"$PACKAGE_DUMP_DIR/composer"; then
    echo "✅ Exported Composer packages"
else
    echo echo "✅ Exported Composer packages"
fi

# Export gem packages
if gem list >"$PACKAGE_DUMP_DIR/gem"; then
    echo "✅ Exported Gem packages"
else
    echo "⛔️ Could not export Gem packages"
fi

# Export Cargo packages
if cargo install --list | awk '!x[$1]++ {print $1}' > "$PACKAGE_DUMP_DIR/cargo"; then
    echo "✅ Exported Cargo packages"
else
    echo "⛔️ Could not export Cargo packages"
fi

# Check git status
git status

