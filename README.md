# AmbientBGM Menubar

A macOS menu bar app for [AmbientBGM.com](https://ambientbgm.com), a free ambient
music player. Click the icon in the menu bar to open the player in a popover; the
icon changes while music is playing. Right-click for Reload and Quit.

The app is a thin WebKit wrapper around the web player. The player itself lives in
[cyberneura/ambientbgm](https://github.com/cyberneura/ambientbgm).

## Install

```shell
brew install --cask cyberneura/tap/ambientbgm-menubar
```

Or download the dmg from [Releases](https://github.com/cyberneura/ambientbgm-menubarapp/releases).

Requires macOS 13 or later (Apple Silicon and Intel).

## Build

Needs Xcode (or the Command Line Tools) on macOS.

```shell
scripts/make-app.sh          # -> dist/AmbientBGMMenubar.app (unsigned)
scripts/make-dmg.sh          # -> dist/AmbientBGMMenubar_<version>_universal.dmg
open dist/AmbientBGMMenubar.app
```

## Release

A release is decided by the `VERSION` file on `main`. Change it and
`.github/workflows/release.yml` builds, signs, notarizes and publishes that version;
leave it and pushing changes nothing.

```shell
scripts/release.sh [patch|minor|major]   # default: patch
```

The Homebrew tap picks up the new release on its own.

## How the web page knows it is inside the app

The app adds `AmbientBGMApp/<version>` to the WebView's User-Agent and opens
`https://ambientbgm.com/?no-chat=1`. Either one makes the site hide its support
chat widget, which would otherwise cover the player in the small popover.

## License

MIT
