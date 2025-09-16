#!/usr/bin/env bash

echo "Running install.sh"

if command -v brew &>/dev/null; then
    # Homebrew
    ## Install
    echo "Installing Brew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    brew analytics off

    ## Taps
    brew tap FelixKratz/formulae

    ## Packages
    echo "Installing Brew packages..."
    brew install borders
    brew install spaceman
    brew install switchaudio-osx
	brew install jq

    ## Casks
    echo "Installing Brew casks..."
    brew install --cask raycast
    brew install --cask rectangle
    brew install --cask spotify
    brew install --cask iterm2
    brew install --cask meetingbar
    brew install --cask itsycal
    brew install --cask mouseless@preview
    brew install --cask brave-browser
    brew install --cask obsidian
    brew install --cask termius
    brew install --cask utm
    brew install --cask telegram


    ### Fonts
    brew install --cask sf-symbols
    brew install --cask font-sf-mono
    brew install --cask font-sf-pro
    brew install --cask font-hack-nerd-font
    brew install --cask font-jetbrains-mono
    brew install --cask font-fira-code
fi

if defaults read com.apple.finder &>/dev/null; then
    echo 'modifying NSUserDefaults'

    # Keyboard: Disable autocorrect
    defaults write -g NSAutomaticSpellingCorrectionEnabled -bool false

    # Keyboard: Disable auto-capitalization
    defaults write -g NSAutomaticCapitalizationEnabled -bool false

    # Keyboard: Set a shorter Delay until key repeat
    defaults write -g InitialKeyRepeat -int 15

    # Keyboard: Set a fast keyboard repeat rate
    defaults write -g KeyRepeat -int 2

    # Keyboard: Reenable key repeat for pressing and holding keys
    defaults write -g ApplePressAndHoldEnabled -bool false

    # Finder: Show all extenions
    defaults write -g AppleShowAllExtensions -bool true

    # Global: Minimize on double click
    defaults write -g AppleMiniaturizeOnDoubleClick -bool true

    # Global: Expand save panel by default
    defaults write -g NSNavPanelExpandedStateForSaveMode -bool true
    defaults write -g NSNavPanelExpandedStateForSaveMode2 -bool true

    # Global: Expand print panel by default
    defaults write -g PMPrintingExpandedStateForPrint -bool true
    defaults write -g PMPrintingExpandedStateForPrint2 -bool true

    # Global: Save to disk (not to iCloud) by default
    defaults write -g NSDocumentSaveNewDocumentsToCloud -bool false

    # Global: Disable smart quotes as they’re annoying when typing code
    defaults write -g NSAutomaticQuoteSubstitutionEnabled -bool false

    # Global: Disable smart dashes as they’re annoying when typing code
    defaults write -g NSAutomaticDashSubstitutionEnabled -bool false

    # Finder: Show ~/Library in finder
    chflags nohidden ~/Library
    # Finder: Show /Volumes in finder

    # Printer: Automatically quit printer app once the print jobs complete
	defaults write com.apple.print.PrintingPrefs 'Quit When Finished' -bool true

	# Finder: Full POSIX path in finder windows
	defaults write com.apple.finder _FXShowPosixPathInTitle -bool true

	# Finder: Show Status bar in Finder
	defaults write com.apple.finder ShowStatusBar -bool true

	# Finder: Show icons for hard drives, servers, and removable media on the desktop
	defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true
	defaults write com.apple.finder ShowMountedServersOnDesktop -bool true
	defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool true

	# Finder: new windows start at home directory
	defaults write com.apple.finder NewWindowTarget -string PfHm
	defaults write com.apple.finder NewWindowTargetPath -string "file:///$HOME"

	# Finder: only search the current direcotry
	defaults write com.apple.finder FXDefaultSearchScope -string SCcf

	# Mission Control: Don't automatically rearrange Spaces based on most recent use
	defaults write com.apple.dock mru-spaces -bool false

    # Dock: Disable recents
	defaults write com.apple.dock show-recents -bool false

    # Screenshot: Save screenshots with date in filename
	defaults write com.apple.screencapture include-date -bool true

    # Spotlight: don't send stuff to apple
	defaults write com.apple.lookup lookupEnabled -dict-add suggestionsEnabled -bool no

	# Preview: Disable autosave for Preview
	defaults write com.apple.Preview ApplePersistence -bool no

	# Terminal: Fix weird copy+paste with apple terminal
	defaults write com.apple.Terminal CopyAttributesProfile com.apple.Terminal.no-attributes

	# Terminal: use pro theme
	defaults write com.apple.Terminal 'Startup Window Settings' -string Pro
	defaults write com.apple.Terminal 'Default Window Settings' -string Pro

	# Terminal: new tabs use default profile and CWD
	defaults write com.apple.Terminal NewTabSettingsBehavior -int 1
	defaults write com.apple.Terminal NewTabWorkingDirectoryBehavior -int 1

    # Spotlight: Don't index mounted volumes
	echo 'sudo needed to update spotlight settings'
	sudo defaults write /.Spotlight-V100/VolumeConfiguration Exclusions -array /Volumes

	echo 'done: killing Dock and Finder'
	killall Dock Finder
fi

# Start Services
echo "Starting Services (grant permissions)..."
brew services start borders
