import Foundation

/// Read-only availability check. Uses `AvailabilitySearch` — never a second occupancy implementation.
struct QuickCheck: Equatable, Sendable {
    static let minDuration = 1
    static let maxDuration = 30
    static let defaultDuration = 3
    static let horizonStep = 90
    static let maxHorizon = 270

    var duration: Int = Self.defaultDuration
    var from: Date
    var horizonDays: Int = AvailabilitySearchOptions.defaults.calendarDayHorizon

    init(
        from: Date,
        duration: Int = Self.defaultDuration,
        horizonDays: Int = AvailabilitySearchOptions.defaults.calendarDayHorizon
    ) {
        self.from = from
        self.duration = min(max(duration, Self.minDuration), Self.maxDuration)
        self.horizonDays = horizonDays
    }

    var canSearchFurther: Bool {
        horizonDays < Self.maxHorizon
    }

    mutating func setDuration(_ value: Int) {
        duration = min(max(value, Self.minDuration), Self.maxDuration)
        horizonDays = AvailabilitySearchOptions.defaults.calendarDayHorizon
    }

    mutating func searchFurther() {
        guard canSearchFurther else { return }
        horizonDays = min(horizonDays + Self.horizonStep, Self.maxHorizon)
    }

    func result(
        search: AvailabilitySearch,
        projects: [ProjectSnapshot]
    ) -> AvailabilitySearchResult {
        search.findSlots(
            duration: duration,
            from: from,
            projects: projects,
            horizonDays: horizonDays
        )
    }

    func message(for result: AvailabilitySearchResult) -> String? {
        if result.isEmpty {
            return PersonalityCopy.fullyBooked
        }
        if result.others.count >= 3 {
            return PersonalityCopy.plentyOfSpace
        }
        if result.others.isEmpty {
            return PersonalityCopy.perfectFit
        }
        return PersonalityCopy.lookingBusy
    }
}
