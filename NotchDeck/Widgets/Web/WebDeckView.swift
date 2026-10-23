// WebDeckView.swift
// Min-Browser inspired web environment for NotchDeck.
// Merges the tab title and URL bar into a single unified row, with multi-tab support,
// persistent cookies/sessions, and background playback.

import AppKit
import AVFoundation
import SwiftUI
import WebKit

@MainActor
final class WebTabItem: NSObject, ObservableObject, Identifiable, WKNavigationDelegate, WKUIDelegate {
    let id: UUID
    @Published var title: String = "New Tab"
    @Published var currentURLString: String
    @Published var displayURL: String
    @Published var isEditing: Bool = false
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var isLoading: Bool = false
    @Published var estimatedProgress: Double = 0.0
    @Published private(set) var isLoaded: Bool = false

    weak var manager: WebDeckModel?
    private var _webView: FirstClickWebView?
    var webView: FirstClickWebView {
        ensureLoaded()
        return _webView!
    }

    private var progressObs: NSKeyValueObservation?
    private var titleObs: NSKeyValueObservation?
    private var urlObs: NSKeyValueObservation?
    private var canGoBackObs: NSKeyValueObservation?
    private var canGoForwardObs: NSKeyValueObservation?

    static let safariUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Safari/605.1.15"
    static let chromeUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36"

    static func userAgent(for url: URL?) -> String {
        guard let host = url?.host?.lowercased() else {
            return safariUserAgent
        }
        // WhatsApp and Google Chat web clients require Chromium UA
        if host.contains("whatsapp.com") || host.contains("chat.google.com") {
            return chromeUserAgent
        }
        // Google Search and general web use genuine Safari desktop UA
        // to prevent Google BotGuard unusual traffic / reCAPTCHA challenges
        return safariUserAgent
    }

    func updateUserAgent(for url: URL?) {
        let ua = Self.userAgent(for: url)
        if let wv = _webView, wv.customUserAgent != ua {
            wv.customUserAgent = ua
        }
    }

    static func clearGoogleSessionData(completion: (() -> Void)? = nil) {
        let store = WKWebsiteDataStore.default()
        store.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
            let googleRecords = records.filter {
                $0.displayName.localizedCaseInsensitiveContains("google") ||
                $0.displayName.localizedCaseInsensitiveContains("gstatic") ||
                $0.displayName.localizedCaseInsensitiveContains("recaptcha")
            }
            if !googleRecords.isEmpty {
                store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), for: googleRecords) {
                    completion?()
                }
            } else {
                completion?()
            }
        }
    }

    func clearSiteData() {
        guard let host = URL(string: currentURLString)?.host else { return }
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

    init(id: UUID = UUID(), urlString: String, lazy: Bool = false, startEditing: Bool = false, manager: WebDeckModel? = nil) {
        self.id = id
        self.currentURLString = urlString
        self.displayURL = startEditing ? "" : urlString
        self.isEditing = startEditing
        self.manager = manager
        super.init()

        // Derive initial clean title from URL host
        if let host = URL(string: urlString)?.host {
            let clean = host.replacingOccurrences(of: "www.", with: "")
            self.title = clean.capitalized
        }

        if !lazy {
            ensureLoaded()
        }
    }

    /// Lazily instantiates and loads the WKWebView only when the tab is first viewed.
    func ensureLoaded() {
        guard _webView == nil else { return }

        let config = WKWebViewConfiguration()
        // Shared processPool consolidates WebContent processes, minimizing RAM usage
        config.processPool = WebKitShared.processPool
        // Shared default websiteDataStore preserves logins/cookies/IndexedDB across all tabs
        config.websiteDataStore = .default()
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.preferences.isElementFullscreenEnabled = true
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.allowsAirPlayForMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.userContentController.addUserScript(BackgroundAudioScriptHelper.userScript)
        config.userContentController.addUserScript(GoogleDropdownScriptHelper.userScript)

        let wv = FirstClickWebView(frame: .zero, configuration: config)
        if #available(macOS 13.3, *) {
            wv.isInspectable = true
        }
        wv.customUserAgent = Self.userAgent(for: URL(string: currentURLString))
        wv.allowsBackForwardNavigationGestures = true
        self._webView = wv

        wv.navigationDelegate = self
        wv.uiDelegate = self

        // Observe web page title
        titleObs = wv.observe(\.title, options: [.new]) { [weak self] wv, _ in
            Task { @MainActor in
                if let t = wv.title?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
                    self?.title = t
                }
            }
        }

        // Observe loading progress
        progressObs = wv.observe(\.estimatedProgress, options: [.new]) { [weak self] wv, _ in
            Task { @MainActor in
                self?.estimatedProgress = wv.estimatedProgress
            }
        }

        // Observe back / forward availability
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

        // Observe URL changes
        urlObs = wv.observe(\.url, options: [.new]) { [weak self] wv, _ in
            Task { @MainActor in
                if let absolute = wv.url?.absoluteString, !absolute.isEmpty {
                    self?.currentURLString = absolute
                    if !(self?.isEditing ?? false) {
                        self?.displayURL = absolute
                    }
                    self?.canGoBack = wv.canGoBack
                    self?.canGoForward = wv.canGoForward
                    self?.manager?.persistTabs()
                }
            }
        }

        isLoaded = true
        load(urlString: currentURLString)
    }

    func load(urlString: String) {
        var trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if !trimmed.hasPrefix("http://") && !trimmed.hasPrefix("https://") {
            if trimmed.contains(".") && !trimmed.contains(" ") {
                trimmed = "https://" + trimmed
            } else {
                let query = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
                trimmed = "https://www.google.com/search?q=\(query)"
            }
        }

        self.currentURLString = trimmed
        self.displayURL = trimmed
        self.isEditing = false
        manager?.persistTabs()

        if isLoaded, let wv = _webView, let url = URL(string: trimmed) {
            updateUserAgent(for: url)
            wv.load(URLRequest(url: url))
        }
    }

    func reload() {
        if isLoaded {
            _webView?.reload()
        } else {
            ensureLoaded()
        }
    }

    func goBack() {
        guard let wv = _webView else { return }
        if wv.canGoBack {
            wv.goBack()
        } else {
            wv.evaluateJavaScript("window.history.back()")
        }
    }

    func goForward() {
        guard let wv = _webView else { return }
        if wv.canGoForward {
            wv.goForward()
        } else {
            wv.evaluateJavaScript("window.history.forward()")
        }
    }

    func zoomIn() {
        _webView?.pageZoom += 0.1
    }

    func zoomOut() {
        if let wv = _webView {
            wv.pageZoom = max(0.5, wv.pageZoom - 0.1)
        }
    }

    func resetZoom() {
        _webView?.pageZoom = 1.0
    }

    var iconName: String {
        let lower = (title + " " + currentURLString).lowercased()
        if lower.contains("chat.google.com") || lower.contains("google chat") { return "bubble.left.and.bubble.right.fill" }
        if lower.contains("spotify") { return "music.note" }
        if lower.contains("whatsapp") { return "message.fill" }
        if lower.contains("slack") { return "number" }
        if lower.contains("chatgpt") { return "sparkles" }
        if lower.contains("claude") { return "brain.head.profile" }
        if lower.contains("notion") { return "doc.text.fill" }
        if lower.contains("discord") { return "bubble.left.and.bubble.right.fill" }
        if lower.contains("youtube") { return "play.rectangle.fill" }
        if lower.contains("github") { return "terminal.fill" }
        if lower.contains("telegram") { return "paperplane.fill" }
        return "globe"
    }

    var brandColor: Color {
        let lower = (title + " " + currentURLString).lowercased()
        if lower.contains("chat.google.com") || lower.contains("google chat") { return Color(red: 0.0, green: 0.67, blue: 0.45) }
        if lower.contains("spotify") { return Color(red: 0.11, green: 0.73, blue: 0.33) }
        if lower.contains("whatsapp") { return Color(red: 0.15, green: 0.78, blue: 0.42) }
        if lower.contains("slack") { return Color(red: 0.88, green: 0.15, blue: 0.44) }
        if lower.contains("chatgpt") { return Color(red: 0.06, green: 0.65, blue: 0.54) }
        if lower.contains("claude") { return Color(red: 0.85, green: 0.45, blue: 0.25) }
        if lower.contains("discord") { return Color(red: 0.35, green: 0.4, blue: 0.95) }
        if lower.contains("youtube") { return Color.red }
        if lower.contains("telegram") { return Color(red: 0.16, green: 0.64, blue: 0.92) }
        return Color(white: 0.85)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let targetURL = navigationAction.request.url {
            updateUserAgent(for: targetURL)

            // If redirected to Google BotGuard captcha / sorry page, automatically purge bot-flagged session data
            if targetURL.absoluteString.contains("google.com/sorry") {
                Self.clearGoogleSessionData { [weak self] in
                    if let components = URLComponents(url: targetURL, resolvingAgainstBaseURL: false),
                       let continueParam = components.queryItems?.first(where: { $0.name == "continue" })?.value,
                       let cleanURL = URL(string: continueParam) {
                        DispatchQueue.main.async {
                            self?.webView.load(URLRequest(url: cleanURL))
                        }
                    }
                }
            }
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        isLoading = true
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoading = false
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        if let url = webView.url?.absoluteString {
            currentURLString = url
            if !isEditing {
                displayURL = url
            }
            manager?.persistTabs()
        }
        if let t = webView.title, !t.isEmpty {
            title = t
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
        // Automatically resurrect the WebContent process if it was terminated / crashed
        if let url = URL(string: currentURLString), !currentURLString.isEmpty {
            webView.load(URLRequest(url: url))
        } else {
            webView.reload()
        }
    }

    func webView(
        _ webView: WKWebView,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // Allows default handling of certificates and HTTP basic/digest authentication
        completionHandler(.performDefaultHandling, nil)
    }

    // MARK: - WKUIDelegate (Permissions, File Chooser, Dialogs, Popups)

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if let targetURL = navigationAction.request.url?.absoluteString, !targetURL.isEmpty && targetURL != "about:blank" {
            // Open new windows / target=_blank as a new tab
            manager?.createNewTab(urlString: targetURL, select: true, startEditing: false)
            return nil
        }
        // If JS called window.open() without an immediate URL, open a new tab and return its WKWebView
        // so WebKit routes the destination directly into the newly created tab
        if let mgr = manager {
            let newTab = mgr.createNewTab(urlString: "about:blank", select: true, startEditing: false)
            return newTab.webView
        }
        return nil
    }

    func webViewDidClose(_ webView: WKWebView) {
        if let tab = self.manager?.tabs.first(where: { $0.webView === webView }) {
            self.manager?.closeTab(id: tab.id)
        }
    }

    func webView(
        _ webView: WKWebView,
        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        type: WKMediaCaptureType,
        decisionHandler: @escaping (WKPermissionDecision) -> Void
    ) {
        if type == .microphone || type == .cameraAndMicrophone {
            if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    DispatchQueue.main.async {
                        decisionHandler(granted ? .grant : .deny)
                    }
                }
                return
            }
        } else if type == .camera {
            if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    DispatchQueue.main.async {
                        decisionHandler(granted ? .grant : .deny)
                    }
                }
                return
            }
        }
        decisionHandler(.grant)
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

    func destroy() {
        progressObs?.invalidate()
        titleObs?.invalidate()
        urlObs?.invalidate()
        canGoBackObs?.invalidate()
        canGoForwardObs?.invalidate()
        progressObs = nil
        titleObs = nil
        urlObs = nil
        canGoBackObs = nil
        canGoForwardObs = nil
        if let wv = _webView {
            wv.stopLoading()
            wv.navigationDelegate = nil
            wv.uiDelegate = nil
            wv.removeFromSuperview()
            _webView = nil
        }
        isLoaded = false
    }

    /// Discards the WKWebView from RAM to save memory while keeping tab metadata intact.
    func discard() {
        destroy()
    }
}

// MARK: - WebDeckModel

@MainActor
final class WebDeckModel: ObservableObject {
    static let shared = WebDeckModel()

    @Published var tabs: [WebTabItem] = []
    @Published var activeTabId: UUID?

    var activeTab: WebTabItem? {
        if let activeTabId, let match = tabs.first(where: { $0.id == activeTabId }) {
            return match
        }
        return tabs.first
    }

    init() {
        loadPersistedTabs()
    }

    @discardableResult
    func createNewTab(urlString: String = "https://www.google.com", select: Bool = true, startEditing: Bool = false) -> WebTabItem {
        // Reset editing state on existing tabs
        for tab in tabs {
            tab.isEditing = false
        }
        let newTab = WebTabItem(urlString: urlString, lazy: false, startEditing: startEditing, manager: self)
        tabs.append(newTab)
        if select {
            activeTabId = newTab.id
        }
        persistTabs()
        return newTab
    }

    func closeTab(id: UUID) {
        guard let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
        let tabToClose = tabs[idx]
        tabToClose.destroy()

        let wasActive = (activeTabId == id)
        tabs.remove(at: idx)

        if tabs.isEmpty {
            createNewTab(urlString: "https://www.google.com", select: true, startEditing: true)
        } else if wasActive {
            let nextIndex = max(0, min(idx, tabs.count - 1))
            activeTabId = tabs[nextIndex].id
            tabs[nextIndex].ensureLoaded()
        }
        persistTabs()
    }

    func selectTab(id: UUID) {
        for tab in tabs {
            if tab.id != id {
                tab.isEditing = false
            }
        }
        activeTabId = id
        activeTab?.ensureLoaded()
        persistTabs()
    }

    /// Suspends idle background tabs and flushes transient WebKit memory caches
    func optimizeMemory() {
        for tab in tabs {
            if tab.id != activeTabId && tab.isLoaded {
                tab.discard()
            }
        }
        WKWebsiteDataStore.default().removeData(
            ofTypes: [WKWebsiteDataTypeMemoryCache],
            modifiedSince: Date.distantPast
        ) { }
    }

    func openInExternalBrowser() {
        if let active = activeTab, let url = active.webView.url ?? URL(string: active.currentURLString) {
            NSWorkspace.shared.open(url)
        }
    }

    func openInBrowser(_ browser: InstalledBrowser) {
        if let active = activeTab, let url = active.webView.url ?? URL(string: active.currentURLString) {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.open([url], withApplicationAt: browser.appURL, configuration: config, completionHandler: nil)
        }
    }

    func persistTabs() {
        let urls = tabs.map { $0.currentURLString }
        UserDefaults.standard.set(urls, forKey: "notchdeck_web_tabs")
        if let activeId = activeTabId?.uuidString {
            UserDefaults.standard.set(activeId, forKey: "notchdeck_web_active_tab_id")
        }
    }

    private func loadPersistedTabs() {
        var restoredURLs = UserDefaults.standard.stringArray(forKey: "notchdeck_web_tabs") ?? []
        if restoredURLs.isEmpty {
            let legacy = UserDefaults.standard.string(forKey: "notchdeck_web_last_url") ?? "https://open.spotify.com/"
            restoredURLs = [legacy]
        }

        // Clean any old deprecated or CAPTCHA-redirected URLs
        var hadSorry = false
        restoredURLs = restoredURLs.map { url in
            if url.contains("google.com/sorry") {
                hadSorry = true
                return "https://www.google.com/"
            }
            if url.contains("app.slack.com/client") || url.contains("slack.com/help") {
                return "https://slack.com/signin"
            }
            return url
        }

        if hadSorry {
            WebTabItem.clearGoogleSessionData()
        }

        for (index, url) in restoredURLs.enumerated() {
            // Eagerly load only the first/active tab; all other tabs remain lazy with zero RAM until clicked
            let tab = WebTabItem(urlString: url, lazy: index > 0, startEditing: false, manager: self)
            tabs.append(tab)
        }

        if tabs.isEmpty {
            let tab = WebTabItem(urlString: "https://open.spotify.com/", lazy: false, startEditing: false, manager: self)
            tabs.append(tab)
        }

        activeTabId = tabs.first?.id
    }
}

// MARK: - WebDeckView

struct WebDeckView: View {

    @ObservedObject var model: WebDeckModel
    var viewModel: NotchViewModel? = nil
    @Environment(\.deckTheme) private var theme: DeckTheme

    init(model: WebDeckModel = WebDeckModel.shared, viewModel: NotchViewModel? = nil) {
        self.model = model
        self.viewModel = viewModel
    }

    var body: some View {
        VStack(spacing: 2) {
            // Single Unified Min-Browser Row: Nav (Pinned) + Adaptive Merged Tabs (Scrollable) + Action Buttons (Pinned)
            HStack(spacing: 8) {
                // Navigation buttons (Fixed on Left)
                if let activeTab = model.activeTab {
                    WebDeckNavButtons(tab: activeTab)
                } else {
                    WebDeckNavButtonsDisabled()
                }

                // Adaptive Merged Tabs Bar (Min-browser style: tab title is also omnibar)
                GeometryReader { geo in
                    let availableWidth = geo.size.width
                    let tabCount = model.tabs.count
                    let spacing: CGFloat = 4
                    let totalSpacing = CGFloat(max(0, tabCount - 1)) * spacing
                    let (activeWidth, inactiveWidth) = computeTabWidths(
                        availableWidth: availableWidth,
                        totalSpacing: totalSpacing,
                        count: tabCount
                    )

                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: spacing) {
                                ForEach(model.tabs) { tab in
                                    let isSelected = model.activeTabId == tab.id
                                    WebTabItemView(
                                        tab: tab,
                                        isSelected: isSelected,
                                        width: isSelected ? activeWidth : inactiveWidth,
                                        theme: theme,
                                        onSelect: {
                                            model.selectTab(id: tab.id)
                                        },
                                        onClose: {
                                            model.closeTab(id: tab.id)
                                        }
                                    )
                                    .id(tab.id)
                                }
                            }
                            .padding(.vertical, 1)
                        }
                        .onChange(of: model.activeTabId) { _, newId in
                            if let newId {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    proxy.scrollTo(newId, anchor: .center)
                                }
                            }
                        }
                    }
                }
                .frame(height: 28)

                // Action buttons (Fixed on Right)
                HStack(spacing: 6) {
                    // In-notch Zoom / Shrink Toggle Button (expands/shrinks the notch deck window like terminal)
                    if let vm = viewModel {
                        Button {
                            withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                                vm.toggleWebZoom()
                            }
                        } label: {
                            Image(systemName: vm.isWebZoomed ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(vm.isWebZoomed ? theme.primaryText : theme.secondaryText)
                                .frame(width: 26, height: 26)
                                .background(
                                    RoundedRectangle(cornerRadius: 7)
                                        .fill(vm.isWebZoomed ? theme.tabSelected : theme.inputBackground.opacity(0.6))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 7)
                                        .stroke(vm.isWebZoomed ? theme.accent.opacity(0.6) : Color.clear, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .pointingHandCursor()
                        .help(vm.isWebZoomed ? "Shrink Notch Deck (Zoom Out)" : "Zoom Notch Deck (Expand)")
                    }

                    // Plus button to add new tab
                    Button {
                        model.createNewTab(urlString: "https://www.google.com", select: true, startEditing: true)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(theme.secondaryText)
                            .frame(width: 26, height: 26)
                            .background(
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(theme.inputBackground.opacity(0.6))
                            )
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()
                    .help("New Tab (⌘T)")

                    // Open in External Browser (Hover reveals small browser dropdown)
                    ExternalBrowserMenuButton(model: model, theme: theme)
                }
                .layoutPriority(1)
            }
            .padding(.horizontal, 8)
            .padding(.top, 2)
            .padding(.bottom, 1)

            // Progress bar (integrated slim line under header)
            if let active = model.activeTab, active.isLoading {
                ProgressView(value: active.estimatedProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: theme.accent))
                    .frame(height: 2)
                    .padding(.horizontal, 8)
            }

            // Web Content Container: Multi-tab ZStack
            ZStack {
                ForEach(model.tabs) { tab in
                    if tab.isLoaded {
                        WebTabRepresentable(tab: tab)
                            .opacity(model.activeTabId == tab.id ? 1 : 0)
                            .allowsHitTesting(model.activeTabId == tab.id)
                    } else if model.activeTabId == tab.id {
                        VStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading \(tab.title)...")
                                .font(.system(size: 11))
                                .foregroundStyle(theme.secondaryText)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onAppear {
                            tab.ensureLoaded()
                        }
                    }
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
        .background(shortcutAnchors)
    }

    // Hidden Keyboard Shortcut anchors (0 layout impact)
    private var shortcutAnchors: some View {
        Group {
            Button("") { model.activeTab?.goBack() }
                .keyboardShortcut("[", modifiers: .command)
            Button("") { model.activeTab?.goForward() }
                .keyboardShortcut("]", modifiers: .command)
            Button("") { model.activeTab?.reload() }
                .keyboardShortcut("r", modifiers: .command)

            Button("") {
                model.createNewTab(urlString: "https://www.google.com", select: true, startEditing: true)
            }
            .keyboardShortcut("t", modifiers: .command)

            Button("") {
                if let activeId = model.activeTabId {
                    model.closeTab(id: activeId)
                }
            }
            .keyboardShortcut("w", modifiers: .command)

            Button("") { model.activeTab?.zoomIn() }
                .keyboardShortcut("+", modifiers: .command)
            Button("") { model.activeTab?.zoomIn() }
                .keyboardShortcut("=", modifiers: .command)
            Button("") { model.activeTab?.zoomOut() }
                .keyboardShortcut("-", modifiers: .command)
            Button("") { model.activeTab?.resetZoom() }
                .keyboardShortcut("0", modifiers: .command)
        }
        .frame(width: 0, height: 0)
        .opacity(0)
    }

    private func computeTabWidths(availableWidth: CGFloat, totalSpacing: CGFloat, count: Int) -> (active: CGFloat, inactive: CGFloat) {
        guard count > 0 else { return (180, 100) }
        let netWidth = max(0, availableWidth - totalSpacing)

        if count == 1 {
            // Single tab fills 100% of the middle bar edge-to-edge
            return (netWidth, 100)
        }

        let inactiveCount = CGFloat(count - 1)
        let minInactive: CGFloat = 68
        let minActive: CGFloat = 130

        // Adaptive ratio: active tab is slightly wider than inactive tabs
        // If 2 tabs: active ~55%, inactive ~45%
        // If 3 tabs: active ~42%, inactives ~29% each
        // If 5+ tabs: active ~28-32%
        let activeRatio = min(0.55, max(0.28, 1.0 / (CGFloat(count) * 0.75)))
        let proposedActive = max(minActive, netWidth * activeRatio)
        let remainingForInactive = max(0, netWidth - proposedActive)
        let rawInactive = remainingForInactive / inactiveCount

        if rawInactive >= minInactive {
            // Tabs expand to fill 100% of available width with ZERO gap
            let activeWidth = netWidth - (rawInactive * inactiveCount)
            return (activeWidth, rawInactive)
        } else {
            // Crowded tab bar: clamp tabs to comfortable minimums and allow smooth horizontal scrolling
            return (minActive, minInactive)
        }
    }
}

// MARK: - Navigation Buttons

private struct WebDeckNavButtons: View {
    @ObservedObject var tab: WebTabItem
    @Environment(\.deckTheme) private var theme: DeckTheme

    var body: some View {
        HStack(spacing: 2) {
            Button {
                tab.goBack()
            } label: {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(tab.canGoBack ? theme.primaryText : theme.tertiaryText.opacity(0.35))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .disabled(!tab.canGoBack)
            .pointingHandCursor()
            .help("Back (⌘[)")

            Button {
                tab.goForward()
            } label: {
                Image(systemName: "chevron.forward")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(tab.canGoForward ? theme.primaryText : theme.tertiaryText.opacity(0.35))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .disabled(!tab.canGoForward)
            .pointingHandCursor()
            .help("Forward (⌘])")

            Button {
                tab.reload()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(theme.secondaryText)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .pointingHandCursor()
            .help("Reload page (⌘R)")
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(Capsule().fill(theme.inputBackground.opacity(0.6)))
        .layoutPriority(1)
    }
}

private struct WebDeckNavButtonsDisabled: View {
    @Environment(\.deckTheme) private var theme: DeckTheme

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "chevron.backward")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.tertiaryText.opacity(0.35))
                .frame(width: 22, height: 22)

            Image(systemName: "chevron.forward")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.tertiaryText.opacity(0.35))
                .frame(width: 22, height: 22)

            Image(systemName: "arrow.clockwise")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(theme.tertiaryText.opacity(0.35))
                .frame(width: 22, height: 22)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(Capsule().fill(theme.inputBackground.opacity(0.6)))
        .layoutPriority(1)
    }
}

// MARK: - WebTabItemView (Min-browser merged Tab + URL)

struct WebTabItemView: View {
    @ObservedObject var tab: WebTabItem
    let isSelected: Bool
    let width: CGFloat
    let theme: DeckTheme
    let onSelect: () -> Void
    let onClose: () -> Void

    @FocusState private var isInputFocused: Bool
    @State private var isHovered: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            // Favicon / Brand Icon
            Image(systemName: tab.iconName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(isSelected ? tab.brandColor : theme.tertiaryText)
                .frame(width: 14)

            if isSelected && tab.isEditing {
                // Min browser editable search / URL input
                TextField("Search or enter address...", text: $tab.displayURL, onCommit: {
                    tab.load(urlString: tab.displayURL)
                    tab.isEditing = false
                })
                .textFieldStyle(.plain)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(theme.primaryText)
                .focused($isInputFocused)
                .onAppear {
                    isInputFocused = true
                }
                .onChange(of: isInputFocused) { _, focused in
                    if !focused {
                        tab.isEditing = false
                    }
                }
                .onExitCommand {
                    tab.isEditing = false
                }

                if !tab.displayURL.isEmpty {
                    Button {
                        tab.displayURL = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(theme.tertiaryText)
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()
                }
            } else {
                // Display mode: Page title + host
                HStack(spacing: 4) {
                    Text(tab.title.isEmpty ? "New Tab" : tab.title)
                        .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? theme.primaryText : theme.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    if isSelected && width > 160, let host = URL(string: tab.currentURLString)?.host, !host.isEmpty {
                        Text("•  \(host)")
                            .font(.system(size: 9.5, design: .monospaced))
                            .foregroundStyle(theme.tertiaryText.opacity(0.65))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .pointingHandCursor()
                .onTapGesture {
                    if isSelected {
                        tab.displayURL = tab.currentURLString
                        tab.isEditing = true
                    } else {
                        onSelect()
                    }
                }
            }

            Spacer(minLength: 0)

            // Close tab button (always show on active, or on hover for inactive)
            if isSelected || isHovered {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundStyle(theme.tertiaryText)
                        .frame(width: 14, height: 14)
                        .background(
                            Circle()
                                .fill(isHovered ? theme.tertiaryText.opacity(0.18) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .pointingHandCursor()
                .help("Close tab")
            }
        }
        .padding(.leading, 7)
        .padding(.trailing, (isSelected || isHovered) ? 5 : 7)
        .padding(.vertical, 3)
        .frame(width: max(40, width), height: 28)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? theme.inputBackground : (isHovered ? theme.inputBackground.opacity(0.4) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? theme.accent.opacity(0.65) : (isHovered ? theme.cardBorder.opacity(0.5) : Color.clear), lineWidth: 1)
        )
        .onHover { h in
            isHovered = h
        }
        .contextMenu {
            Button("Reload") { tab.reload() }
            Button("Duplicate Tab") {
                tab.manager?.createNewTab(urlString: tab.currentURLString, select: true, startEditing: false)
            }
            Divider()
            Button("Clear Site Data") {
                tab.clearSiteData()
            }
            Button("Reset Google Session") {
                WebTabItem.clearGoogleSessionData {
                    tab.load(urlString: "https://www.google.com")
                }
            }
            Divider()
            Button("Close Tab") { onClose() }
        }
    }
}

// MARK: - WebTabRepresentable

struct WebTabRepresentable: NSViewRepresentable {
    @ObservedObject var tab: WebTabItem

    func makeNSView(context: Context) -> WKWebView {
        DispatchQueue.main.async {
            if !tab.isEditing {
                tab.webView.window?.makeFirstResponder(tab.webView)
            }
        }
        return tab.webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        let isActive = (tab.id == tab.manager?.activeTabId)
        if isActive {
            nsView.alphaValue = 1.0
            nsView.isHidden = false
        } else {
            // Keep attached to window and visible to WebKit audio subsystem so background playback never pauses
            nsView.alphaValue = 0.001
            nsView.isHidden = false
        }
    }
}

// MARK: - InstalledBrowser Model

struct InstalledBrowser: Identifiable, Hashable {
    let id: String
    let name: String
    let appURL: URL
    let isDefault: Bool
    let icon: NSImage

    static func discoverAll() -> [InstalledBrowser] {
        guard let testURL = URL(string: "https://apple.com") else { return [] }
        let defaultAppURL = NSWorkspace.shared.urlForApplication(toOpen: testURL)
        let candidates = NSWorkspace.shared.urlsForApplications(toOpen: testURL)
        let knownKeywords = ["safari", "chrome", "zen", "brave", "firefox", "arc", "edge", "opera", "vivaldi", "orion"]

        var results: [InstalledBrowser] = []
        var seenNames = Set<String>()

        for appURL in candidates {
            let filename = appURL.deletingPathExtension().lastPathComponent
            let lower = filename.lowercased()
            if lower.contains("testing") || lower.contains("helper") { continue }
            guard knownKeywords.contains(where: { lower.contains($0) }) else { continue }
            guard !seenNames.contains(filename) else { continue }
            seenNames.insert(filename)

            let isDef = (appURL == defaultAppURL)
            let icon = NSWorkspace.shared.icon(forFile: appURL.path)
            let bundleId = Bundle(url: appURL)?.bundleIdentifier ?? appURL.path

            results.append(InstalledBrowser(
                id: bundleId,
                name: filename,
                appURL: appURL,
                isDefault: isDef,
                icon: icon
            ))
        }

        return results.sorted {
            if $0.isDefault != $1.isDefault {
                return $0.isDefault
            }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }
}

// MARK: - ExternalBrowserMenuButton (Hover Dropdown)

struct ExternalBrowserMenuButton: View {
    @ObservedObject var model: WebDeckModel
    let theme: DeckTheme

    @State private var installedBrowsers: [InstalledBrowser] = []
    @State private var isDropdownOpen: Bool = false
    @State private var isHoveringButton: Bool = false
    @State private var isHoveringMenu: Bool = false
    @State private var hoveredBrowserId: String? = nil
    @State private var hideTask: Task<Void, Never>? = nil

    var body: some View {
        Button {
            isDropdownOpen.toggle()
        } label: {
            Image(systemName: "arrow.up.forward.square")
                .font(.system(size: 12))
                .foregroundStyle(isDropdownOpen ? theme.accent : theme.secondaryText)
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(isDropdownOpen ? theme.accent.opacity(0.2) : theme.inputBackground.opacity(0.6))
                )
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
        .help("Open in Browser (Hover to choose)")
        .onHover { hovering in
            isHoveringButton = hovering
            if hovering {
                hideTask?.cancel()
                if installedBrowsers.isEmpty {
                    installedBrowsers = InstalledBrowser.discoverAll()
                }
                isDropdownOpen = true
            } else {
                scheduleHide()
            }
        }
        .popover(isPresented: $isDropdownOpen, arrowEdge: .bottom) {
            browserDropdownView
                .onHover { hovering in
                    isHoveringMenu = hovering
                    if hovering {
                        hideTask?.cancel()
                    } else {
                        scheduleHide()
                    }
                }
        }
        .contextMenu {
            ForEach(installedBrowsers.isEmpty ? InstalledBrowser.discoverAll() : installedBrowsers) { browser in
                Button {
                    model.openInBrowser(browser)
                } label: {
                    Text(browser.isDefault ? "\(browser.name) (Default)" : browser.name)
                }
            }
        }
    }

    private var browserDropdownView: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text("Open in Browser")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(theme.tertiaryText)
                Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.top, 4)
            .padding(.bottom, 2)

            ForEach(installedBrowsers) { browser in
                Button {
                    model.openInBrowser(browser)
                    isDropdownOpen = false
                } label: {
                    HStack(spacing: 8) {
                        Image(nsImage: browser.icon)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 16, height: 16)
                            .clipShape(RoundedRectangle(cornerRadius: 3.5))

                        Text(browser.name)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(theme.primaryText)
                            .lineLimit(1)

                        Spacer(minLength: 4)

                        if browser.isDefault {
                            Text("Default")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(theme.accent)
                                .padding(.horizontal, 4.5)
                                .padding(.vertical, 1.5)
                                .background(
                                    Capsule()
                                        .fill(theme.accent.opacity(0.18))
                                )
                        }
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4.5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(hoveredBrowserId == browser.id ? theme.inputBackground : Color.clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .pointingHandCursor()
                .onHover { h in
                    if h {
                        hoveredBrowserId = browser.id
                    } else if hoveredBrowserId == browser.id {
                        hoveredBrowserId = nil
                    }
                }
            }
        }
        .padding(6)
        .frame(width: 175)
    }

    private func scheduleHide() {
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(nanoseconds: 280_000_000) // 280ms grace period for smooth mouse transition
            if !Task.isCancelled {
                if !isHoveringButton && !isHoveringMenu {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isDropdownOpen = false
                    }
                }
            }
        }
    }
}

