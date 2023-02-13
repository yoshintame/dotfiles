echo "Creating an SSH key for you..."
ssh-keygen -t rsa

echo "Please add this public key to Github \n"
echo "https://github.com/account/ssh \n"
read -p "Press [Enter] key after this..."

# Check for Homebrew,
# Install if we don't have it
if test ! $(which brew); then
  echo "Installing homebrew..."
  ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
fi

# Update homebrew recipes
echo "Updating homebrew..."
brew update

echo "Installing Git..."
brew install git

echo "Git config setting up..."
git config --global user.name "Mikhail Ivanov"
git config --global user.email m.ivanov0427@gmail.com

echo "Installing xcode-select..."
xcode-select --install # Need for some apps

echo "Cleaning up brew..."
brew cleanup

echo "Installing homebrew cask..."
brew install caskroom/cask/brew-cask

echo "Copying and stowing dotfiles from Github..."
cd ~
git clone {} .dotfiles # @TODO
cd .dotfiles
sh @macos/stow.packeges.sh

echo "Installing Brew Bundles..."
brew bundle --file=~/.dotfiles/_brewbundle/Brewfile.main
brew bundle --file=~/.dotfiles/_brewbundle/Brewfile.Brewfile.safariextensions

brew cask cleanup
brew cleanup




