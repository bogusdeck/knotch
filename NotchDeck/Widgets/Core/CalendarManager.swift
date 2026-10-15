// CalendarManager.swift
// Manages EventKit integration for upcoming events with on-demand permission requesting.

import EventKit
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.notchdeck.app", category: "CalendarManager")

struct CalendarEventItem: Identifiable, Sendable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool

    var timeString: String {
        if isAllDay { return "All Day" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: startDate)
    }
}

@MainActor
final class CalendarManager: ObservableObject {

    @Published private(set) var events: [CalendarEventItem] = []
    @Published private(set) var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published private(set) var hasPermission: Bool = false

    private let store = EKEventStore()

    init() {
        checkStatus()
    }

    func checkStatus() {
        if #available(macOS 14.0, *) {
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
            hasPermission = (authorizationStatus == .fullAccess)
        } else {
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
            hasPermission = (authorizationStatus == .authorized)
        }
        if hasPermission {
            fetchUpcomingEvents()
        }
    }

    func requestPermission() {
        if #available(macOS 14.0, *) {
            store.requestFullAccessToEvents { [weak self] granted, _ in
                Task { @MainActor in
                    self?.hasPermission = granted
                    if granted {
                        self?.fetchUpcomingEvents()
                    }
                }
            }
        } else {
            store.requestAccess(to: .event) { [weak self] granted, _ in
                Task { @MainActor in
                    self?.hasPermission = granted
                    if granted {
                        self?.fetchUpcomingEvents()
                    }
                }
            }
        }
    }

    func fetchUpcomingEvents() {
        guard hasPermission else { return }

        let start = Date()
        let end = Calendar.current.date(byAdding: .day, value: 2, to: start) ?? start.addingTimeInterval(86400 * 2)
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let foundEvents = store.events(matching: predicate)

        self.events = foundEvents.prefix(5).map { event in
            CalendarEventItem(
                id: event.eventIdentifier ?? UUID().uuidString,
                title: event.title ?? "Untitled Event",
                startDate: event.startDate,
                endDate: event.endDate,
                isAllDay: event.isAllDay
            )
        }
    }
}
