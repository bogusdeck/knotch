// HolderView.swift
// Desktop Environment canvas for the Holder tab.
// Displays pinned applications, PDFs, and files with one-click launch, embedded PDF reading, and drag-and-drop.

import AppKit
import PDFKit
import SwiftUI
import UniformTypeIdentifiers
import WebKit

struct HolderView: View {

    @ObservedObject var holderManager: HolderManager
    var viewModel: NotchViewModel? = nil
    @Environment(\.deckTheme) private var theme: DeckTheme
    @State private var isTargetedForDrop: Bool = false
    @State private var hoveredItemId: UUID? = nil

    private var isActivelyDragging: Bool {
        isTargetedForDrop || (viewModel?.isDraggingOverNotch == true)
    }

    private var appItems: [HolderItem] {
        holderManager.items.filter { $0.isApplication }
    }

    private var documentItems: [HolderItem] {
        holderManager.items.filter { !$0.isApplication }
    }

    private let appColumns = [
        GridItem(.adaptive(minimum: 88, maximum: 110), spacing: 14)
    ]

    private let docColumns = [
        GridItem(.adaptive(minimum: 100, maximum: 130), spacing: 12)
    ]

    var body: some View {
        ZStack {
            if let activeApp = holderManager.activeEmbeddedAppItem, let webURL = activeApp.webCompanionURL {
                embeddedWebAppView(for: activeApp, url: webURL)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else if let previewItem = holderManager.selectedItemForPreview {
                embeddedPreviewView(for: previewItem)
            } else {
                mainCanvasView
            }

            if isActivelyDragging {
                dropHereOverlay
                    .zIndex(100)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDrop(of: DropURLHelper.supportedDropTypes, isTargeted: $isTargetedForDrop) { providers in
            handleDrop(providers: providers)
        }
    }

    // MARK: - Main Canvas View

    private var mainCanvasView: some View {
        VStack(spacing: 8) {
            // Header Bar
            headerBar

            // Scrollable Desktop Items
            ScrollView(.vertical, showsIndicators: false) {
                if holderManager.items.isEmpty {
                    emptyHolderView
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        // Applications Section
                        if !appItems.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    Image(systemName: "app.badge.fill")
                                        .font(.system(size: 11))
                                        .foregroundStyle(theme.accent)
                                    Text("Applications")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(theme.primaryText)

                                    Text("\(appItems.count)")
                                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 1)
                                        .background(Capsule().fill(theme.inputBackground))
                                        .foregroundStyle(theme.secondaryText)
                                }
                                .padding(.horizontal, 14)

                                LazyVGrid(columns: appColumns, spacing: 14) {
                                    ForEach(appItems) { item in
                                        appItemCell(item)
                                    }
                                }
                                .padding(.horizontal, 14)
                            }
                        }

                        // Documents & Files Section
                        if !documentItems.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    Image(systemName: "doc.fill")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.blue.opacity(0.85))
                                    Text("Documents & Files")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(theme.primaryText)

                                    Text("\(documentItems.count)")
                                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 1)
                                        .background(Capsule().fill(theme.inputBackground))
                                        .foregroundStyle(theme.secondaryText)
                                }
                                .padding(.horizontal, 14)

                                LazyVGrid(columns: docColumns, spacing: 12) {
                                    ForEach(documentItems) { item in
                                        documentItemCell(item)
                                    }
                                }
                                .padding(.horizontal, 14)
                            }
                        }
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 16)
                }
            }
        }
    }

    private func downsampledImage(from url: URL, maxPixelSize: CGFloat = 1200) -> NSImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else {
            return nil
        }
        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions) else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 8) {
            Image(systemName: isTargetedForDrop ? "arrow.down.circle.fill" : "macwindow.on.rectangle")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isTargetedForDrop ? theme.accent : theme.secondaryText)

            Text(isTargetedForDrop ? "Drop apps or documents to add to Holder" : "Holder")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isTargetedForDrop ? theme.accent : theme.primaryText)

            Spacer()

            if !holderManager.items.isEmpty {
                Text("\(holderManager.items.count) item\(holderManager.items.count == 1 ? "" : "s")")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.tertiaryText)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 2)
    }

    // MARK: - App Cell

    private func appItemCell(_ item: HolderItem) -> some View {
        let isHovered = hoveredItemId == item.id
        let running = item.isRunning

        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                holderManager.launchOrOpenItem(item)
            }
        } label: {
            VStack(spacing: 6) {
                ZStack(alignment: .bottomTrailing) {
                    // App Icon
                    itemIcon(for: item)
                        .frame(width: 44, height: 44)

                    // Running indicator dot
                    if running {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                            .overlay(
                                Circle()
                                    .stroke(Color.black.opacity(0.6), lineWidth: 1.5)
                            )
                            .shadow(color: .green.opacity(0.6), radius: 3)
                            .offset(x: 2, y: 2)
                    }
                }

                // App Name
                Text(item.name)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(theme.primaryText)

                // Sub-label
                Text(item.webCompanionURL != nil ? "In-Notch Web" : (running ? "Running" : "App"))
                    .font(.system(size: 8))
                    .foregroundStyle(item.webCompanionURL != nil ? theme.accent : (running ? .green : theme.tertiaryText))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isHovered ? theme.tabHover : theme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isHovered ? theme.accent.opacity(0.6) : theme.cardBorder, lineWidth: 1)
            )
            .scaleEffect(isHovered ? 1.03 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
        .onHover { hovered in
            hoveredItemId = hovered ? item.id : nil
        }
        .onDrag {
            NSItemProvider(contentsOf: item.url) ?? NSItemProvider(object: item.path as NSString)
        }
        .contextMenu {
            if let webURL = item.webCompanionURL {
                Button("Open inside Notch") {
                    holderManager.openEmbeddedApp(item)
                }
                Button("Open in Default Browser") {
                    NSWorkspace.shared.open(webURL)
                }
            }
            Button("Launch Native App") {
                holderManager.launchNativeApp(item)
            }
            Button("Reveal in Finder") {
                holderManager.revealInFinder(item)
            }
            Button("Copy Path") {
                holderManager.copyPath(item)
            }
            Divider()
            Button("Remove from Holder", role: .destructive) {
                holderManager.removeItem(item)
            }
        }
        .help(item.webCompanionURL != nil ? "\(item.name) (Click to run inside Notch)" : (running ? "\(item.name) (Running)" : "\(item.name) (Click to launch)"))
    }

    // MARK: - Document Cell

    private func documentItemCell(_ item: HolderItem) -> some View {
        let isHovered = hoveredItemId == item.id

        return VStack(spacing: 6) {
            // Document icon with preview badge
            ZStack(alignment: .topTrailing) {
                itemIcon(for: item)
                    .frame(width: 40, height: 40)

                if item.isPDF {
                    Text("PDF")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.red.opacity(0.85)))
                        .offset(x: 6, y: -4)
                }
            }

            // Name
            Text(item.name)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.primaryText)

            // Inline action badges
            HStack(spacing: 4) {
                if item.isPDF {
                    Button {
                        holderManager.previewItem(item)
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "eye.fill")
                                .font(.system(size: 7))
                            Text("Preview")
                                .font(.system(size: 8, weight: .medium))
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(theme.inputBackground))
                        .foregroundStyle(theme.secondaryText)
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()
                }

                Button {
                    holderManager.openExternal(item)
                } label: {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 8))
                        .padding(3)
                        .background(Circle().fill(theme.inputBackground))
                        .foregroundStyle(theme.secondaryText)
                }
                .buttonStyle(.plain)
                .pointingHandCursor()
                .help("Open in default application")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovered ? theme.tabHover : theme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isHovered ? Color.blue.opacity(0.6) : theme.cardBorder, lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .pointingHandCursor()
        .onHover { hovered in
            hoveredItemId = hovered ? item.id : nil
        }
        .onTapGesture {
            holderManager.launchOrOpenItem(item)
        }
        .onDrag {
            NSItemProvider(contentsOf: item.url) ?? NSItemProvider(object: item.path as NSString)
        }
        .contextMenu {
            Button("Open") {
                holderManager.openExternal(item)
            }
            if item.isPDF {
                Button("Preview in Notch") {
                    holderManager.previewItem(item)
                }
            }
            Button("Reveal in Finder") {
                holderManager.revealInFinder(item)
            }
            Button("Copy Path") {
                holderManager.copyPath(item)
            }
            Divider()
            Button("Remove from Holder", role: .destructive) {
                holderManager.removeItem(item)
            }
        }
    }

    // MARK: - Embedded Preview View

    private func embeddedPreviewView(for item: HolderItem) -> some View {
        VStack(spacing: 0) {
            // Preview navigation header
            HStack(spacing: 10) {
                Button {
                    holderManager.closePreview()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .bold))
                        Text("Back")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(theme.primaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(theme.inputBackground))
                }
                .buttonStyle(.plain)
                .pointingHandCursor()

                Text(item.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.primaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                Button {
                    holderManager.openExternal(item)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.forward.app")
                            .font(.system(size: 10))
                        Text("Open in App")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(theme.secondaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(theme.inputBackground))
                }
                .buttonStyle(.plain)
                .pointingHandCursor()
                .help("Open with system default application")

                Button {
                    holderManager.closePreview()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(theme.secondaryText)
                        .padding(5)
                        .background(Circle().fill(theme.inputBackground))
                }
                .buttonStyle(.plain)
                .pointingHandCursor()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(theme.cardBackground)

            Divider().overlay(theme.divider)

            // Body: PDF viewer or fallback viewer
            if item.isPDF {
                PDFKitRepresentable(url: item.url)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if item.kind == .image, let nsImage = downsampledImage(from: item.url) ?? NSImage(contentsOf: item.url) {
                ScrollView {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                        .padding(14)
                }
            } else {
                VStack(spacing: 12) {
                    itemIcon(for: item)
                        .frame(width: 64, height: 64)
                    Text(item.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(theme.primaryText)
                    Text(item.path)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(theme.tertiaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    Button("Open in Default App") {
                        holderManager.openExternal(item)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Embedded Web App View

    private func embeddedWebAppView(for item: HolderItem, url: URL) -> some View {
        VStack(spacing: 0) {
            // Header bar
            HStack(spacing: 8) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        holderManager.closeEmbeddedApp()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.backward")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Holder")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(theme.inputBackground))
                    .foregroundStyle(theme.primaryText)
                }
                .buttonStyle(.plain)
                .pointingHandCursor()

                itemIcon(for: item)
                    .frame(width: 18, height: 18)

                Text(item.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.primaryText)

                if let host = url.host {
                    Text(host)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(theme.tertiaryText)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(theme.inputBackground.opacity(0.6)))
                }

                Spacer()

                // Open in External Browser button
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.forward.square")
                            .font(.system(size: 10))
                        Text("Open in Browser")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(theme.inputBackground))
                    .foregroundStyle(theme.secondaryText)
                }
                .buttonStyle(.plain)
                .pointingHandCursor()
                .help("Open in your default web browser")

                // Launch Native App button
                Button {
                    holderManager.launchNativeApp(item)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.forward.app")
                            .font(.system(size: 10))
                        Text("Open Native App")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(theme.inputBackground))
                    .foregroundStyle(theme.secondaryText)
                }
                .buttonStyle(.plain)
                .pointingHandCursor()
                .help("Open in native macOS \(item.name) application")

                // Close button
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        holderManager.closeEmbeddedApp()
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(theme.secondaryText)
                }
                .buttonStyle(.plain)
                .pointingHandCursor()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(theme.cardBackground)

            Divider().overlay(theme.divider)

            // Web View
            HolderWebView(url: url)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func itemIcon(for item: HolderItem) -> some View {
        let nsImage = NSWorkspace.shared.icon(forFile: item.path)
        return Image(nsImage: nsImage)
            .resizable()
            .scaledToFit()
    }

    // MARK: - Drop Here Overlay

    private var dropHereOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(theme.background.opacity(0.92))

            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 2.5, dash: [8, 5])
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [theme.accent, Color.cyan, theme.accent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(theme.accent.opacity(0.18))
                        .frame(width: 58, height: 58)

                    Circle()
                        .stroke(theme.accent.opacity(0.4), lineWidth: 1.5)
                        .frame(width: 58, height: 58)

                    Image(systemName: "arrow.down.app.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(theme.accent)
                }

                VStack(spacing: 4) {
                    Text("Drop App Here to Hold")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(theme.primaryText)

                    Text("Release mouse to pin application to your NotchDeck Holder")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(theme.secondaryText)
                }
            }
            .padding(16)
        }
        .padding(8)
    }

    // MARK: - Empty State

    private var emptyHolderView: some View {
        VStack(spacing: 10) {
            Image(systemName: "macwindow.on.rectangle")
                .font(.system(size: 34))
                .foregroundStyle(theme.tertiaryText)
                .padding(.top, 28)

            Text("Holder is Empty")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.secondaryText)

            Text("Drag and drop your favorite applications (like Slack)\nor documents (like PDFs) here to pin them to your notch.")
                .font(.system(size: 10.5))
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.tertiaryText)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Drop Handling

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        DropURLHelper.extractURLs(from: providers) { urls in
            for url in urls {
                holderManager.addItem(from: url)
            }
        }
        return true
    }
}

// MARK: - PDFKit Representable

struct PDFKitRepresentable: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = NSColor.clear
        if let doc = PDFDocument(url: url) {
            pdfView.document = doc
        }
        return pdfView
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        if nsView.document?.documentURL != url {
            nsView.document = PDFDocument(url: url)
        }
    }
}

// MARK: - HolderWebView Representable

struct HolderWebView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.processPool = WebKitShared.processPool
        config.websiteDataStore = .default()
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.allowsAirPlayForMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let webView = FirstClickWebView(frame: .zero, configuration: config)
        webView.customUserAgent = WebTabItem.userAgent(for: url)
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        if nsView.url == nil {
            nsView.load(URLRequest(url: url))
        }
    }
}
