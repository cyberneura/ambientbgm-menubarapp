# AmbientBGM Menubar

ambientbgm.com を NSPopover の WKWebView で開くだけの macOS メニューバーアプリ。
`Sources/main.swift` 1 ファイルを `swiftc` で直接コンパイルする (Xcode プロジェクトも SwiftPM も無い)。
public リポジトリなので README・コード中の UI 文字列は英語、このファイルだけ日本語。

元は `cyberneura/ambientbgm` の `menubarapp/` にあった (CYBERNEURA-DEV-859 で分離)。
Web プレイヤー本体はあちらのリポジトリにある。

## ビルド

```shell
scripts/make-app.sh     # dist/AmbientBGMMenubar.app (universal, 未署名)
scripts/make-dmg.sh     # dist/AmbientBGMMenubar_<version>_universal.dmg
```

- `.icns` はコミットしない。`resources/AppIcon.png` から `make-app.sh` が毎回作る
- `Info.plist` は `packaging/Info.plist` の `__VERSION__` を `VERSION` で置き換えて作る
- **Linux ではビルドできない** (Cocoa / WebKit)。検証は PR CI の test job (macOS) に頼る

## リリース

**`VERSION` を main で上げるだけ** (`scripts/release.sh [patch|minor|major]`)。
`.github/workflows/release.yml` が「その version の Release が公開済みか」だけを見て、
未公開なら test → 署名・公証付き build → publish を走らせる。PR では test job だけが走る。

- 署名・公証には repository secrets `APPLE_CERTIFICATE` / `APPLE_CERTIFICATE_PASSWORD` /
  `APPLE_SIGNING_IDENTITY` / `APPLE_ID` / `APPLE_PASSWORD` / `APPLE_TEAM_ID` が要る。
  足りなければ build job の最初で止まる (未署名の dmg を出さないため)
- Homebrew の cask は `cyberneura/homebrew-tap` の `Casks/ambientbgm-menubar.rb`。
  tap 側が毎時最新 Release を見て自分を更新する

## チャット UI を出さない仕組み

User-Agent に `AmbientBGMApp/<version>` を足し、`?no-chat=1` 付きで開く。
ambientbgm.com (webapp の `chatVisibility.ts`) はどちらかがあればチャットウィジェットを出さない。
トークン名を変える時は webapp 側と揃えること。

## Mac App Store

将来 Mac App Store での配布を視野に入れている。その場合は App Sandbox の entitlements
(`com.apple.security.app-sandbox` + `com.apple.security.network.client`) と
Apple Distribution 証明書での署名が別途必要になる (現状の workflow は Developer ID 配布のみ)。
