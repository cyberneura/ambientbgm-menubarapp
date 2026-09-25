// main.swift - AmbientBGM Menubar App
import Cocoa
import WebKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var webViewController: WebViewController!
    var iconDefault: NSImage?
    var iconPlaying: NSImage?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        iconDefault = loadMenubarIcon("MenubarIcon")
        iconPlaying = loadMenubarIcon("MenubarIconPlaying")

        if let button = statusItem.button {
            button.image = iconDefault
            if iconDefault == nil { button.title = "🎵" }
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        webViewController = WebViewController(onPlaybackStateChanged: { [weak self] isPlaying in
            DispatchQueue.main.async {
                self?.updateIcon(isPlaying: isPlaying)
            }
        })

        popover = NSPopover()
        popover.contentSize = NSSize(width: 400, height: 700)
        popover.behavior = .transient
        // ツノ (arrow) を含むポップオーバーの枠はシステムが描画し、色を直接指定する
        // 公開 API が無い。外観をダーク固定にして、ページ背景 (webapp の layout.tsx が
        // 使う Tailwind の bg-zinc-950 = #09090b) に馴染ませる。
        // 指定しないと OS がライトモードのときに枠とツノが白くなる
        popover.appearance = NSAppearance(named: .darkAqua)
        popover.contentViewController = webViewController
    }

    private func loadMenubarIcon(_ name: String) -> NSImage? {
        guard let path = Bundle.main.path(forResource: name, ofType: "png"),
              let image = NSImage(contentsOfFile: path) else { return nil }
        image.isTemplate = true
        image.size = NSSize(width: 18, height: 18)
        return image
    }

    func updateIcon(isPlaying: Bool) {
        guard let button = statusItem.button else { return }
        button.image = isPlaying ? (iconPlaying ?? iconDefault) : iconDefault
    }

    @objc func handleClick() {
        guard let event = NSApp.currentEvent, let button = statusItem.button else { return }

        if event.type == .rightMouseUp {
            let menu = NSMenu()
            let reloadItem = NSMenuItem(title: "Reload", action: #selector(reloadPage), keyEquivalent: "")
            reloadItem.target = self
            menu.addItem(reloadItem)
            menu.addItem(NSMenuItem.separator())
            let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "")
            quitItem.target = self
            menu.addItem(quitItem)
            statusItem.menu = menu
            button.performClick(nil)
            statusItem.menu = nil
        } else {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
        }
    }

    @objc func reloadPage() {
        webViewController.reload()
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

// JS から再生状態を受け取るハンドラ
class PlaybackMessageHandler: NSObject, WKScriptMessageHandler {
    let onStateChanged: (Bool) -> Void

    init(onStateChanged: @escaping (Bool) -> Void) {
        self.onStateChanged = onStateChanged
    }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        if let body = message.body as? String {
            onStateChanged(body == "playing")
        }
    }
}

class WebViewController: NSViewController {
    var webView: WKWebView!
    var messageHandler: PlaybackMessageHandler!
    let onPlaybackStateChanged: (Bool) -> Void

    init(onPlaybackStateChanged: @escaping (Bool) -> Void) {
        self.onPlaybackStateChanged = onPlaybackStateChanged
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        messageHandler = PlaybackMessageHandler(onStateChanged: onPlaybackStateChanged)

        let config = WKWebViewConfiguration()
        config.userContentController.add(messageHandler, name: "playbackState")
        // ambientbgm.com はこのトークンを含む User-Agent にはチャット UI を出さない
        // (webapp/src/app/chatVisibility.ts)。ポップオーバーは狭く、左下のチャットが
        // プレイヤーに重なるため。
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        config.applicationNameForUserAgent = "AmbientBGMApp/\(version) (menubar)"

        // audio の play/pause イベントを監視して Swift に通知する JS
        let js = """
        (function() {
            function notifyState(state) {
                window.webkit.messageHandlers.playbackState.postMessage(state);
            }
            // 既存の audio 要素と動的に追加される要素の両方を監視
            document.addEventListener('play', function(e) {
                if (e.target.tagName === 'AUDIO' || e.target.tagName === 'VIDEO') {
                    notifyState('playing');
                }
            }, true);
            document.addEventListener('pause', function(e) {
                if (e.target.tagName === 'AUDIO' || e.target.tagName === 'VIDEO') {
                    notifyState('paused');
                }
            }, true);
            document.addEventListener('ended', function(e) {
                if (e.target.tagName === 'AUDIO' || e.target.tagName === 'VIDEO') {
                    notifyState('paused');
                }
            }, true);
        })();
        """
        let script = WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        config.userContentController.addUserScript(script)

        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 400, height: 700), configuration: config)
        // User-Agent と同じ目的の保険。?no-chat=1 はクエリだけでもチャット UI を消す
        webView.load(URLRequest(url: URL(string: "https://ambientbgm.com/?no-chat=1")!))
        self.view = webView
    }

    /// ページを再読み込みし、再生状態を「停止」に戻す。
    ///
    /// リロードすると audio 要素ごと破棄されて再生は止まるが、**破棄された要素からは
    /// pause / ended イベントが飛ばない**。そのため JS からの通知だけに任せると、
    /// メニューバーのアイコンが「再生中」のまま残る。
    ///
    /// リロードの起点は右クリックメニューの Reload と Cmd+R の 2 つあるので、
    /// どちらもこのメソッドを通す (片方だけ直すと、もう一方で同じ症状が残る)。
    func reload() {
        // 先にアイコンを戻す。reload() は非同期で、完了を待つと
        // その間だけ「再生中」のまま見えてしまう。
        onPlaybackStateChanged(false)

        // NSViewController の view は遅延生成なので、ポップオーバーを一度も開いて
        // いなければ webView はまだ存在しない。その場合は読み込むものが無い
        // (次に開いた時に読み込まれる) ので、アイコンを戻すだけで終える。
        guard isViewLoaded else { return }
        webView.reload()
    }

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "r" {
            reload()
        } else {
            super.keyDown(with: event)
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
