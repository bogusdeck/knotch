// PeekView.swift
// Compact view shown when the user hovers over the notch.
// Displays a minimal live summary: time + what's playing.

import SwiftUI

struct PeekView: View {

    @ObservedObject var viewModel: NotchViewModel

    var body: some View {
        HStack(spacing: 14) {
            // Clock — always shown
            clockSection

            Divider()
                .frame(height: 20)
                .overlay(.white.opacity(0.2))

            // "Now playing" placeholder (replaced in Phase 4)
            nowPlayingSection
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .foregroundStyle(.white)
    }

    // MARK: - Sub-views

    private var clockSection: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(Date(), format: .dateTime.hour().minute())
                .font(.system(size: 13, weight: .semibold, design: .rounded))
            Text(Date(), format: .dateTime.weekday(.wide))
                .font(.system(size: 10, weight: .regular))
                .opacity(0.6)
        }
    }

    private var nowPlayingSection: some View {
        HStack(spacing: 6) {
            Image(systemName: "music.note")
                .imageScale(.small)
                .opacity(0.7)
            Text("Nothing playing")
                .font(.system(size: 11, weight: .regular))
                .opacity(0.6)
                .lineLimit(1)
        }
    }
}
