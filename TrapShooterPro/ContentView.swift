import SwiftUI
import WebKit
import UIKit

struct ContentView: View {
    var body: some View {
        WebContainer()
            .ignoresSafeArea()
            .background(Color.white)
    }
}

/// Hosts Web/index.html and connects it to the app through the "trap" message handler.
struct WebContainer: UIViewRepresentable {
    func makeCoordinator() -> Bridge { Bridge() }

    func makeUIView(context: Context) -> WKWebView {
        let bridge = context.coordinator
        let controller = WKUserContentController()
        let flag = "window.TRAP_NATIVE = { platform: 'ios', mic: true, version: '7.0' };"
        controller.addUserScript(WKUserScript(source: flag, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        controller.add(WeakMessageHandler(bridge), name: "trap")

        let config = WKWebViewConfiguration()
        config.userContentController = controller
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.websiteDataStore = .default()

        let web = WKWebView(frame: .zero, configuration: config)
        web.isOpaque = true
        web.backgroundColor = .white
        web.scrollView.backgroundColor = .white
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.uiDelegate = bridge
        web.navigationDelegate = bridge
        if #available(iOS 16.4, *) { web.isInspectable = true }
        bridge.web = web

        if let url = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Web") {
            web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            web.loadHTMLString("<h2 style='font-family:-apple-system;padding:40px 24px'>The Web folder is missing from the app. Add it to the project as a folder reference.</h2>", baseURL: nil)
        }
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

/// Avoids a retain cycle between WKUserContentController and the bridge.
final class WeakMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    init(_ target: WKScriptMessageHandler) { self.target = target }
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(controller, didReceive: message)
    }
}

/// Messages from the page: "mic" (start, stop, inputs), "save" (share sheet), "location".
final class Bridge: NSObject, WKScriptMessageHandler, WKUIDelegate, WKNavigationDelegate {
    weak var web: WKWebView?
    private lazy var mic = MicBridge(send: { [weak self] script in self?.run(script) },
                                     present: { [weak self] url in self?.share(url) })
    private lazy var location = LocationFetcher()

    func run(_ script: String) {
        DispatchQueue.main.async { [weak self] in
            self?.web?.evaluateJavaScript(script, completionHandler: nil)
        }
    }

    // MARK: messages from the page

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
        switch type {
        case "mic":
            mic.handle(body)
        case "save":
            save(name: body["name"] as? String ?? "file", base64: body["data"] as? String ?? "")
        case "location":
            location.fetch { [weak self] lat, lon, err in
                if let lat = lat, let lon = lon {
                    self?.run("window.__trapLocation && window.__trapLocation(\(lat), \(lon), null)")
                } else {
                    self?.run("window.__trapLocation && window.__trapLocation(null, null, '\(err ?? "unavailable")')")
                }
            }
        default:
            break // "status" feeds an Apple Watch app, not part of this build
        }
    }

    // MARK: files to the share sheet

    private func save(name: String, base64: String) {
        guard let data = Data(base64Encoded: base64) else { return }
        let safeName = name.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(safeName)
        do { try data.write(to: url, options: .atomic) } catch { return }
        share(url)
    }

    func share(_ url: URL) {
        DispatchQueue.main.async { [weak self] in
            guard let top = Bridge.topController() else { return }
            let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            if let pop = sheet.popoverPresentationController, let view = self?.web {
                pop.sourceView = view
                pop.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
            }
            top.present(sheet, animated: true)
        }
    }

    static func topController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap { $0.windows }.first { $0.isKeyWindow } ?? scenes.first?.windows.first
        var top = window?.rootViewController
        while let next = top?.presentedViewController { top = next }
        return top
    }

    // MARK: JavaScript alert and confirm

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        guard let top = Bridge.topController() else { completionHandler(); return }
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        top.present(alert, animated: true)
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        guard let top = Bridge.topController() else { completionHandler(false); return }
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
        top.present(alert, animated: true)
    }

    // MARK: links open in Safari, the app page stays

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url, let scheme = url.scheme?.lowercased(),
           ["http", "https", "mailto", "tel", "sms"].contains(scheme),
           navigationAction.targetFrame?.isMainFrame ?? true {
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url { UIApplication.shared.open(url) }
        return nil
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        mic.stop()
        webView.reload()
    }
}
