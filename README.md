# Screen On Time

A tiny macOS menu bar app that shows how long your screen has been on **since you unplugged** your Mac. It is hidden while plugged in.

- Battery percentage at the moment you unplugged, current level, and how much you've used
- Pauses while the display or system sleeps
- Dark frosted popover, optional Launch at Login
- No network access, no data collected

## Build

```bash
scripts/build.sh            # builds build/ScreenOnTime.app
scripts/build.sh --install  # also copies to /Applications and launches
```

Requires macOS 13+ and the Xcode command line tools.

## Install with Homebrew

```bash
brew install --cask redmantitu/tap/screen-on-time
```

The app is ad-hoc signed (not notarized); the cask clears the quarantine flag on install.

## License

MIT
