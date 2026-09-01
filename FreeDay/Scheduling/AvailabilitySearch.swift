import Foundation

struct AvailabilitySearchOptions: Equatable, Sendable {
    /// Calendar days ahead to search, including the start date's offset.
    var calendarDayHorizon: Int
    var resultLimit: Int

    static let defaults = AvailabilitySearchOptions(
        calendarDayHorizon: 90,
        resultLimit: 5
    )
}

struct AvailabilitySearchResult: Equatable, Sendable {
    var slots: [FreeSlot]
    var horizonDays: Int

    var next: FreeSlot? { slots.first }
    var others: [FreeSlot] { Array(slots.dropFirst()) }
    var isEmpty: Bool { slots.isEmpty }
}

/// Find Free Days search. Uses the scheduling engine; does not duplicate occupancy rules.
struct AvailabilitySearch: Sendable {
    var engine: SchedulingEngine
    var options: AvailabilitySearchOptions

    init(
        engine: SchedulingEngine,
        options: AvailabilitySearchOptions = .defaults
    ) {
        self.engine = engine
        self.options = options
    }

    func findSlots(
        duration: Int,
        from start: Date,
        projects: [ProjectSnapshot],
        excluding excludedID: UUID? = nil,
        horizonDays: Int? = nil
    ) -> AvailabilitySearchResult {
        let calendar = engine.workingCalendar
        let from = calendar.startOfDay(start)
        let horizon = horizonDays ?? options.calendarDayHorizon
        let through = calendar.date(byAddingDays: horizon, to: from)
        let slots = engine.findFreeSlots(
            duration: duration,
            from: from,
            through: through,
            projects: projects,
            excluding: excludedID,
            resultLimit: options.resultLimit
        )
        return AvailabilitySearchResult(slots: slots, horizonDays: horizon)
    }
}
