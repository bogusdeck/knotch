// CalendarWidget.swift
// Built-in calendar widget displaying upcoming events with clear permission prompts.

import SwiftUI

struct CalendarWidgetTile: View {
    @ObservedObject var calendarManager: CalendarManager
    @Environment(\.deckTheme) private var theme: DeckTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "calendar")
                    .font(.system(size: 13))
                    .foregroundStyle(.red.opacity(0.8))

                Text("Upcoming Events")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.primaryText)

                Spacer()
            }

            if calendarManager.hasPermission {
                if calendarManager.events.isEmpty {
                    Text("No upcoming events")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.tertiaryText)
                        .padding(.vertical, 4)
                } else {
                    VStack(spacing: 6) {
                        ForEach(calendarManager.events) { event in
                            HStack {
                                Circle()
                                    .fill(Color.red.opacity(0.8))
                                    .frame(width: 5, height: 5)

                                Text(event.title)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(theme.primaryText)
                                    .lineLimit(1)

                                Spacer()

                                Text(event.timeString)
                                    .font(.system(size: 9))
                                    .foregroundStyle(theme.secondaryText)
                            }
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Calendar access is required to display your upcoming schedule.")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.secondaryText)

                    Button("Grant Calendar Permission") {
                        calendarManager.requestPermission()
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .buttonStyle(.borderedProminent)
                    .tint(.red.opacity(0.7))
                }
                .padding(.vertical, 4)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(theme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(theme.cardBorder, lineWidth: 1)
        )
    }
}
