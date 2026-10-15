// ErrorBannerView.swift
// A small pill-shaped banner that slides down inside the notch to report
// config.toml parse errors with their line number.
// Disappears automatically after 6 seconds or when the error is resolved.

import SwiftUI

struct ErrorBannerView: View {

    let error: ConfigError
    let onDismiss: () -> Void

    @State private var isVisible = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
                .imageScale(.small)

            Text(errorText)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .imageScale(.small)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.red.opacity(0.85))
                .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
        )
        .padding(.horizontal, 12)
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : -20)
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                isVisible = true
            }
            // Auto-dismiss after 6 seconds
            Task {
                try? await Task.sleep(for: .seconds(6))
                dismiss()
            }
        }
    }

    // MARK: - Helpers

    private var errorText: String {
        switch error {
        case .parseError(let line, let msg):
            if let line {
                return "config.toml line \(line): \(msg)"
            }
            return "config.toml error: \(msg)"
        case .ioError(let msg):
            return "Config I/O: \(msg)"
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.2)) {
            isVisible = false
        }
        Task {
            try? await Task.sleep(for: .milliseconds(220))
            onDismiss()
        }
    }
}
