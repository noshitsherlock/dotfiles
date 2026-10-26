#!/usr/bin/env bash
# macOS system preferences. Safe to re-run.
echo 'modifying NSUserDefaults'

# Keyboard: Disable autocorrect
defaults write -g NSAutomaticSpellingCorrectionEnabled -bool false

# Keyboard: Disable auto-capitalization
defaults write -g NSAutomaticCapitalizationEnabled -bool false

# Keyboard: Set shorter Delay until key repeat
defaults write -g InitialKeyRepeat -int 15

# Keyboard: Set a fast keyboard repeat rate
defaults write -g KeyRepeat -int 2

# Keyboard: Reenable key repeat when pressing and holding keys
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

# Finder: new windows start in home directory
defaults write com.apple.finder NewWindowTarget -string PfHm
defaults write com.apple.finder NewWindowTargetPath -string "file://$HOME/"

# Finder: only search current direcotry
defaults write com.apple.finder FXDefaultSearchScope -string SCcf

# Mission Control: Don't automatically rearrange Spaces based on most recent use
defaults write com.apple.dock mru-spaces -bool false

# Dock: Disable recents
defaults write com.apple.dock show-recents -bool false

# Dock: Auto-hide, smaller icons, minimize into app icon
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock tilesize -int 42
defaults write com.apple.dock minimize-to-application -bool true

# Appearance: Dark mode
defaults write -g AppleInterfaceStyle -string Dark

# Finder: List view, path bar, show hidden files, no internal disk on desktop
defaults write com.apple.finder FXPreferredViewStyle -string Nlsv
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write com.apple.finder ShowHardDrivesOnDesktop -bool false

# Screenshot: Save screenshots with date in filename
defaults write com.apple.screencapture include-date -bool true

# Spotlight: don't send stuff to apple
defaults write com.apple.lookup lookupEnabled -dict-add suggestionsEnabled -bool no

# Preview: Disable autosave in Preview
defaults write com.apple.Preview ApplePersistence -bool no

# Terminal: Fix weird copy+paste in apple terminal
defaults write com.apple.Terminal CopyAttributesProfile com.apple.Terminal.no-attributes

# Terminal: use pro theme
defaults write com.apple.Terminal 'Startup Window Settings' -string Pro
defaults write com.apple.Terminal 'Default Window Settings' -string Pro

# Terminal: new tabs use default profile and CWD
defaults write com.apple.Terminal NewTabSettingsBehavior -int 1
defaults write com.apple.Terminal NewTabWorkingDirectoryBehavior -int 1

# Appearance: Dark app icons
defaults write -g AppleIconAppearanceTheme -string RegularDark

# Global: Don't swipe between pages with two fingers
defaults write -g AppleEnableSwipeNavigateWithScrolls -bool false

# Global: List view in Open dialogs
defaults write -g NavPanelFileListModeForOpenMode -int 2

# Dock: No bouncing on app launch, scale minimize effect
defaults write com.apple.dock launchanim -bool false
defaults write com.apple.dock mineffect -string scale

# Windows: Disable macOS tiling (Rectangle handles it), hide desktop items
defaults write com.apple.WindowManager EnableTilingByEdgeDrag -bool false
defaults write com.apple.WindowManager EnableTopTilingByEdgeDrag -bool false
defaults write com.apple.WindowManager EnableTilingOptionAccelerator -bool false
defaults write com.apple.WindowManager EnableTiledWindowMargins -bool false
defaults write com.apple.WindowManager HideDesktop -bool true

# Menu bar clock: Day of week, AM/PM
defaults write com.apple.menuextra.clock ShowDayOfWeek -bool true
defaults write com.apple.menuextra.clock ShowAMPM -bool true

# Shortcuts: Free ⌘Space for Raycast (disable Spotlight and Finder search),
# and disable ⌃Space / ⌃⌥Space input source switching
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 64 '{enabled = 0; value = {type = standard; parameters = (65535, 49, 1048576);};}'
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 65 '{enabled = 0; value = {type = standard; parameters = (65535, 49, 1572864);};}'
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 60 '{enabled = 0; value = {type = standard; parameters = (32, 49, 262144);};}'
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 61 '{enabled = 0; value = {type = standard; parameters = (32, 49, 786432);};}'
/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u 2>/dev/null || true

# Login items: Rectangle and Raycast
for app in Rectangle Raycast; do
  osascript -e 'tell application "System Events" to get the name of every login item' 2>/dev/null | grep -q "$app" && continue
  [ -d "/Applications/$app.app" ] && osascript -e "tell application \"System Events\" to make login item at end with properties {path:\"/Applications/$app.app\", hidden:false}" >/dev/null
done

# Dock: Apps in order, then Downloads (sorted by date added, shown as a stack).
# Apps that aren't installed yet (e.g. Office before Company Portal) are skipped;
# re-run ./install.sh macos once they are.
if command -v dockutil &>/dev/null; then
  dockutil --remove all --no-restart >/dev/null
  for app in \
    "/Applications/Brave Browser.app" \
    "/System/Applications/Messages.app" \
    "/System/Applications/Calendar.app" \
    "/Applications/Microsoft Outlook.app" \
    "/Applications/iTerm.app" \
    "/Applications/Obsidian.app" \
    "/Applications/Microsoft Teams.app" \
    "/Applications/Microsoft Excel.app" \
    "/Applications/Microsoft PowerPoint.app" \
    "/Applications/Slack.app" \
    "/Applications/WezTerm.app" \
    "/Applications/Claude.app" \
    "/Applications/Microsoft 365 Copilot.app"; do
    if [ -d "$app" ]; then dockutil --add "$app" --no-restart >/dev/null; else echo "  dock: not installed yet, skipping $(basename "$app" .app)"; fi
  done
  dockutil --add "$HOME/Downloads" --view grid --display stack --sort dateadded --section others --no-restart >/dev/null
else
  echo '  dockutil not installed, skipping Dock layout'
fi

echo 'done: killing Dock, Finder and SystemUIServer'
killall Dock Finder SystemUIServer 2>/dev/null || true
