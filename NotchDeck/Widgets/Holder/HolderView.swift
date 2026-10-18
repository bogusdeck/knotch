// HolderView.swift
// Desktop Environment canvas for the Holder tab.
// Displays pinned applications, PDFs, and files with one-click launch, embedded PDF reading, and drag-and-drop.

import AppKit
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

struct HolderView: View {

    @ObservedObject var holderManager: HolderManager
    @State private var isTargetedForDrop: Bool = false
    @State private var hoveredItemId: UUID? = nil

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
        Group {
            if let previewItem = holderManager.selectedItemForPreview {
                embeddedPreviewView(for: previewItem)
            } else {
                mainCanvasView
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
                                        .foregroundStyle(.purple.opacity(0.85))
                                    Text("Applications")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.8))

                                    Text("\(appItems.count)")
                                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 1)
                                        .background(Capsule().fill(Color.white.opacity(0.08)))
                                        .foregroundStyle(.white.opacity(0.5))
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
                                        .foregroundStyle(.white.opacity(0.8))

                                    Text("\(documentItems.count)")
                                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 1)
                                        .background(Capsule().fill(Color.white.opacity(0.08)))
                                        .foregroundStyle(.white.opacity(0.5))
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

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 8) {
            Image(systemName: isTargetedForDrop ? "arrow.down.circle.fill" : "macwindow.on.rectangle")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isTargetedForDrop ? .purple : .white.opacity(0.7))

            Text(isTargetedForDrop ? "Drop apps or documents to add to Holder" : "Holder")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isTargetedForDrop ? .purple : .white.opacity(0.85))

            Spacer()

            if !holderManager.items.isEmpty {
                Text("\(holderManager.items.count) item\(holderManager.items.count == 1 ? "" : "s")")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.45))
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
                    .foregroundStyle(.white)

                // Sub-label
                Text(running ? "Running" : "App")
                    .font(.system(size: 8))
                    .foregroundStyle(running ? .green.opacity(0.8) : .white.opacity(0.35))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isHovered ? Color.white.opacity(0.12) : Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isHovered ? Color.purple.opacity(0.6) : Color.white.opacity(0.06), lineWidth: 1)
            )
            .scaleEffect(isHovered ? 1.03 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovered in
            hoveredItemId = hovered ? item.id : nil
        }
        .onDrag {
            NSItemProvider(contentsOf: item.url) ?? NSItemProvider(object: item.path as NSString)
        }
        .contextMenu {
            Button("Launch \(item.name)") {
                holderManager.launchOrOpenItem(item)
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
        .help(running ? "\(item.name) (Running - Click to activate)" : "\(item.name) (Click to launch)")
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
                .foregroundStyle(.white)

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
                        .background(Capsule().fill(Color.white.opacity(0.12)))
                        .foregroundStyle(.white.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    holderManager.openExternal(item)
                } label: {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 8))
                        .padding(3)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("Open in default application")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovered ? Color.white.opacity(0.12) : Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isHovered ? Color.blue.opacity(0.6) : Color.white.opacity(0.06), lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
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
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.1)))
                }
                .buttonStyle(.plain)

                Text(item.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
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
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .help("Open with system default application")

                Button {
                    holderManager.closePreview()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(5)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.3))

            Divider().overlay(Color.white.opacity(0.1))

            // Body: PDF viewer or fallback viewer
            if item.isPDF {
                PDFKitRepresentable(url: item.url)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if item.kind == .image, let nsImage = NSImage(contentsOf: item.url) {
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
                        .foregroundStyle(.white)
                    Text(item.path)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
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

    // MARK: - Helpers

    private func itemIcon(for item: HolderItem) -> some View {
        let nsImage = NSWorkspace.shared.icon(forFile: item.path)
        return Image(nsImage: nsImage)
            .resizable()
            .scaledToFit()
    }

    // MARK: - Empty State

    private var emptyHolderView: some View {
        VStack(spacing: 10) {
            Image(systemName: "macwindow.on.rectangle")
                .font(.system(size: 34))
                .foregroundStyle(.white.opacity(0.2))
                .padding(.top, 28)

            Text("Holder is Empty")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))

            Text("Drag and drop your favorite applications (like Slack)\nor documents (like PDFs) here to pin them to your notch.")
                .font(.system(size: 10.5))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.35))
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
