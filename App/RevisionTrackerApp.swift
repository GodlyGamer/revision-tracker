import SwiftUI
import UIKit
import WebKit

@main
struct RevisionTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            TrackerView()
                .ignoresSafeArea()
        }
    }
}

/// Hosts the bundled index.html in a full-screen WKWebView.
struct TrackerView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> WebViewController { WebViewController() }
    func updateUIViewController(_ uiViewController: WebViewController, context: Context) {}
}

/// Saves the app's data as a JSON file in Documents, so it survives app updates and
/// re-signing (as long as the bundle ID and Apple ID stay the same) and is visible in Files.
final class NativeStore {
    private var values: [String: String] = [:]
    private let fileURL: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = docs.appendingPathComponent("revision-tracker-data.json")
        if let data = try? Data(contentsOf: fileURL),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
            values = dict
        }
    }

    func set(_ key: String, _ value: String) {
        values[key] = value
        if let data = try? JSONSerialization.data(withJSONObject: values, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    /// JavaScript run before the page loads: exposes the saved values as window.__nativeStore.
    func bootstrapScript() -> String {
        let data = (try? JSONSerialization.data(withJSONObject: values)) ?? Data("{}".utf8)
        let json = String(data: data, encoding: .utf8) ?? "{}"
        return "window.__nativeStore = \(json);"
    }
}

/// Breaks the retain cycle between WKUserContentController and the view controller.
final class WeakScriptHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    init(_ target: WKScriptMessageHandler) { self.target = target }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}

final class WebViewController: UIViewController, WKUIDelegate, WKNavigationDelegate, WKScriptMessageHandler {
    private var webView: WKWebView!
    private let store = NativeStore()

    /// Matches the page ground so there is no white flash or white edge.
    private static let ground = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.black
            : UIColor(red: 0.894, green: 0.894, blue: 0.914, alpha: 1)
    }

    override func loadView() {
        let controller = WKUserContentController()
        controller.addUserScript(WKUserScript(source: store.bootstrapScript(),
                                              injectionTime: .atDocumentStart,
                                              forMainFrameOnly: true))
        controller.add(WeakScriptHandler(self), name: "store")
        controller.add(WeakScriptHandler(self), name: "exportBackup")

        let config = WKWebViewConfiguration()
        config.userContentController = controller
        config.websiteDataStore = .default()

        webView = WKWebView(frame: .zero, configuration: config)
        webView.uiDelegate = self
        webView.navigationDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = Self.ground
        webView.scrollView.backgroundColor = Self.ground
        webView.underPageBackgroundColor = Self.ground
        webView.allowsLinkPreview = false
        if #available(iOS 16.4, *) { webView.isInspectable = true }
        view = webView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        loadPage()
    }

    private func loadPage() {
        guard let url = Bundle.main.url(forResource: "index", withExtension: "html") else {
            webView.loadHTMLString("<p style='font:17px -apple-system;padding:40px'>index.html is missing from the app bundle.</p>", baseURL: nil)
            return
        }
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    // MARK: Messages from the page

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any] else { return }
        switch message.name {
        case "store":
            if let key = body["key"] as? String, let value = body["value"] as? String {
                store.set(key, value)
            }
        case "exportBackup":
            if let name = body["filename"] as? String, let json = body["json"] as? String {
                shareBackup(named: name, json: json)
            }
        default:
            break
        }
    }

    private func shareBackup(named name: String, json: String) {
        let safeName = name.replacingOccurrences(of: "/", with: "-")
        let fm = FileManager.default
        // Keep a copy in Documents/Backups (visible in Files > On My iPhone > Revision Tracker).
        let backups = fm.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Backups", isDirectory: true)
        try? fm.createDirectory(at: backups, withIntermediateDirectories: true)
        let kept = backups.appendingPathComponent(safeName)
        try? json.write(to: kept, atomically: true, encoding: .utf8)

        let tmp = fm.temporaryDirectory.appendingPathComponent(safeName)
        try? json.write(to: tmp, atomically: true, encoding: .utf8)

        let sheet = UIActivityViewController(activityItems: [tmp], applicationActivities: nil)
        if let pop = sheet.popoverPresentationController {
            pop.sourceView = view
            pop.sourceRect = CGRect(x: view.bounds.midX, y: 80, width: 1, height: 1)
        }
        topController().present(sheet, animated: true)
    }

    private func topController() -> UIViewController {
        var top: UIViewController = self
        while let next = top.presentedViewController { top = next }
        return top
    }

    // MARK: alert() and confirm() (WKWebView shows nothing unless the app does this)

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        topController().present(alert, animated: true)
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
        topController().present(alert, animated: true)
    }

    // MARK: Navigation

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url,
           navigationAction.navigationType == .linkActivated,
           url.scheme == "http" || url.scheme == "https" {
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    /// If iOS kills the web content process in the background, reload instead of showing a blank page.
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        loadPage()
    }
}
