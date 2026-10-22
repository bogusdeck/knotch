// DedicatedWebView.swift
// High-performance dedicated web view tab for standalone web apps (WhatsApp, Slack, ChatGPT, etc.)
// Features shared WKProcessPool for minimal RAM usage, lazy loading, and in-notch zoom.

import AppKit
import AVFoundation
import SwiftUI
import WebKit

// MARK: - Shared WebKit Pool (RAM Optimization)

@MainActor
enum WebKitShared {
    /// Shared WKProcessPool across all web views (WebDeck, WhatsApp, Slack, Holder).
    /// Prevents WebKit from spawning separate OS WebProcess instances for each view,
    /// saving hundreds of megabytes of RAM.
    static let processPool = WKProcessPool()
}

// MARK: - First-Click Responsive WKWebView

/// WKWebView subclass that allows clicking into web controls, links, and text fields on the very first click,
/// without requiring an initial preparatory activation click.
class FirstClickWebView: WKWebView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
}

// MARK: - Google Dropdown & Modal Stability Script Helper

@MainActor
enum GoogleDropdownScriptHelper {
    static let scriptSource = """
    (function() {
        if (window.__notchdeck_google_dropdown_fix) return;
        window.__notchdeck_google_dropdown_fix = true;

        // When focus shifts into a Google Account iframe or dropdown element,
        // prevent window blur from triggering OneGoogleBar's automatic teardown.
        window.addEventListener('blur', function(e) {
            var active = document.activeElement;
            if (active && (active.tagName === 'IFRAME' || active.getAttribute('role') === 'presentation')) {
                e.stopImmediatePropagation();
            }
        }, true);
    })();
    """

    static var userScript: WKUserScript {
        WKUserScript(
            source: scriptSource,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
    }
}

// MARK: - Background Audio Script Helper (YouTube, Spotify, Soundcloud, etc.)

@MainActor
enum BackgroundAudioScriptHelper {
    static let scriptSource = """
    (function() {
        if (window.__notchdeck_bg_audio_ready) return;
        window.__notchdeck_bg_audio_ready = true;

        // Prevent YouTube, Spotify, and web media players from pausing when the drawer closes or unfocuses
        try {
            Object.defineProperty(document, 'hidden', {
                get: function() { return false; },
                configurable: true
            });
            Object.defineProperty(document, 'visibilityState', {
                get: function() { return 'visible'; },
                configurable: true
            });
            Object.defineProperty(document, 'webkitHidden', {
                get: function() { return false; },
                configurable: true
            });
            Object.defineProperty(document, 'webkitVisibilityState', {
                get: function() { return 'visible'; },
                configurable: true
            });
        } catch(e) {}

        // Stop visibilitychange events from firing pause hooks
        window.addEventListener('visibilitychange', function(e) {
            e.stopImmediatePropagation();
        }, true);
        document.addEventListener('visibilitychange', function(e) {
            e.stopImmediatePropagation();
        }, true);
    })();
    """

    static var userScript: WKUserScript {
        WKUserScript(
            source: scriptSource,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
    }
}

// MARK: - WhatsApp Notification & Unread Watcher Script Helper

@MainActor
enum WhatsAppNotificationScriptHelper {
    static let scriptSource = """
    (function() {
        if (window.__notchdeck_wa_hooked) return;
        window.__notchdeck_wa_hooked = true;

        function postUnread(count) {
            try {
                window.webkit.messageHandlers.waNotificationHandler.postMessage({
                    type: 'unread',
                    count: count
                });
            } catch(e) {}
        }

        // Intercept Web Notification API
        var OrigNotification = window.Notification;
        if (OrigNotification) {
            function CustomNotification(title, options) {
                try {
                    window.webkit.messageHandlers.waNotificationHandler.postMessage({
                        type: 'notification',
                        title: title || ''
                    });
                } catch(e) {}
                return new OrigNotification(title, options);
            }
            CustomNotification.prototype = OrigNotification.prototype;
            CustomNotification.permission = 'granted';
            CustomNotification.requestPermission = function(cb) {
                if (cb) cb('granted');
                return Promise.resolve('granted');
            };
            window.Notification = CustomNotification;
        }

        function checkTitle() {
            var title = document.title || '';
            var match = title.match(/\\(([0-9]+)\\)/);
            if (match && match[1]) {
                var c = parseInt(match[1], 10) || 0;
                postUnread(c);
            } else if (title.indexOf('*') !== -1) {
                postUnread(1);
            } else {
                postUnread(0);
            }
        }

        setInterval(checkTitle, 1500);

        var titleEl = document.querySelector('title');
        if (titleEl) {
            var obs = new MutationObserver(checkTitle);
            obs.observe(titleEl, { subtree: true, characterData: true, childList: true });
        }
    })();
    """

    static var userScript: WKUserScript {
        WKUserScript(
            source: scriptSource,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
    }
}

// MARK: - DedicatedWebModel Registry (Persistent Web Apps)

@MainActor
final class DedicatedWebModelRegistry {
    static let shared = DedicatedWebModelRegistry()

    private var models: [String: DedicatedWebModel] = [:]

    func model(id: String, defaultURL: URL, userAgent: String) -> DedicatedWebModel {
        if let existing = models[id] {
            return existing
        }
        let m = DedicatedWebModel(id: id, defaultURL: defaultURL, userAgent: userAgent)
        models[id] = m
        return m
    }
}

// MARK: - DedicatedWebModel

@MainActor
final class DedicatedWebModel: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    let id: String
    let defaultURL: URL
    let userAgent: String

    @Published var webView: WKWebView?
    @Published var isLoading: Bool = false
    @Published var estimatedProgress: Double = 0.0
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var currentURL: URL
    @Published var pageTitle: String = ""
    @Published var micStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    @Published var unreadCount: Int = 0

    private var progressObs: NSKeyValueObservation?
    private var titleObs: NSKeyValueObservation?
    private var urlObs: NSKeyValueObservation?
    private var canGoBackObs: NSKeyValueObservation?
    private var canGoForwardObs: NSKeyValueObservation?

    init(id: String = UUID().uuidString, defaultURL: URL, userAgent: String) {
        self.id = id
        self.defaultURL = defaultURL
        self.currentURL = defaultURL
        self.userAgent = userAgent
        super.init()
        checkMicrophonePermission()
    }

    func checkMicrophonePermission() {
        micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    }

    func updateUnreadFromTitle(_ title: String) {
        var count = 0
        if let match = title.range(of: #"\(([0-9]+)\)"#, options: .regularExpression) {
            let numStr = title[match].dropFirst().dropLast()
            count = Int(numStr) ?? 1
        } else if title.contains("*") {
            count = 1
        }
        if self.unreadCount != count {
            self.unreadCount = count
            NotificationCenter.default.post(
                name: .whatsAppUnreadCountChanged,
                object: nil,
                userInfo: ["count": count, "source": self.id]
            )
        }
    }

    func requestMicrophoneAccess(completion: ((Bool) -> Void)? = nil) {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            micStatus = .authorized
            completion?(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                Task { @MainActor in
                    self?.micStatus = granted ? .authorized : .denied
                    completion?(granted)
                }
            }
        case .denied, .restricted:
            micStatus = status
            completion?(false)
        @unknown default:
            completion?(false)
        }
    }

    func openMicrophonePrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Lazily instantiates and loads the WKWebView only when the tab is first viewed.
    func ensureLoaded() {
        guard webView == nil else { return }

        // If mic permission hasn't been requested yet, prompt immediately on load
        if micStatus == .notDetermined {
            requestMicrophoneAccess()
        }

        let config = WKWebViewConfiguration()
        config.processPool = WebKitShared.processPool
        config.websiteDataStore = .default()
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.preferences.isElementFullscreenEnabled = true
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.allowsAirPlayForMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.userContentController.addUserScript(BackgroundAudioScriptHelper.userScript)
        config.userContentController.addUserScript(GoogleDropdownScriptHelper.userScript)

        if id == "whatsapp" {
            config.userContentController.add(self, name: "waNotificationHandler")
            config.userContentController.addUserScript(WhatsAppNotificationScriptHelper.userScript)
        }

        let wv = FirstClickWebView(frame: .zero, configuration: config)
        if #available(macOS 13.3, *) {
            wv.isInspectable = true
        }
        let initialUA = Self.userAgent(for: defaultURL, fallback: userAgent)
        wv.customUserAgent = initialUA
        wv.allowsBackForwardNavigationGestures = true
        self.webView = wv

        wv.navigationDelegate = self
        wv.uiDelegate = self

        titleObs = wv.observe(\.title, options: [.new]) { [weak self] wv, _ in
            Task { @MainActor in
                if let t = wv.title?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
                    self?.pageTitle = t
                    if self?.id == "whatsapp" || self?.id == "googlechat" {
                        self?.updateUnreadFromTitle(t)
                    }
                }
            }
        }

        progressObs = wv.observe(\.estimatedProgress, options: [.new]) { [weak self] wv, _ in
            Task { @MainActor in
                self?.estimatedProgress = wv.estimatedProgress
            }
        }

        canGoBackObs = wv.observe(\.canGoBack, options: [.initial, .new]) { [weak self] wv, _ in
            Task { @MainActor in
                self?.canGoBack = wv.canGoBack
            }
        }

        canGoForwardObs = wv.observe(\.canGoForward, options: [.initial, .new]) { [weak self] wv, _ in
            Task { @MainActor in
                self?.canGoForward = wv.canGoForward
            }
        }

        urlObs = wv.observe(\.url, options: [.new]) { [weak self] wv, _ in
            Task { @MainActor in
                if let u = wv.url {
                    self?.currentURL = u
                    self?.canGoBack = wv.canGoBack
                    self?.canGoForward = wv.canGoForward
                }
            }
        }

        wv.load(URLRequest(url: defaultURL))
    }

    static func userAgent(for url: URL?, fallback: String) -> String {
        guard let host = url?.host?.lowercased() else { return fallback }
        // Google authentication (accounts.google.com) requires genuine Safari desktop UA
        // so Google invokes Apple's native iCloud Keychain / Touch ID Passkey modal sheet
        // instead of expecting Chrome proprietary Credential Manager extensions.
        if host.contains("accounts.google.com") || host.contains("myaccount.google.com") {
            return WebTabItem.safariUserAgent
        }
        if host.contains("slack.com") || host.contains("whatsapp.com") || host.contains("chat.google.com") {
            return WebTabItem.chromeUserAgent
        }
        return fallback
    }

    func updateUserAgent(for url: URL?) {
        let ua = Self.userAgent(for: url, fallback: self.userAgent)
        if let wv = webView, wv.customUserAgent != ua {
            wv.customUserAgent = ua
        }
    }

    func reload() {
        webView?.reload()
    }

    func load(url: URL) {
        currentURL = url
        updateUserAgent(for: url)
        webView?.load(URLRequest(url: url))
    }

    func goBack() {
        if let wv = webView, wv.canGoBack {
            wv.goBack()
        } else {
            webView?.evaluateJavaScript("window.history.back()")
        }
    }

    func goForward() {
        if let wv = webView, wv.canGoForward {
            wv.goForward()
        } else {
            webView?.evaluateJavaScript("window.history.forward()")
        }
    }

    func zoomIn() {
        if let wv = webView {
            wv.pageZoom += 0.1
        }
    }

    func zoomOut() {
        if let wv = webView {
            wv.pageZoom = max(0.5, wv.pageZoom - 0.1)
        }
    }

    func resetZoom() {
        webView?.pageZoom = 1.0
    }

    func openInDefaultBrowser() {
        let target = webView?.url ?? currentURL
        NSWorkspace.shared.open(target)
    }

    func openInBrowser(_ browser: InstalledBrowser) {
        let target = webView?.url ?? currentURL
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.open([target], withApplicationAt: browser.appURL, configuration: config, completionHandler: nil)
    }

    func clearSiteData() {
        guard let host = (webView?.url ?? currentURL).host else { return }
        let store = WKWebsiteDataStore.default()
        store.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { [weak self] records in
            let matches = records.filter { $0.displayName.localizedCaseInsensitiveContains(host) }
            if !matches.isEmpty {
                store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), for: matches) {
                    DispatchQueue.main.async {
                        self?.reload()
                    }
                }
            }
        }
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        isLoading = true
        updateUserAgent(for: webView.url)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoading = false
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        if let u = webView.url {
            currentURL = u
        }
        if let t = webView.title, !t.isEmpty {
            pageTitle = t
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        isLoading = false
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        isLoading = false
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        isLoading = false
        // Auto-recover from background process suspension
        webView.load(URLRequest(url: currentURL))
    }

    func webView(
        _ webView: WKWebView,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        completionHandler(.performDefaultHandling, nil)
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        updateUserAgent(for: url)

        // New window/tab requested (target="_blank" or window.open)
        if navigationAction.targetFrame == nil {
            let host = url.host?.lowercased() ?? ""
            // Keep auth, login, account switchers, and in-service domains inside this web view
            if host.contains("accounts.google.com") ||
               host.contains("google.com") ||
               host.contains("whatsapp.com") ||
               host.contains("slack.com") ||
               host.contains("cdadebate.com") ||
               (!host.isEmpty && host == (currentURL.host?.lowercased() ?? "")) {
                webView.load(navigationAction.request)
                decisionHandler(.cancel)
                return
            } else {
                // Open external links (e.g. shared articles) in user's default browser
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
                return
            }
        }

        decisionHandler(.allow)
    }

    // MARK: - WKUIDelegate (Permissions, File Chooser, Dialogs)

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if let targetURL = navigationAction.request.url {
            let host = targetURL.host?.lowercased() ?? ""
            if host.contains("accounts.google.com") ||
               host.contains("google.com") ||
               host.contains("whatsapp.com") ||
               host.contains("slack.com") ||
               host.contains("cdadebate.com") ||
               (!host.isEmpty && host == (currentURL.host?.lowercased() ?? "")) {
                webView.load(navigationAction.request)
                return nil
            }
            // Open genuinely external URLs in the user's default browser
            NSWorkspace.shared.open(targetURL)
        }
        return nil
    }

    func webView(
        _ webView: WKWebView,
        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        type: WKMediaCaptureType,
        decisionHandler: @escaping (WKPermissionDecision) -> Void
    ) {
        if type == .microphone || type == .cameraAndMicrophone {
            requestMicrophoneAccess { granted in
                decisionHandler(granted ? .grant : .deny)
            }
        } else if type == .camera {
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    decisionHandler(granted ? .grant : .deny)
                }
            }
        } else {
            decisionHandler(.grant)
        }
    }

    func webView(
        _ webView: WKWebView,
        runOpenPanelWith parameters: WKOpenPanelParameters,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping ([URL]?) -> Void
    ) {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = parameters.allowsDirectories
        openPanel.allowsMultipleSelection = parameters.allowsMultipleSelection
        openPanel.begin { result in
            if result == .OK {
                completionHandler(openPanel.urls)
            } else {
                completionHandler(nil)
            }
        }
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping () -> Void
    ) {
        let alert = NSAlert()
        alert.messageText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
        completionHandler()
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (Bool) -> Void
    ) {
        let alert = NSAlert()
        alert.messageText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        let response = alert.runModal()
        completionHandler(response == .alertFirstButtonReturn)
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptTextInputPanelWithPrompt prompt: String,
        defaultText: String?,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (String?) -> Void
    ) {
        let alert = NSAlert()
        alert.messageText = prompt
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        input.stringValue = defaultText ?? ""
        alert.accessoryView = input
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            completionHandler(input.stringValue)
        } else {
            completionHandler(nil)
        }
    }

    deinit {
        progressObs?.invalidate()
        titleObs?.invalidate()
        urlObs?.invalidate()
    }
}

// MARK: - WKScriptMessageHandler (WhatsApp Notifications)

extension DedicatedWebModel: WKScriptMessageHandler {
    nonisolated func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "waNotificationHandler", let dict = message.body as? [String: Any] else { return }
        let type = dict["type"] as? String
        Task { @MainActor in
            if type == "unread", let count = dict["count"] as? Int {
                if self.unreadCount != count {
                    self.unreadCount = count
                    NotificationCenter.default.post(name: .whatsAppUnreadCountChanged, object: nil, userInfo: ["count": count])
                }
            } else if type == "notification" {
                let current = max(self.unreadCount, 1)
                self.unreadCount = current
                NotificationCenter.default.post(name: .whatsAppUnreadCountChanged, object: nil, userInfo: ["count": current])
            }
        }
    }
}

// MARK: - DedicatedWebView (SwiftUI)

struct DedicatedWebView: View {
    let id: String
    let title: String
    let icon: String
    let brandColor: Color
    let defaultURL: URL
    let userAgent: String
    var viewModel: NotchViewModel? = nil

    @ObservedObject private var model: DedicatedWebModel
    @Environment(\.deckTheme) private var theme: DeckTheme

    init(
        id: String = "dedicated",
        title: String,
        icon: String,
        brandColor: Color,
        defaultURL: URL,
        userAgent: String = WebTabItem.chromeUserAgent,
        viewModel: NotchViewModel? = nil
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.brandColor = brandColor
        self.defaultURL = defaultURL
        self.userAgent = userAgent
        self.viewModel = viewModel
        self.model = DedicatedWebModelRegistry.shared.model(id: id, defaultURL: defaultURL, userAgent: userAgent)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack(spacing: 8) {
                // App Brand Badge & Host
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(brandColor)

                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.primaryText)

                    if let host = (model.webView?.url ?? defaultURL).host {
                        Text(host)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(theme.tertiaryText)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(theme.inputBackground.opacity(0.6)))
                    }
                }

                Spacer()

                // Navigation Controls (Back, Forward, Reload)
                HStack(spacing: 3) {
                    Button { model.goBack() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .semibold))
                            .frame(width: 24, height: 24)
                            .foregroundStyle(model.canGoBack ? theme.primaryText : theme.tertiaryText.opacity(0.4))
                            .background(RoundedRectangle(cornerRadius: 6).fill(theme.inputBackground.opacity(0.5)))
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()
                    .disabled(!model.canGoBack)
                    .help("Back (⌘[)")

                    Button { model.goForward() } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .frame(width: 24, height: 24)
                            .foregroundStyle(model.canGoForward ? theme.primaryText : theme.tertiaryText.opacity(0.4))
                            .background(RoundedRectangle(cornerRadius: 6).fill(theme.inputBackground.opacity(0.5)))
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()
                    .disabled(!model.canGoForward)
                    .help("Forward (⌘])")

                    Button { model.reload() } label: {
                        Image(systemName: model.isLoading ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                            .font(.system(size: 10, weight: .semibold))
                            .frame(width: 24, height: 24)
                            .foregroundStyle(theme.secondaryText)
                            .background(RoundedRectangle(cornerRadius: 6).fill(theme.inputBackground.opacity(0.5)))
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()
                    .help("Reload (⌘R)")
                }

                // Microphone Access Button
                Button {
                    if model.micStatus == .denied || model.micStatus == .restricted {
                        model.openMicrophonePrivacySettings()
                    } else {
                        model.requestMicrophoneAccess()
                    }
                } label: {
                    Image(systemName: model.micStatus == .authorized ? "mic.fill" : (model.micStatus == .denied ? "mic.slash.fill" : "mic"))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(model.micStatus == .authorized ? Color.green : (model.micStatus == .denied ? Color.red : theme.secondaryText))
                        .frame(width: 24, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(model.micStatus == .authorized ? Color.green.opacity(0.12) : theme.inputBackground.opacity(0.5))
                        )
                }
                .buttonStyle(.plain)
                .pointingHandCursor()
                .help(model.micStatus == .authorized ? "Microphone Access Granted" : (model.micStatus == .denied ? "Microphone Denied (Click to open System Settings)" : "Click to grant Microphone access"))

                // Quick Switch to tanish.vashisth@cdadebate.com for Google Chat
                if id == "googlechat" {
                    Button {
                        if let url = URL(string: "https://accounts.google.com/AccountChooser?service=dynamite&Email=tanish.vashisth@cdadebate.com&continue=https://chat.google.com") {
                            model.load(url: url)
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "person.crop.circle.badge.checkmark")
                                .font(.system(size: 9, weight: .bold))
                            Text("tanish.vashisth@cdadebate.com")
                                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                                .lineLimit(1)
                        }
                        .foregroundStyle(Color(red: 0.0, green: 0.72, blue: 0.48))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(red: 0.0, green: 0.72, blue: 0.48).opacity(0.12))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(red: 0.0, green: 0.72, blue: 0.48).opacity(0.35), lineWidth: 0.75)
                        )
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()
                    .help("Switch to tanish.vashisth@cdadebate.com")
                }

                // In-notch Zoom / Shrink Toggle Button
                if let vm = viewModel {
                    Button {
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                            vm.toggleWebZoom()
                        }
                    } label: {
                        Image(systemName: vm.isWebZoomed ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(vm.isWebZoomed ? theme.primaryText : theme.secondaryText)
                            .frame(width: 24, height: 24)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(vm.isWebZoomed ? theme.tabSelected : theme.inputBackground.opacity(0.5))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(vm.isWebZoomed ? theme.accent.opacity(0.6) : Color.clear, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()
                    .help(vm.isWebZoomed ? "Shrink View (Zoom Out)" : "Zoom View (Expand)")
                }

                // Open in External Browser Menu Button
                DedicatedExternalBrowserButton(model: model, theme: theme)

                // More Menu
                Menu {
                    if id == "googlechat" {
                        Button("Sign in / Switch to tanish.vashisth@cdadebate.com") {
                            if let url = URL(string: "https://accounts.google.com/AccountChooser?service=dynamite&Email=tanish.vashisth@cdadebate.com&continue=https://chat.google.com") {
                                model.load(url: url)
                            }
                        }
                        Divider()
                    }
                    Button("Reload Page") { model.reload() }
                    Button("Request Microphone Permission") { model.requestMicrophoneAccess() }
                    Button("Microphone Privacy Settings") { model.openMicrophonePrivacySettings() }
                    Divider()
                    Button("Open in Default Browser") { model.openInDefaultBrowser() }
                    Divider()
                    Button("Clear Cookies & Cache") { model.clearSiteData() }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(theme.secondaryText)
                        .frame(width: 24, height: 24)
                        .background(RoundedRectangle(cornerRadius: 6).fill(theme.inputBackground.opacity(0.5)))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .pointingHandCursor()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)

            // Progress Bar
            if model.isLoading {
                ProgressView(value: model.estimatedProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: brandColor))
                    .frame(height: 2)
                    .padding(.horizontal, 8)
            }

            // Web Content Container
            ZStack {
                if let wv = model.webView {
                    DedicatedWebViewRepresentable(webView: wv)
                } else {
                    VStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Connecting to \(title)...")
                            .font(.system(size: 11))
                            .foregroundStyle(theme.tertiaryText)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(theme.cardBorder, lineWidth: 1)
            )
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // Lazy load WKWebView on first view
            model.ensureLoaded()
        }
        .background(shortcutAnchors)
    }

    private var shortcutAnchors: some View {
        Group {
            Button("") { model.goBack() }
                .keyboardShortcut("[", modifiers: .command)
            Button("") { model.goForward() }
                .keyboardShortcut("]", modifiers: .command)
            Button("") { model.reload() }
                .keyboardShortcut("r", modifiers: .command)
            Button("") { model.zoomIn() }
                .keyboardShortcut("+", modifiers: .command)
            Button("") { model.zoomIn() }
                .keyboardShortcut("=", modifiers: .command)
            Button("") { model.zoomOut() }
                .keyboardShortcut("-", modifiers: .command)
            Button("") { model.resetZoom() }
                .keyboardShortcut("0", modifiers: .command)
        }
        .frame(width: 0, height: 0)
        .opacity(0)
    }
}

// MARK: - Representable

private struct DedicatedWebViewRepresentable: NSViewRepresentable {
    let webView: WKWebView

    func makeNSView(context: Context) -> WKWebView {
        DispatchQueue.main.async {
            webView.window?.makeFirstResponder(webView)
        }
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
}

// MARK: - Dedicated External Browser Menu Button

private struct DedicatedExternalBrowserButton: View {
    @ObservedObject var model: DedicatedWebModel
    let theme: DeckTheme
    @State private var installedBrowsers: [InstalledBrowser] = []

    var body: some View {
        Menu {
            Button {
                model.openInDefaultBrowser()
            } label: {
                Label("Open in Default Browser", systemImage: "arrow.up.forward.square")
            }

            if !installedBrowsers.isEmpty {
                Divider()
                ForEach(installedBrowsers) { browser in
                    Button {
                        model.openInBrowser(browser)
                    } label: {
                        HStack {
                            Image(nsImage: browser.icon)
                            Text("Open in \(browser.name)\(browser.isDefault ? " (Default)" : "")")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.forward.square")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(theme.secondaryText)
                .frame(width: 24, height: 24)
                .background(RoundedRectangle(cornerRadius: 6).fill(theme.inputBackground.opacity(0.5)))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .pointingHandCursor()
        .help("Open tab in external browser")
        .onAppear {
            installedBrowsers = InstalledBrowser.discoverAll()
        }
    }
}
