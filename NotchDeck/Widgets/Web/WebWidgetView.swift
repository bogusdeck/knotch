// WebWidgetView.swift
// Transparent WKWebView wrapper and template container for user web widgets.

import AppKit
import SwiftUI
import WebKit

struct WebWidgetView: View {
    let widgetId: String
    let title: String
    let relativePath: String?
    let allowShell: Bool
    let widgetConfig: [String: Any]

    @State private var directoryExists: Bool = false
    @State private var bridge: WebWidgetBridge?

    private var resolvedDirectoryURL: URL {
        let base = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/notchdeck", isDirectory: true)

        if let rel = relativePath, !rel.isEmpty {
            if rel.hasPrefix("/") {
                return URL(fileURLWithPath: rel)
            } else {
                return base.appendingPathComponent(rel, isDirectory: true)
            }
        } else {
            return base.appendingPathComponent("widgets/\(widgetId)", isDirectory: true)
        }
    }

    private var indexHTMLURL: URL {
        resolvedDirectoryURL.appendingPathComponent("index.html")
    }

    var body: some View {
        Group {
            if FileManager.default.fileExists(atPath: indexHTMLURL.path) {
                if let bridge = bridge {
                    WebWidgetRepresentable(
                        widgetDirURL: resolvedDirectoryURL,
                        indexURL: indexHTMLURL,
                        bridge: bridge
                    )
                } else {
                    ProgressView()
                }
            } else {
                missingTemplateView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            setupBridge()
        }
    }

    private func setupBridge() {
        let br = WebWidgetBridge(
            widgetId: widgetId,
            widgetTitle: title,
            allowShell: allowShell,
            widgetDirURL: resolvedDirectoryURL,
            widgetConfig: widgetConfig
        )
        self.bridge = br
        self.directoryExists = FileManager.default.fileExists(atPath: indexHTMLURL.path)
    }

    private var missingTemplateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "safari")
                .font(.system(size: 30))
                .foregroundColor(.secondary)

            Text("Web Widget Not Found")
                .font(.headline)

            Text("Expected index.html at:\n\(indexHTMLURL.path)")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            Button("Create Starter Template") {
                createStarterTemplate()
                setupBridge()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding()
    }

    private func createStarterTemplate() {
        let dir = resolvedDirectoryURL
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let html = """
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8">
          <style>
            body {
              margin: 0;
              padding: 16px;
              font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
              color: #ffffff;
              background: transparent;
              user-select: none;
            }
            .card {
              background: rgba(255, 255, 255, 0.08);
              border-radius: 12px;
              padding: 16px;
              backdrop-filter: blur(20px);
            }
            h2 { margin: 0 0 8px 0; font-size: 16px; }
            p { margin: 0 0 12px 0; font-size: 12px; opacity: 0.8; }
            button {
              background: #7C5CFF;
              border: none;
              color: white;
              padding: 6px 12px;
              border-radius: 6px;
              cursor: pointer;
              font-weight: 500;
            }
          </style>
        </head>
        <body>
          <div class="card">
            <h2>\(title.isEmpty ? widgetId : title)</h2>
            <p>Welcome to your transparent NotchDeck web widget!</p>
            <button id="notifyBtn">Test Notification</button>
          </div>
          <script>
            document.getElementById('notifyBtn').onclick = () => {
              if (window.notch) {
                window.notch.notify('Greetings from \(title)!');
              }
            };
          </script>
        </body>
        </html>
        """
        try? html.write(to: indexHTMLURL, atomically: true, encoding: .utf8)
    }
}

struct WebWidgetRepresentable: NSViewRepresentable {
    let widgetDirURL: URL
    let indexURL: URL
    let bridge: WebWidgetBridge

    func makeNSView(context: Context) -> WKWebView {
        let userContentController = WKUserContentController()

        // Inject window.notch script
        let script = WKUserScript(
            source: bridge.injectionScript(),
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        userContentController.addUserScript(script)
        userContentController.addScriptMessageHandler(bridge, contentWorld: .page, name: "notchBridge")

        let config = WKWebViewConfiguration()
        config.processPool = WebKitShared.processPool
        config.userContentController = userContentController
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        let webView = FirstClickWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.underPageBackgroundColor = .clear

        webView.loadFileURL(indexURL, allowingReadAccessTo: widgetDirURL)
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // Self-managing
    }
}
