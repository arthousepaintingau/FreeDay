import Foundation

enum CalendarDayKind: Equatable, Sendable {
    case free
    case booked
    case buffer
    case quoted
    case completed
    case nonWorking

    var badgeTitle: String {
        switch self {
        case .free, .completed: String(localized: "Free", comment: "Calendar day status")
        case .booked: String(localized: "Booked", comment: "Calendar day status")
        case .buffer: String(localized: "Buffer", comment: "Calendar buffer day status")
        case .quoted: String(localized: "Quoted", comment: "Calendar day status")
        case .nonWorking: String(localized: "Off", comment: "Non-working calendar day")
        }
    }

    var colorAvailability: DayAvailability {
        switch self {
        case .free, .completed: .free
        case .booked: .booked
        case .buffer: .tentative
        case .quoted: .tentative
        case .nonWorking: .nonWorking
        }
    }
}

struct CalendarDayModel: Equatable, Identifiable, Sendable {
    var date: Date
    var isoDate: String
    var kind: CalendarDayKind
    var primaryProject: ProjectSnapshot?
    var historyProject: ProjectSnapshot?
    var isToday: Bool
    var isWorkingDay: Bool

    var id: Date { date }

    var canUseDay: Bool {
        isWorkingDay && (kind == .free || kind == .completed)
    }

    var projectToOpen: ProjectSnapshot? {
        switch kind {
        case .booked, .quoted, .buffer: primaryProject
        default: nil
        }
    }

    var displayName: String? {
        switch kind {
        case .booked, .quoted, .buffer: primaryProject?.customerName
        case .completed: historyProject?.customerName
        default: nil
        }
    }

    var durationHint: String? {
        guard let project = primaryProject, project.durationInWorkingDays > 1 else { return nil }
        switch kind {
        case .booked, .quoted:
            return String(localized: "\(project.durationInWorkingDays) days", comment: "Multi-day duration on a calendar card")
        default:
            return nil
        }
    }

    func spokenLabel(fullDate: String) -> String {
        let todayPrefix = isToday ? String(localized: "Today. ", comment: "Spoken today prefix") : ""
        switch kind {
        case .free:
            return "\(todayPrefix)\(fullDate). Free."
        case .booked:
            if let name = primaryProject?.customerName, !name.isEmpty {
                return "\(todayPrefix)\(fullDate). Booked. \(name)."
            }
            return "\(todayPrefix)\(fullDate). Booked."
        case .buffer:
            return "\(todayPrefix)\(fullDate). Reserved buffer day."
        case .quoted:
            if let name = primaryProject?.customerName, !name.isEmpty {
                return "\(todayPrefix)\(fullDate). Quoted. \(name)."
            }
            return "\(todayPrefix)\(fullDate). Quoted."
        case .completed:
            if let name = historyProject?.customerName, !name.isEmpty {
                return "\(todayPrefix)\(fullDate). Free. Completed. \(name)."
            }
            return "\(todayPrefix)\(fullDate). Free."
        case .nonWorking:
            return "\(todayPrefix)\(fullDate). Off."
        }
    }
}

struct CalendarWeekModel: Equatable, Sendable {
    var start: Date
    var days: [CalendarDayModel]
    var personality: String?
    var containsToday: Bool

    var workingDays: [CalendarDayModel] { days.filter(\.isWorkingDay) }
    var weekendDays: [CalendarDayModel] { days.filter { !$0.isWorkingDay } }

    func day(iso: String) -> CalendarDayModel? {
        days.first { $0.isoDate == iso }
    }
}

struct CalendarMonthModel: Equatable, Sendable {
    var monthStart: Date
    var monthStamp: String
    var days: [CalendarDayModel?]
    var containsToday: Bool

    func day(iso: String) -> CalendarDayModel? {
        days.compactMap { $0 }.first { $0.isoDate == iso }
    }
}

struct CalendarOccupancyIndex: Sendable {
    private var booked: [Date: [ProjectSnapshot]] = [:]
    private var buffer: [Date: [ProjectSnapshot]] = [:]
    private var quoted: [Date: [ProjectSnapshot]] = [:]
    private var completed: [Date: [ProjectSnapshot]] = [:]

    init(projects: [ProjectSnapshot], engine: SchedulingEngine) {
        let calendar = engine.workingCalendar
        for project in projects {
            for date in engine.jobDates(for: project) {
                let day = calendar.startOfDay(date)
                switch project.status {
                case .booked: booked[day, default: []].append(project)
                case .quoted: quoted[day, default: []].append(project)
                case .completed: completed[day, default: []].append(project)
                }
            }
            if project.blocksAvailability {
                for date in engine.bufferDates(for: project) {
                    let day = calendar.startOfDay(date)
                    buffer[day, default: []].append(project)
                }
            }
        }
    }

    func bookedProjects(on day: Date) -> [ProjectSnapshot] { booked[day] ?? [] }
    func bufferProjects(on day: Date) -> [ProjectSnapshot] { buffer[day] ?? [] }
    func quotedProjects(on day: Date) -> [ProjectSnapshot] { quoted[day] ?? [] }
    func completedProjects(on day: Date) -> [ProjectSnapshot] { completed[day] ?? [] }
}

/// Calendar display built from the same scheduling engine Home and Find Free Days use.
struct CalendarPresentation: Sendable {
    var engine: SchedulingEngine

    func week(containing date: Date, projects: [ProjectSnapshot], now: Date = .now) -> CalendarWeekModel {
        let index = CalendarOccupancyIndex(projects: projects, engine: engine)
        let start = startOfWeek(for: date)
        let days = (0..<7).compactMap { offset -> CalendarDayModel? in
            guard let day = engine.workingCalendar.calendar.date(byAdding: .day, value: offset, to: start) else {
                return nil
            }
            return model(on: day, index: index, now: now)
        }
        let bookedWorkingDays = days.filter { $0.isWorkingDay && ($0.kind == .booked || $0.kind == .buffer) }.count
        let workingCount = days.filter(\.isWorkingDay).count
        return CalendarWeekModel(
            start: start,
            days: days,
            personality: PersonalityCopy.week(bookedWorkingDays: bookedWorkingDays, workingDays: workingCount),
            containsToday: days.contains(where: \.isToday)
        )
    }

    func month(containing date: Date, projects: [ProjectSnapshot], now: Date = .now) -> CalendarMonthModel {
        let index = CalendarOccupancyIndex(projects: projects, engine: engine)
        let calendar = engine.workingCalendar.calendar
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: date))
            ?? engine.workingCalendar.startOfDay(date)
        let cells = monthCells(containing: monthStart)
        let days = cells.map { cell -> CalendarDayModel? in
            guard let cell else { return nil }
            return model(on: cell, index: index, now: now)
        }
        return CalendarMonthModel(
            monthStart: monthStart,
            monthStamp: String(isoString(for: monthStart).prefix(7)),
            days: days,
            containsToday: days.contains(where: { $0?.isToday == true })
        )
    }

    func addingWeeks(_ count: Int, to date: Date) -> Date {
        engine.workingCalendar.calendar.date(byAdding: .weekOfYear, value: count, to: startOfWeek(for: date))
            ?? date
    }

    func addingMonths(_ count: Int, to date: Date) -> Date {
        engine.workingCalendar.calendar.date(byAdding: .month, value: count, to: date) ?? date
    }

    func startOfWeek(for date: Date) -> Date {
        let calendar = engine.workingCalendar.calendar
        return calendar.dateInterval(of: .weekOfYear, for: date)?.start
            ?? engine.workingCalendar.startOfDay(date)
    }

    func isCurrentWeek(_ date: Date, now: Date = .now) -> Bool {
        startOfWeek(for: date) == startOfWeek(for: now)
    }

    func isCurrentMonth(_ date: Date, now: Date = .now) -> Bool {
        engine.workingCalendar.calendar.isDate(date, equalTo: now, toGranularity: .month)
    }

    private func model(on date: Date, index: CalendarOccupancyIndex, now: Date) -> CalendarDayModel {
        let calendar = engine.workingCalendar
        let day = calendar.startOfDay(date)
        let today = calendar.startOfDay(now)
        let isWorking = calendar.isWorkingDay(day)
        let booked = index.bookedProjects(on: day)
        let buffered = index.bufferProjects(on: day)
        let quoted = index.quotedProjects(on: day)
        let completed = index.completedProjects(on: day)

        let kind: CalendarDayKind
        let primary: ProjectSnapshot?
        if !isWorking {
            kind = .nonWorking
            primary = nil
        } else if let firstBooked = booked.first {
            kind = .booked
            primary = firstBooked
        } else if let firstBuffer = buffered.first {
            kind = .buffer
            primary = firstBuffer
        } else if let firstQuoted = quoted.first {
            kind = .quoted
            primary = firstQuoted
        } else if completed.isEmpty {
            kind = .free
            primary = nil
        } else {
            kind = .completed
            primary = nil
        }

        return CalendarDayModel(
            date: day,
            isoDate: isoString(for: day),
            kind: kind,
            primaryProject: primary,
            historyProject: completed.first,
            isToday: day == today,
            isWorkingDay: isWorking
        )
    }

    private func isoString(for date: Date) -> String {
        let parts = engine.workingCalendar.calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    private func monthCells(containing monthStart: Date) -> [Date?] {
        let calendar = engine.workingCalendar.calendar
        guard
            let monthInterval = calendar.dateInterval(of: .month, for: monthStart),
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: monthStart)?.start
        else { return [] }

        let dayCount = calendar.dateComponents([.day], from: weekStart, to: monthInterval.end).day ?? 0
        let padded = ((max(dayCount, 1) + 6) / 7) * 7
        return (0..<padded).map { offset in
            calendar.date(byAdding: .day, value: offset, to: weekStart)
        }
    }
}
