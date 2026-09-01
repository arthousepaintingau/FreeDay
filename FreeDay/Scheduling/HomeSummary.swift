import Foundation

struct HomeSummary: Equatable, Sendable {
    var todayAvailability: DayAvailability
    var nextAvailable: Date?
    var upcoming: [ProjectSnapshot]
    var personality: String?
}

enum PersonalityCopy {
    static func home(today: DayAvailability, nextAvailable: Date?, upcomingCount: Int = 0) -> String? {
        if today == .booked, nextAvailable == nil {
            return String(localized: "😅 You’re fully booked!", comment: "Home personality when no free days")
        }
        if today == .free, upcomingCount == 0 {
            return plentyOfSpace
        }
        if today == .free {
            return String(localized: "Nice! You’ve got some room.", comment: "Home personality when today is free")
        }
        if nextAvailable != nil {
            return lookingBusy
        }
        return nil
    }

    static var plentyOfSpace: String {
        String(localized: "Looking good — plenty of space.", comment: "Open schedule personality")
    }

    static var plentyOfRoom: String {
        String(localized: "Nice. You’ve got plenty of room.", comment: "Coming capacity when light")
    }

    static var gotSomeSpace: String {
        String(localized: "Looking good — you’ve got some space.", comment: "Coming capacity when balanced")
    }

    static var lookingBusy: String {
        String(localized: "Looking busy, but you’ve got some room.", comment: "Busy schedule with remaining space")
    }

    static var perfectFit: String {
        String(localized: "🎯 Perfect fit!", comment: "Shown when a job fits a free slot")
    }

    static var yesYoureFree: String {
        String(localized: "🎯 Yes — you’re free.", comment: "Specific date is available")
    }

    static var notAvailable: String {
        String(localized: "😅 Not available.", comment: "Specific date is unavailable")
    }

    static func conflictsWith(_ name: String) -> String {
        String(localized: "Those dates conflict with \(name).", comment: "Specific date conflict")
    }

    static var jobDone: String {
        String(localized: "🥳 Job done!", comment: "Shown after marking a project complete")
    }

    static var notEnoughDays: String {
        String(localized: "Not enough available days.", comment: "Conflict prevention message")
    }

    static var breathingRoom: String {
        String(localized: "Nice. A little breathing room.", comment: "Shown after adding a project with buffer")
    }

    static var thingsGettingBusy: String {
        String(localized: "Things are getting busy!", comment: "Shown after adding a project")
    }

    static var perfectFitShort: String {
        String(localized: "Perfect fit!", comment: "Next available slot caption without emoji")
    }

    static var gotRoom: String {
        String(localized: "Nice! You’ve got room.", comment: "Shown when more free slots exist")
    }

    static var fullyBooked: String {
        String(localized: "😅 You’re fully booked!", comment: "No free slot in the search horizon")
    }

    static var newDatesLockedIn: String {
        String(localized: "👍 New dates locked in.", comment: "Shown after a successful reschedule")
    }

    static var datesNoLongerAvailable: String {
        String(localized: "Those dates are no longer available.", comment: "Stale reschedule conflict")
    }

    static var datesConflict: String {
        String(localized: "Those dates conflict with another booked job.", comment: "Manual reschedule conflict")
    }

    static func noSlot(horizonDays: Int) -> String {
        String(
            localized: "No available slot found in the next \(horizonDays) days.",
            comment: "Empty availability search"
        )
    }

    static func week(bookedWorkingDays: Int, workingDays: Int) -> String? {
        guard workingDays > 0 else { return nil }
        if bookedWorkingDays == 0 {
            return String(localized: "Nice! You’ve got some room.", comment: "Week with free days")
        }
        if bookedWorkingDays >= workingDays {
            return String(localized: "😅 You’re fully booked!", comment: "Week with no free working days")
        }
        return String(localized: "Looking busy, but you’ve got some room.", comment: "Mixed week")
    }
}

struct HomeSummaryBuilder: Sendable {
    var engine: SchedulingEngine

    func make(projects: [ProjectSnapshot], now: Date, upcomingLimit: Int = 5) -> HomeSummary {
        let calendar = engine.workingCalendar
        let today = calendar.startOfDay(now)
        let todayAvailability = engine.availability(on: today, projects: projects)
        let nextAvailable = engine.nextAvailableDay(from: today, projects: projects)
        let upcoming = projects
            .filter { $0.status == .booked }
            .sorted { lhs, rhs in
                (lhs.startDate ?? .distantFuture) < (rhs.startDate ?? .distantFuture)
            }
            .filter { project in
                guard let start = project.startDate else { return true }
                let last = engine.workingDates(start: start, duration: project.durationInWorkingDays).last
                return (last ?? start) >= today
            }
            .prefix(upcomingLimit)

        return HomeSummary(
            todayAvailability: todayAvailability,
            nextAvailable: nextAvailable,
            upcoming: Array(upcoming),
            personality: PersonalityCopy.home(
                today: todayAvailability,
                nextAvailable: nextAvailable,
                upcomingCount: upcoming.count
            )
        )
    }
}
