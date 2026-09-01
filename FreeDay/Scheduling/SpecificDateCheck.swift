import Foundation

/// Exact-date availability inside Quick Check. Uses `validateBooking` and `AvailabilitySearch`.
struct SpecificDateCheck: Equatable, Sendable {
    var requestedDate: Date
    var duration: Int
    var horizonDays: Int = AvailabilitySearchOptions.defaults.calendarDayHorizon

    init(
        requestedDate: Date,
        duration: Int,
        horizonDays: Int = AvailabilitySearchOptions.defaults.calendarDayHorizon
    ) {
        self.requestedDate = requestedDate
        self.duration = min(max(duration, QuickCheck.minDuration), QuickCheck.maxDuration)
        self.horizonDays = horizonDays
    }

    func snappedStart(using calendar: WorkingCalendar) -> Date {
        calendar.nextWorkingDay(onOrAfter: requestedDate)
    }

    func evaluate(
        engine: SchedulingEngine,
        search: AvailabilitySearch,
        projects: [ProjectSnapshot]
    ) -> SpecificDateResult {
        let start = snappedStart(using: engine.workingCalendar)
        let dates = engine.workingDates(start: start, duration: duration)
        guard dates.count == duration, let first = dates.first, let last = dates.last else {
            return .unavailable(start: start, conflictName: nil, next: nil)
        }
        let requested = FreeSlot(start: first, end: last, workingDates: dates)

        switch engine.validateBooking(start: start, duration: duration, projects: projects, buffer: 0) {
        case .valid:
            return .available(start: start, slot: requested)
        case .conflict:
            let name = conflictName(requestedDates: dates, engine: engine, projects: projects)
            let next = search.findSlots(
                duration: duration,
                from: start,
                projects: projects,
                horizonDays: horizonDays
            ).next
            return .unavailable(start: start, conflictName: name, next: next)
        }
    }

    private func conflictName(
        requestedDates: [Date],
        engine: SchedulingEngine,
        projects: [ProjectSnapshot]
    ) -> String? {
        let requested = engine.workingCalendar.normalizedSet(requestedDates)
        return projects
            .filter { project in
                let reserved = engine.workingCalendar.normalizedSet(engine.reservedDates(for: project))
                return !requested.isDisjoint(with: reserved)
            }
            .sorted { ($0.startDate ?? .distantFuture) < ($1.startDate ?? .distantFuture) }
            .first?
            .customerName
    }
}

enum SpecificDateResult: Equatable, Sendable {
    case available(start: Date, slot: FreeSlot)
    case unavailable(start: Date, conflictName: String?, next: FreeSlot?)

    var start: Date {
        switch self {
        case .available(let start, _), .unavailable(let start, _, _): start
        }
    }

    var isAvailable: Bool {
        if case .available = self { return true }
        return false
    }

    var slotToUse: FreeSlot? {
        switch self {
        case .available(_, let slot): slot
        case .unavailable(_, _, let next): next
        }
    }
}
