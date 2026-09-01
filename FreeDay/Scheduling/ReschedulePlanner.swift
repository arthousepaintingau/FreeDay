import Foundation

enum RescheduleDecision: Equatable, Sendable {
    case allowed(dates: [Date])
    case blocked
}

/// Finds new dates for a booked project without rewriting occupancy rules.
/// The moving project is excluded from blocking so its current days can be reused by the search.
struct ReschedulePlanner: Sendable {
    var engine: SchedulingEngine
    var search: AvailabilitySearch

    init(
        engine: SchedulingEngine,
        options: AvailabilitySearchOptions = .defaults
    ) {
        self.engine = engine
        self.search = AvailabilitySearch(engine: engine, options: options)
    }

    func currentSlot(for project: ProjectSnapshot) -> FreeSlot? {
        guard project.canReschedule, let start = project.startDate else { return nil }
        let dates = engine.workingDates(start: start, duration: project.durationInWorkingDays)
        guard let first = dates.first, let last = dates.last else { return nil }
        return FreeSlot(start: first, end: last, workingDates: dates)
    }

    func searchOrigin(
        for project: ProjectSnapshot,
        searchEarlier: Bool,
        override: Date? = nil,
        now: Date = .now
    ) -> Date {
        if let override {
            return engine.workingCalendar.startOfDay(override)
        }
        let original = engine.workingCalendar.startOfDay(project.startDate ?? now)
        let today = engine.workingCalendar.startOfDay(now)
        if searchEarlier, today < original {
            return today
        }
        return original
    }

    func alternatives(
        for project: ProjectSnapshot,
        among projects: [ProjectSnapshot],
        searchEarlier: Bool = false,
        from override: Date? = nil,
        now: Date = .now
    ) -> AvailabilitySearchResult {
        guard project.canReschedule else {
            return AvailabilitySearchResult(slots: [], horizonDays: search.options.calendarDayHorizon)
        }
        let origin = searchOrigin(for: project, searchEarlier: searchEarlier, override: override, now: now)
        let reservedLength = project.durationInWorkingDays + max(0, project.bufferInWorkingDays)
        let result = search.findSlots(
            duration: reservedLength,
            from: origin,
            projects: projects,
            excluding: project.id
        )
        let currentStart = project.startDate.map(engine.workingCalendar.startOfDay)
        let slots = result.slots.compactMap { slot in
            engine.jobPortion(of: slot, duration: project.durationInWorkingDays)
        }.filter { engine.workingCalendar.startOfDay($0.start) != currentStart }
        return AvailabilitySearchResult(slots: slots, horizonDays: result.horizonDays)
    }

    func preview(start: Date, duration: Int) -> FreeSlot? {
        let dates = engine.workingDates(start: start, duration: duration)
        guard let first = dates.first, let last = dates.last else { return nil }
        return FreeSlot(start: first, end: last, workingDates: dates)
    }

    func evaluate(
        start: Date,
        project: ProjectSnapshot,
        among projects: [ProjectSnapshot]
    ) -> RescheduleDecision {
        switch engine.validateBooking(
            start: start,
            duration: project.durationInWorkingDays,
            projects: projects,
            excluding: project.id,
            buffer: project.bufferInWorkingDays
        ) {
        case .valid(let dates):
            return .allowed(dates: dates)
        case .conflict:
            return .blocked
        }
    }

    func evaluate(
        slot: FreeSlot,
        project: ProjectSnapshot,
        among projects: [ProjectSnapshot]
    ) -> RescheduleDecision {
        evaluate(start: slot.start, project: project, among: projects)
    }
}
