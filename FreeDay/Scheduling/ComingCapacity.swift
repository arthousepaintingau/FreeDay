import Foundation

enum BusyLevel: Equatable, Sendable {
    case light
    case balanced
    case busy
    case packed

    var title: String {
        switch self {
        case .light: String(localized: "Light", comment: "Capacity meter")
        case .balanced: String(localized: "Balanced", comment: "Capacity meter")
        case .busy: String(localized: "Busy", comment: "Capacity meter")
        case .packed: String(localized: "Packed 😅", comment: "Capacity meter")
        }
    }

    var spokenTitle: String {
        switch self {
        case .light: String(localized: "Light", comment: "Spoken capacity meter")
        case .balanced: String(localized: "Balanced", comment: "Spoken capacity meter")
        case .busy: String(localized: "Busy", comment: "Spoken capacity meter")
        case .packed: String(localized: "Packed", comment: "Spoken capacity meter")
        }
    }

    static func occupancyPercent(occupied: Int, working: Int) -> Int {
        guard working > 0 else { return 0 }
        return Int((Double(occupied) / Double(working) * 100).rounded())
    }

    static func from(occupied: Int, working: Int) -> BusyLevel {
        switch occupancyPercent(occupied: occupied, working: working) {
        case ...24: .light
        case 25...49: .balanced
        case 50...74: .busy
        default: .packed
        }
    }
}

struct ComingDay: Equatable, Identifiable, Sendable {
    var date: Date
    var isoDate: String
    var kind: CalendarDayKind
    var project: ProjectSnapshot?
    var isToday: Bool
    var isWorkingDay: Bool

    var id: Date { date }

    var canUseDay: Bool {
        isWorkingDay && kind == .free
    }

    var displayName: String? {
        kind == .booked ? project?.customerName : nil
    }

    func spokenLabel(fullDate: String) -> String {
        let todayPrefix = isToday ? String(localized: "Today. ", comment: "Spoken today prefix") : ""
        switch kind {
        case .booked:
            if let name = project?.customerName, !name.isEmpty {
                return "\(todayPrefix)\(fullDate). Booked. \(name)."
            }
            return "\(todayPrefix)\(fullDate). Booked."
        case .buffer:
            return "\(todayPrefix)\(fullDate). Reserved buffer day."
        case .free:
            return "\(todayPrefix)\(fullDate). Free working day."
        default:
            return "\(todayPrefix)\(fullDate). Off."
        }
    }
}

struct ComingSection: Equatable, Identifiable, Sendable {
    enum Kind: Equatable, Sendable {
        case thisWeek
        case nextWeek
        case later
    }

    var weekStart: Date
    var kind: Kind
    var days: [ComingDay]

    var id: Date { weekStart }
}

/// 14-day capacity snapshot. Occupancy comes from `CalendarOccupancyIndex` / the scheduling engine.
struct ComingCapacity: Equatable, Sendable {
    static let windowDays = 14

    var start: Date
    var end: Date
    var days: [ComingDay]
    var sections: [ComingSection]
    var freeWorkingDays: Int
    var bookedJobs: Int
    var bufferDays: Int
    var occupiedWorkingDays: Int
    var workingDayCount: Int
    var occupancyPercent: Int
    var busyLevel: BusyLevel

    var personality: String {
        switch busyLevel {
        case .light: PersonalityCopy.plentyOfRoom
        case .balanced: PersonalityCopy.gotSomeSpace
        case .busy: PersonalityCopy.thingsGettingBusy
        case .packed: PersonalityCopy.fullyBooked
        }
    }

    var spokenBusyMeter: String {
        String(
            localized: "Schedule capacity: \(busyLevel.spokenTitle). \(occupancyPercent) percent occupied.",
            comment: "VoiceOver for the busy meter"
        )
    }

    var homeSummaryLine: String {
        String(
            localized: "\(freeWorkingDays) free days · \(bookedJobs) booked jobs",
            comment: "Home teaser for What’s Coming"
        )
    }

    func day(iso: String) -> ComingDay? {
        days.first { $0.isoDate == iso }
    }
}

struct ComingCapacityBuilder: Sendable {
    var engine: SchedulingEngine

    func make(projects: [ProjectSnapshot], now: Date) -> ComingCapacity {
        let calendar = engine.workingCalendar
        let presentation = CalendarPresentation(engine: engine)
        let index = CalendarOccupancyIndex(projects: projects, engine: engine)
        let start = calendar.startOfDay(now)
        let end = calendar.date(byAddingDays: ComingCapacity.windowDays - 1, to: start)
        let today = start
        let thisWeekStart = presentation.startOfWeek(for: start)
        let nextWeekStart = presentation.addingWeeks(1, to: start)

        let days: [ComingDay] = (0..<ComingCapacity.windowDays).map { offset in
            let date = calendar.date(byAddingDays: offset, to: start)
            return day(on: date, index: index, today: today)
        }

        let working = days.filter(\.isWorkingDay)
        let occupiedDays = working.filter { $0.kind == .booked || $0.kind == .buffer }
        let bufferDays = working.filter { $0.kind == .buffer }.count
        let bookedJobIDs = Set(working.compactMap { day -> UUID? in
            guard day.kind == .booked else { return nil }
            return day.project?.id
        })
        let occupiedCount = occupiedDays.count
        let workingCount = working.count
        let percent = BusyLevel.occupancyPercent(occupied: occupiedCount, working: workingCount)

        return ComingCapacity(
            start: start,
            end: end,
            days: days,
            sections: sections(
                days: days,
                thisWeekStart: thisWeekStart,
                nextWeekStart: nextWeekStart,
                presentation: presentation
            ),
            freeWorkingDays: workingCount - occupiedCount,
            bookedJobs: bookedJobIDs.count,
            bufferDays: bufferDays,
            occupiedWorkingDays: occupiedCount,
            workingDayCount: workingCount,
            occupancyPercent: percent,
            busyLevel: BusyLevel.from(occupied: occupiedCount, working: workingCount)
        )
    }

    private func day(on date: Date, index: CalendarOccupancyIndex, today: Date) -> ComingDay {
        let calendar = engine.workingCalendar
        let day = calendar.startOfDay(date)
        let isWorking = calendar.isWorkingDay(day)
        let booked = index.bookedProjects(on: day)
        let buffered = index.bufferProjects(on: day)

        let kind: CalendarDayKind
        let project: ProjectSnapshot?
        if !isWorking {
            kind = .nonWorking
            project = nil
        } else if let firstBooked = booked.first {
            kind = .booked
            project = firstBooked
        } else if let firstBuffer = buffered.first {
            kind = .buffer
            project = firstBuffer
        } else {
            kind = .free
            project = nil
        }

        return ComingDay(
            date: day,
            isoDate: isoString(for: day),
            kind: kind,
            project: project,
            isToday: day == today,
            isWorkingDay: isWorking
        )
    }

    private func sections(
        days: [ComingDay],
        thisWeekStart: Date,
        nextWeekStart: Date,
        presentation: CalendarPresentation
    ) -> [ComingSection] {
        var grouped: [(Date, [ComingDay])] = []
        for day in days {
            let weekStart = presentation.startOfWeek(for: day.date)
            if let last = grouped.last, last.0 == weekStart {
                grouped[grouped.count - 1].1.append(day)
            } else {
                grouped.append((weekStart, [day]))
            }
        }
        return grouped.map { weekStart, weekDays in
            let kind: ComingSection.Kind
            if weekStart == thisWeekStart {
                kind = .thisWeek
            } else if weekStart == nextWeekStart {
                kind = .nextWeek
            } else {
                kind = .later
            }
            return ComingSection(weekStart: weekStart, kind: kind, days: weekDays)
        }
    }

    private func isoString(for date: Date) -> String {
        let parts = engine.workingCalendar.calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
