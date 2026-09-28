# AmbientBGM Menubar

A macOS menu bar app for [AmbientBGM.com](https://ambientbgm.com), a free ambient
music player. Click the icon in the menu bar to open the player in a popover; the
icon changes while music is playing. Right-click for About, Third-Party Licenses,
Reload and Quit.

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

MIT. See [LICENSE](LICENSE).

## Third-party licenses

[THIRD-PARTY-NOTICES.txt](THIRD-PARTY-NOTICES.txt) lists the third-party libraries
bundled with the app. There are none at the moment: the app is built from its own
Swift sources and uses only the frameworks that come with macOS. In the app, the
same text is under **Third-Party Licenses…** in the right-click menu, just below
**About AmbientBGM Menubar**.

The file, and `Sources/ThirdPartyNotices.swift` which compiles it into the app,
are generated; do not edit them by hand:

```shell
scripts/generate-third-party-notices.sh           # rewrite both
scripts/generate-third-party-notices.sh --check   # fail if they are stale (run in CI)
```
