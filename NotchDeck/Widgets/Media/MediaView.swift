// MediaView.swift
// Full media card view with both Classic Card and Vinyl Turntable playback UI.
// Supports scrolling or swiping left/right to toggle between Classic and Vinyl views.
// Optimized for balanced square-card dashboard layout.

import SwiftUI
import AppKit

enum MediaStyle: String, CaseIterable {
    case standard = "standard"
    case vinyl = "vinyl"
}

struct MediaView: View {

    @ObservedObject var mediaManager: MediaManager
    @Environment(\.deckTheme) private var theme: DeckTheme
    @AppStorage("notchdeck_media_style") private var mediaStyle: String = MediaStyle.standard.rawValue

    @State private var isHovered: Bool = false
    @State private var scrollMonitor: Any? = nil
    @State private var lastScrollTrigger: Date = .distantPast

    private var isVinyl: Bool {
        mediaStyle == MediaStyle.vinyl.rawValue
    }

    var body: some View {
        Group {
            if let media = mediaManager.currentMedia {
                if isVinyl {
                    activeVinylCard(media)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                } else {
                    activeStandardCard(media)
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                }
            } else {
                if isVinyl {
                    idleVinylCard
                } else {
                    idleStandardCard
                }
            }
        }
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                startScrollMonitoring()
            } else {
                stopScrollMonitoring()
            }
        }
        .onDisappear {
            stopScrollMonitoring()
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    if value.translation.width < -25 {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            mediaStyle = MediaStyle.vinyl.rawValue
                        }
                    } else if value.translation.width > 25 {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            mediaStyle = MediaStyle.standard.rawValue
                        }
                    }
                }
        )
    }

    // MARK: - Scroll Wheel Event Monitor

    private func startScrollMonitoring() {
        guard scrollMonitor == nil else { return }
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            let dx = event.scrollingDeltaX
            if abs(dx) > 5 && Date().timeIntervalSince(lastScrollTrigger) > 0.35 {
                lastScrollTrigger = Date()
                Task { @MainActor in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        if dx < 0 {
                            mediaStyle = MediaStyle.vinyl.rawValue
                        } else {
                            mediaStyle = MediaStyle.standard.rawValue
                        }
                    }
                }
            }
            return event
        }
    }

    private func stopScrollMonitoring() {
        if let monitor = scrollMonitor {
            NSEvent.removeMonitor(monitor)
            scrollMonitor = nil
        }
    }

    // MARK: - Style Toggle Header Button

    private func styleSwitcher() -> some View {
        HStack(spacing: 5) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    mediaStyle = MediaStyle.standard.rawValue
                }
            } label: {
                Circle()
                    .fill(!isVinyl ? theme.accent : theme.tertiaryText.opacity(0.35))
                    .frame(width: !isVinyl ? 6.5 : 4.5, height: !isVinyl ? 6.5 : 4.5)
            }
            .buttonStyle(.plain)
            .help("Switch to Classic Card View")

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    mediaStyle = MediaStyle.vinyl.rawValue
                }
            } label: {
                Circle()
                    .fill(isVinyl ? theme.accent : theme.tertiaryText.opacity(0.35))
                    .frame(width: isVinyl ? 6.5 : 4.5, height: isVinyl ? 6.5 : 4.5)
            }
            .buttonStyle(.plain)
            .help("Switch to Vinyl Turntable View")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(theme.inputBackground.opacity(0.6))
        )
    }

    // MARK: - Active Standard Card

    private func activeStandardCard(_ media: MediaItem) -> some View {
        VStack(spacing: 8) {
            // Header with brand and style dots
            HStack {
                serviceBrandBadge(media)
                Spacer()
                styleSwitcher()
            }

            // Track Artwork & Info
            HStack(spacing: 9) {
                artworkView(media)
                    .frame(width: 44, height: 44)
                    .cornerRadius(7)
                    .shadow(color: .black.opacity(0.3), radius: 3, y: 1.5)

                VStack(alignment: .leading, spacing: 2) {
                    Text(media.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.primaryText)
                        .lineLimit(1)

                    Text(media.artist)
                        .font(.system(size: 10))
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(1)

                    AudioWaveView(isPlaying: media.isPlaying, color: media.brandColor)
                }

                Spacer(minLength: 0)
            }

            Spacer(minLength: 0)

            // Playback controls centered
            HStack(spacing: 16) {
                Button {
                    mediaManager.previousTrack()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.secondaryText)
                }
                .buttonStyle(.plain)

                Button {
                    mediaManager.togglePlayPause()
                } label: {
                    ZStack {
                        Circle()
                            .fill(media.brandColor.opacity(0.18))
                            .frame(width: 28, height: 28)
                        Circle()
                            .stroke(media.brandColor.opacity(0.4), lineWidth: 1)
                            .frame(width: 28, height: 28)
                        Image(systemName: media.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(media.brandColor)
                    }
                }
                .buttonStyle(.plain)

                Button {
                    mediaManager.nextTrack()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.secondaryText)
                }
                .buttonStyle(.plain)
            }

            // Progress bar and timestamps
            progressBar(media)
        }
        .padding(11)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(theme.cardBorder, lineWidth: 1)
        )
    }

    // MARK: - Active Vinyl Card

    private func activeVinylCard(_ media: MediaItem) -> some View {
        PureVinylCard(
            media: media,
            mediaManager: mediaManager,
            artworkView: AnyView(artworkView(media)),
            styleSwitcher: AnyView(styleSwitcher()),
            theme: theme
        )
    }

    // MARK: - Service Brand Badge

    private func serviceBrandBadge(_ media: MediaItem) -> some View {
        HStack(spacing: 4) {
            if media.isSpotify {
                Circle()
                    .fill(Color(red: 0.11, green: 0.73, blue: 0.33))
                    .frame(width: 6, height: 6)
                Text("SPOTIFY")
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.11, green: 0.73, blue: 0.33))
            } else if media.isAppleMusic {
                Image(systemName: "apple.logo")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color(red: 0.99, green: 0.24, blue: 0.27))
                Text("MUSIC")
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.99, green: 0.24, blue: 0.27))
            } else {
                Circle()
                    .fill(theme.accent)
                    .frame(width: 5.5, height: 5.5)
                Text("MUSIC")
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.secondaryText)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(theme.inputBackground.opacity(0.7))
        )
    }

    // MARK: - Progress Bar

    private func progressBar(_ media: MediaItem) -> some View {
        VStack(spacing: 3) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(theme.barTrack)
                        .frame(height: 3)

                    Capsule()
                        .fill(media.brandColor)
                        .frame(width: max(0, geo.size.width * CGFloat(media.progress)), height: 3)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            let fraction = max(0, min(1, value.location.x / geo.size.width))
                            let targetSeconds = media.duration * Double(fraction)
                            mediaManager.seek(to: targetSeconds)
                        }
                )
            }
            .frame(height: 3)

            HStack {
                Text(media.formattedElapsed)
                    .font(.system(size: 8.5, design: .monospaced))
                    .foregroundStyle(theme.tertiaryText)

                Spacer()

                Text(media.formattedDuration)
                    .font(.system(size: 8.5, design: .monospaced))
                    .foregroundStyle(theme.tertiaryText)
            }
        }
    }

    // MARK: - Artwork View

    private func artworkView(_ media: MediaItem) -> some View {
        Group {
            if let artwork = media.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .scaledToFill()
            } else if let urlStr = media.artworkUrl, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .empty:
                        ZStack {
                            theme.inputBackground
                            ProgressView()
                                .scaleEffect(0.5)
                        }
                    default:
                        fallbackArtwork(media)
                    }
                }
            } else {
                fallbackArtwork(media)
            }
        }
    }

    private func fallbackArtwork(_ media: MediaItem) -> some View {
        ZStack {
            theme.inputBackground
            if let bundleId = media.bundleIdentifier,
               let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path))
                    .resizable()
                    .scaledToFit()
                    .padding(5)
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 18))
                    .foregroundStyle(media.brandColor.opacity(0.8))
            }
        }
    }

    // MARK: - Idle Cards

    private var idleStandardCard: some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "music.note")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.accent)
                    Text("MUSIC")
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.secondaryText)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(theme.inputBackground.opacity(0.7)))

                Spacer()
                styleSwitcher()
            }

            Spacer(minLength: 0)

            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(theme.inputBackground)
                    .frame(width: 42, height: 42)
                Image(systemName: "music.note")
                    .font(.system(size: 18))
                    .foregroundStyle(theme.tertiaryText)
            }

            VStack(spacing: 2) {
                Text("Nothing Playing")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.secondaryText)
                Text("Spotify / Apple Music")
                    .font(.system(size: 9))
                    .foregroundStyle(theme.tertiaryText)
            }

            Spacer(minLength: 0)
        }
        .padding(11)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(theme.cardBorder, lineWidth: 1)
        )
    }

    private var idleVinylCard: some View {
        IdlePureVinylCard(
            mediaManager: mediaManager,
            styleSwitcher: AnyView(styleSwitcher()),
            theme: theme
        )
    }
}

// MARK: - Pure Vinyl Card Components

struct PureVinylCard: View {
    let media: MediaItem
    @ObservedObject var mediaManager: MediaManager
    let artworkView: AnyView
    let styleSwitcher: AnyView
    let theme: DeckTheme

    @State private var isHovered: Bool = false

    var body: some View {
        GeometryReader { geo in
            let cardSize = min(geo.size.width, geo.size.height)
            let discSize = max(90, cardSize - 16)

            ZStack {
                // Background
                theme.cardBackground

                // Ambient Radial Glow from brand color
                RadialGradient(
                    colors: [
                        media.brandColor.opacity(0.20),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 8,
                    endRadius: discSize * 0.65
                )

                // Large Interactive Vinyl Disc
                PureVinylDiscView(
                    media: media,
                    artworkView: artworkView,
                    size: discSize,
                    isHovered: isHovered,
                    onTogglePlay: {
                        mediaManager.togglePlayPause()
                    }
                )

                // Hover Controls: Skip Previous / Skip Next
                if isHovered {
                    HStack {
                        Button {
                            mediaManager.previousTrack()
                        } label: {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(Color.black.opacity(0.6)))
                                .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                                .shadow(color: .black.opacity(0.5), radius: 4)
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 8)
                        .transition(.scale.combined(with: .opacity))

                        Spacer()

                        Button {
                            mediaManager.nextTrack()
                        } label: {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(Color.black.opacity(0.6)))
                                .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                                .shadow(color: .black.opacity(0.5), radius: 4)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 8)
                        .transition(.scale.combined(with: .opacity))
                    }
                }

                // Top Bar: Service Brand Badge & Style Switcher
                VStack {
                    HStack {
                        if media.isSpotify {
                            Circle()
                                .fill(Color(red: 0.11, green: 0.73, blue: 0.33))
                                .frame(width: 6, height: 6)
                                .opacity(isHovered ? 0.9 : 0.45)
                        } else if media.isAppleMusic {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(Color(red: 0.99, green: 0.24, blue: 0.27))
                                .opacity(isHovered ? 0.9 : 0.45)
                        } else {
                            Circle()
                                .fill(theme.accent)
                                .frame(width: 5, height: 5)
                                .opacity(isHovered ? 0.8 : 0.35)
                        }

                        Spacer()

                        styleSwitcher
                            .opacity(isHovered ? 1.0 : 0.4)
                    }
                    .padding(8)

                    Spacer()

                    // Song title & artist floating pill on hover
                    if isHovered {
                        VStack(spacing: 1.5) {
                            Text(media.title)
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)

                            if !media.artist.isEmpty {
                                Text(media.artist)
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.8))
                                    .lineLimit(1)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.78))
                                .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 0.8))
                        )
                        .shadow(color: .black.opacity(0.55), radius: 6, y: 2)
                        .padding(.bottom, 6)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isHovered ? media.brandColor.opacity(0.4) : theme.cardBorder,
                        lineWidth: 1
                    )
            )
            .onHover { h in
                withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                    isHovered = h
                }
            }
        }
    }
}

struct PureVinylDiscView: View {
    let media: MediaItem
    let artworkView: AnyView
    let size: CGFloat
    let isHovered: Bool
    let onTogglePlay: () -> Void

    var body: some View {
        TimelineView(.animation(paused: !media.isPlaying)) { context in
            let rotation = media.isPlaying
                ? (context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 8.0) / 8.0) * 360.0
                : 0.0

            Button(action: onTogglePlay) {
                ZStack {
                    // Outer shadow for realistic vinyl depth
                    Circle()
                        .fill(Color.black.opacity(0.45))
                        .frame(width: size + 4, height: size + 4)
                        .blur(radius: 4)

                    // Rotating Vinyl Body
                    ZStack {
                        // Deep black vinyl record base with radial gradient
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color(red: 0.16, green: 0.16, blue: 0.18),
                                        Color(red: 0.09, green: 0.09, blue: 0.10),
                                        Color(red: 0.04, green: 0.04, blue: 0.05),
                                        Color(red: 0.02, green: 0.02, blue: 0.02)
                                    ],
                                    center: .center,
                                    startRadius: size * 0.18,
                                    endRadius: size * 0.50
                                )
                            )
                            .frame(width: size, height: size)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.14), lineWidth: 1.2)
                            )

                        // Precision Micro Grooves
                        Group {
                            Circle()
                                .stroke(Color.white.opacity(0.06), lineWidth: 0.8)
                                .frame(width: size * 0.92, height: size * 0.92)

                            Circle()
                                .stroke(Color.white.opacity(0.05), lineWidth: 0.8)
                                .frame(width: size * 0.84, height: size * 0.84)

                            Circle()
                                .stroke(Color.white.opacity(0.07), lineWidth: 0.8)
                                .frame(width: size * 0.76, height: size * 0.76)

                            Circle()
                                .stroke(Color.white.opacity(0.05), lineWidth: 0.8)
                                .frame(width: size * 0.68, height: size * 0.68)

                            Circle()
                                .stroke(Color.white.opacity(0.06), lineWidth: 0.8)
                                .frame(width: size * 0.60, height: size * 0.60)

                            Circle()
                                .stroke(Color.white.opacity(0.04), lineWidth: 0.8)
                                .frame(width: size * 0.52, height: size * 0.52)
                        }

                        // Rotating Specular Sheen (Dual cone reflection)
                        AngularGradient(
                            gradient: Gradient(colors: [
                                .clear,
                                Color.white.opacity(0.14),
                                .clear,
                                Color.white.opacity(0.07),
                                .clear,
                                Color.white.opacity(0.14),
                                .clear
                            ]),
                            center: .center,
                            angle: .degrees(rotation)
                        )
                        .clipShape(Circle())
                        .frame(width: size, height: size)

                        // Center Circular Label (Album Cover Artwork or Song Name)
                        ZStack {
                            if media.hasArtwork {
                                artworkView
                                    .frame(width: size * 0.44, height: size * 0.44)
                                    .clipShape(Circle())
                            } else {
                                // Record label with Song Name in center
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: [
                                                media.brandColor.opacity(0.4),
                                                Color(red: 0.12, green: 0.12, blue: 0.14)
                                            ],
                                            center: .center,
                                            startRadius: 4,
                                            endRadius: size * 0.22
                                        )
                                    )
                                    .frame(width: size * 0.44, height: size * 0.44)

                                VStack(spacing: 2) {
                                    Image(systemName: "music.note")
                                        .font(.system(size: max(8, size * 0.08)))
                                        .foregroundStyle(media.brandColor)

                                    Text(media.title)
                                        .font(.system(size: max(7, size * 0.065), weight: .bold))
                                        .foregroundStyle(.white)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 4)

                                    if !media.artist.isEmpty {
                                        Text(media.artist)
                                            .font(.system(size: max(6, size * 0.055), weight: .medium))
                                            .foregroundStyle(Color.white.opacity(0.8))
                                            .lineLimit(1)
                                    }
                                }
                                .frame(width: size * 0.40)
                            }

                            // Foil ring around center label
                            Circle()
                                .stroke(media.brandColor.opacity(0.85), lineWidth: 1.5)
                                .frame(width: size * 0.44, height: size * 0.44)

                            // Spindle Hole
                            Circle()
                                .fill(Color.black)
                                .frame(width: 8, height: 8)
                                .overlay(
                                    Circle()
                                        .stroke(Color(white: 0.7), lineWidth: 1)
                                )
                        }
                    }
                    .rotationEffect(.degrees(rotation))

                    // Center Play/Pause button on hover or when paused
                    if isHovered || !media.isPlaying {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.65))
                                .frame(width: max(32, size * 0.24), height: max(32, size * 0.24))
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                                )

                            Image(systemName: media.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: max(12, size * 0.10), weight: .bold))
                                .foregroundStyle(.white)
                                .offset(x: media.isPlaying ? 0 : 1)
                        }
                        .shadow(color: .black.opacity(0.6), radius: 6)
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }
}

struct IdlePureVinylCard: View {
    @ObservedObject var mediaManager: MediaManager
    let styleSwitcher: AnyView
    let theme: DeckTheme

    @State private var isHovered: Bool = false

    var body: some View {
        GeometryReader { geo in
            let cardSize = min(geo.size.width, geo.size.height)
            let discSize = max(90, cardSize - 16)

            ZStack {
                theme.cardBackground

                Button {
                    mediaManager.togglePlayPause()
                } label: {
                    ZStack {
                        // Vinyl Disc
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color(red: 0.15, green: 0.15, blue: 0.16),
                                        Color(red: 0.08, green: 0.08, blue: 0.09),
                                        Color(red: 0.03, green: 0.03, blue: 0.04)
                                    ],
                                    center: .center,
                                    startRadius: discSize * 0.18,
                                    endRadius: discSize * 0.50
                                )
                            )
                            .frame(width: discSize, height: discSize)
                            .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))

                        // Grooves
                        Circle()
                            .stroke(Color.white.opacity(0.05), lineWidth: 0.8)
                            .frame(width: discSize * 0.88, height: discSize * 0.88)
                        Circle()
                            .stroke(Color.white.opacity(0.05), lineWidth: 0.8)
                            .frame(width: discSize * 0.72, height: discSize * 0.72)
                        Circle()
                            .stroke(Color.white.opacity(0.05), lineWidth: 0.8)
                            .frame(width: discSize * 0.56, height: discSize * 0.56)

                        // Center Label
                        ZStack {
                            Circle()
                                .fill(Color(white: 0.12))
                                .frame(width: discSize * 0.44, height: discSize * 0.44)
                                .overlay(Circle().stroke(theme.accent.opacity(0.5), lineWidth: 1))

                            VStack(spacing: 3) {
                                Image(systemName: "opticaldisc")
                                    .font(.system(size: 16))
                                    .foregroundStyle(theme.accent)

                                Text("Vinyl Ready")
                                    .font(.system(size: 8.5, weight: .semibold))
                                    .foregroundStyle(theme.primaryText)

                                Text("Click to play")
                                    .font(.system(size: 7.5))
                                    .foregroundStyle(theme.tertiaryText)
                            }

                            // Spindle hole
                            Circle()
                                .fill(Color.black)
                                .frame(width: 7, height: 7)
                                .overlay(Circle().stroke(Color.white.opacity(0.4), lineWidth: 0.8))
                        }

                        // Play icon on hover
                        if isHovered {
                            Circle()
                                .fill(Color.black.opacity(0.6))
                                .frame(width: 32, height: 32)
                                .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                                .overlay(
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(.white)
                                        .offset(x: 1)
                                )
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
                .buttonStyle(.plain)

                // Top Bar: Switcher
                VStack {
                    HStack {
                        Spacer()
                        styleSwitcher
                            .opacity(isHovered ? 1.0 : 0.4)
                    }
                    .padding(8)

                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(theme.cardBorder, lineWidth: 1)
            )
            .onHover { h in
                withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                    isHovered = h
                }
            }
        }
    }
}
