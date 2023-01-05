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

echo "Git config"

git config --global user.name "Mikhail Ivanov"
git config --global user.email m.ivanov0427@gmail.com


echo "Installing brew git utilities..."
brew install git-extras
brew install legit
brew install git-flow




echo "Installing other brew stuff..."
brew install tree
brew install wget
brew install trash
brew install svn
brew install mackup
brew install node


#@TODO install our custom fonts and stuff

echo "Cleaning up brew"
brew cleanup

echo "Installing homebrew cask"
brew install caskroom/cask/brew-cask

echo "Copying dotfiles from Github"
cd ~
git clone git@github.com:bradp/dotfiles.git .dotfiles
cd .dotfiles
sh symdotfiles

echo "Grunting it up"
npm install -g grunt-cli

#Install Zsh & Oh My Zsh
echo "Installing Oh My ZSH..."
curl -L http://install.ohmyz.sh | sh

echo "Setting up Oh My Zsh theme..."
cd  /Users/bradparbs/.oh-my-zsh/themes
curl https://gist.githubusercontent.com/bradp/a52fffd9cad1cd51edb7/raw/cb46de8e4c77beb7fad38c81dbddf531d9875c78/brad-muse.zsh-theme > brad-muse.zsh-theme

echo "Setting up Zsh plugins..."
cd ~/.oh-my-zsh/custom/plugins
git clone git://github.com/zsh-users/zsh-syntax-highlighting.git

echo "Setting ZSH as shell..."
chsh -s /bin/zsh

# Apps
apps=(
    alfred # Alternatife for spotlight
    bartender # Menu bar icon organizer
    bettertouchtool # Tool to customize input devices and automate computer systems
    cleanmymac # Tool to remove unnecessary files and folders from disk
    cloud # unknown
    colloquy # unknown
    cornerstone # Subversion client
    diffmerge # Visually compare and merge files
    filezilla # unknown
    firefox
    google-chrome
    harvest # Remove metadata files from external drives
    hipchat
    licecap # Animated screen capture application
    mou 
    private-internet-access # VPN client
    pycharm-ce
    razer-synapse
    sourcetree # Graphical client for Git version control
    steam
    spotify
    vagrant # Development environment
    iterm2 # Terminal emulator as alternative to Apple's Terminal app
    sublime-text2 # Text editor for code, markup and prose
    textexpander # Inserts pre-made snippets of text anywhere
    transmission # Open-source BitTorrent client
    zoomus
    sequel-pro # MySQL/MariaDB database management platform
    qlmarkdown # QuickLook generator for Markdown files
    qlstephen # QuickLook plugin for plaintext files without an extension
    suspicious-package # Application for inspecting installer packages
    notion
    adguard
    rectangle
    handbrake
    microsoft-edge
    microsoft-remote-desktop
    anydesk
    onedrive
    microsoft-word
    microsoft-powerpoint
    microsoft-excel
    intellij-idea-ce
    webstorm
    betterdiscord-installer
    telegram
    zoom
    jetbrains-toolbox
    soda-player # Video player and streaming platform
    iina # Free and open-source media player
    coconutbattery # Tool to show live information about the batteries in various devices
    'macdown' # Open-source Markdown editor
    'visual-studio-code'
    'robo-3t' # MongoDB management tool
    'appcleaner' # Application uninstaller
    'namechanger' # Rename a list of files quickly
    cask 'the-unarchiver' # Unpacks archive files
    cask 'cheatsheet' # Tool to list all active shortcuts of the current application
    cask 'clipy' # Clipboard extension app
)

# Install apps to /Applications
# Default is: /Users/$user/Applications
echo "installing apps with Cask..."
brew cask install --appdir="/Applications" ${apps[@]}

brew cask alfred link

brew cask cleanup
brew cleanup
bbbbbbbb∫BBBBBBB∫∫∫ı

∂CCC
# cask 'keycastr' # Open-source keystroke visualizer
cask 'skitch' # Screen capture tool with mark up and sharing features
cask 'the-unarchiver' # Unpacks archive files
cask 'atext' # Tool to replace abbreviations while typing
cask 'java8' # ??

brew install ffmpeg
brew install gh # GitHub command-line tool
brew 'vim'
# brew 'diff-so-fancy' # Good-lookin' diffs with diff-highlight and more
#brew 'heroku'
brew 'reattach-to-user-namespace' # Reattach process (e.g., tmux) to background
brew 'git'
# brew 'awscli' # Official Amazon AWS command-line interface
# brew 'w3m' # Pager/text based browser
brew 'nvm'
brew 'node'
#brew 'terminal-notifier'
brew 'tree'
brew 'mackup'
brew 'mas'
brew 'trash'
brew 'htop'
brew 'nmap'
brew 'mtr'
brew 'wget'
brew 'coreutils'
brew 'findutils'
brew 'autojump'
brew 'zsh'
brew 'zsh-completions'
brew 'tmux'
brew 'jq'
#brew 'q'
#brew 'docker-compose'
brew 'ack'


# Fonts
cask 'font-source-code-pro-for-powerline'
cask 'font-source-code-pro'
cask 'font-source-sans-pro'



# Non brew apps
spark
notch
finalcut
adobe
flstudio
pixelmator
pixea

# To-Do
win e etc shortcuts
setup terminal
setup extension
remote mouse