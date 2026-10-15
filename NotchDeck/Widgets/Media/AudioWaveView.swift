// AudioWaveView.swift
// Compact animated audio wave bars showing playback activity.

import SwiftUI

struct AudioWaveView: View {

    let isPlaying: Bool
    var color: Color = .purple

    @State private var phase: CGFloat = 0.0

    var body: some View {
        HStack(spacing: 2.5) {
            bar(index: 0)
            bar(index: 1)
            bar(index: 2)
            bar(index: 3)
        }
        .frame(height: 12)
        .onAppear {
            if isPlaying { startAnimation() }
        }
        .onChange(of: isPlaying) { _, playing in
            if playing {
                startAnimation()
            }
        }
    }

    private func bar(index: Int) -> some View {
        let baseHeights: [CGFloat] = [0.4, 0.9, 0.6, 0.8]
        let currentHeight: CGFloat = isPlaying
            ? baseHeights[index] * (0.4 + 0.6 * sin(phase + Double(index) * 1.2))
            : 0.2

        return RoundedRectangle(cornerRadius: 1.5)
            .fill(color)
            .frame(width: 2.5, height: max(3, currentHeight * 12))
    }

    private func startAnimation() {
        withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) {
            phase = .pi
        }
    }
}
