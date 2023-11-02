#!/bin/bash

PACKAGE_DUMP_DIR="$HOME/dotfiles/package_dump"

# Install brew packages
brew upgrade
brew bundle install --file="$PACKAGE_DUMP_DIR/homebrew"
brew upgrade --cask && brew cleanup

# Install npm packages
xargs npm install --global < "$PACKAGE_DUMP_DIR/npm"

# Install pip packages
pip install -r "$PACKAGE_DUMP_DIR/pip"

# Install cargo packages
xargs cargo install < "$PACKAGE_DUMP_DIR/cargo"

# Install gem packages
# I don't use Gem for managing packages, as gem package manager is a mess, but I'm keeping this here for reference
# gem install $(cat "$PACKAGE_DUMP_DIR/gem" | awk '{print $1" -v "$3}')