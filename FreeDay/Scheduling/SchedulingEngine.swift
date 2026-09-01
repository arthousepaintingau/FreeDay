import Foundation

/// Pure availability math. Independently testable, no SwiftData, no UI.
struct SchedulingEngine: Sendable {
    var workingCalendar: WorkingCalendar

    init(workingCalendar: WorkingCalendar = .australiaDefault) {
        self.workingCalendar = workingCalendar
    }

    func workingDates(start: Date, duration: Int) -> [Date] {
        workingCalendar.workingDays(startingAt: start, count: duration)
    }

    /// Actual job days only. Buffer is never included.
    func jobDates(for project: ProjectSnapshot) -> [Date] {
        guard let start = project.startDate, project.durationInWorkingDays > 0 else { return [] }
        return workingDates(start: start, duration: project.durationInWorkingDays)
    }

    /// Working days reserved after the job. Quoted and completed projects reserve nothing.
    func bufferDates(for project: ProjectSnapshot) -> [Date] {
        Array(reservedDates(for: project).dropFirst(max(0, project.durationInWorkingDays)))
    }

    /// Job days plus buffer days for booked work. Empty when the project does not block.
    func reservedDates(for project: ProjectSnapshot) -> [Date] {
        guard project.blocksAvailability, let start = project.startDate else { return [] }
        let length = project.durationInWorkingDays + max(0, project.bufferInWorkingDays)
        return workingDates(start: start, duration: length)
    }

    func occupiedDates(
        from projects: [ProjectSnapshot],
        excluding excludedID: UUID? = nil
    ) -> Set<Date> {
        var occupied: Set<Date> = []
        for project in projects where project.id != excludedID && project.blocksAvailability {
            occupied.formUnion(reservedDates(for: project).map(workingCalendar.startOfDay))
        }
        return occupied
    }

    func tentativeDates(
        from projects: [ProjectSnapshot],
        excluding excludedID: UUID? = nil
    ) -> Set<Date> {
        var tentative: Set<Date> = []
        for project in projects where project.id != excludedID && project.showsAsTentative {
            guard let start = project.startDate else { continue }
            let dates = workingDates(start: start, duration: project.durationInWorkingDays)
            tentative.formUnion(dates.map(workingCalendar.startOfDay))
        }
        return tentative
    }

    func availability(
        on date: Date,
        projects: [ProjectSnapshot],
        excluding excludedID: UUID? = nil
    ) -> DayAvailability {
        let day = workingCalendar.startOfDay(date)
        guard workingCalendar.isWorkingDay(day) else { return .nonWorking }
        if occupiedDates(from: projects, excluding: excludedID).contains(day) {
            return .booked
        }
        if tentativeDates(from: projects, excluding: excludedID).contains(day) {
            return .tentative
        }
        return .free
    }

    func findFreeSlots(
        duration: Int,
        from start: Date,
        projects: [ProjectSnapshot],
        excluding excludedID: UUID? = nil,
        resultLimit: Int = 8,
        workingDayHorizon: Int = 260
    ) -> [FreeSlot] {
        guard duration > 0, resultLimit > 0, workingDayHorizon > 0 else { return [] }
        let occupied = occupiedDates(from: projects, excluding: excludedID)
        let window = workingCalendar.workingDays(startingAt: start, count: workingDayHorizon)
        return collectSlots(in: window, duration: duration, occupied: occupied, resultLimit: resultLimit)
    }

    func findFreeSlots(
        duration: Int,
        from start: Date,
        through end: Date,
        projects: [ProjectSnapshot],
        excluding excludedID: UUID? = nil,
        resultLimit: Int = 5
    ) -> [FreeSlot] {
        guard duration > 0, resultLimit > 0 else { return [] }
        let occupied = occupiedDates(from: projects, excluding: excludedID)
        let window = workingCalendar.workingDays(from: start, through: end)
        return collectSlots(in: window, duration: duration, occupied: occupied, resultLimit: resultLimit)
    }

    private func collectSlots(
        in window: [Date],
        duration: Int,
        occupied: Set<Date>,
        resultLimit: Int
    ) -> [FreeSlot] {
        guard window.count >= duration else { return [] }

        var slots: [FreeSlot] = []
        var index = 0
        while index <= window.count - duration, slots.count < resultLimit {
            let candidate = Array(window[index ..< (index + duration)])
            let isFree = candidate.allSatisfy { !occupied.contains($0) }
            if isFree {
                slots.append(
                    FreeSlot(
                        start: candidate[0],
                        end: candidate[candidate.count - 1],
                        workingDates: candidate
                    )
                )
                index += duration
            } else {
                index += 1
            }
        }
        return slots
    }

    func nextAvailableDay(
        from start: Date,
        projects: [ProjectSnapshot],
        excluding excludedID: UUID? = nil,
        workingDayHorizon: Int = 260
    ) -> Date? {
        findFreeSlots(
            duration: 1,
            from: start,
            projects: projects,
            excluding: excludedID,
            resultLimit: 1,
            workingDayHorizon: workingDayHorizon
        ).first?.start
    }

    func validateBooking(
        start: Date,
        duration: Int,
        projects: [ProjectSnapshot],
        excluding excludedID: UUID? = nil,
        buffer: Int = 0
    ) -> BookingValidation {
        let jobLength = max(0, duration)
        let reservedLength = jobLength + max(0, buffer)
        let reserved = workingDates(start: start, duration: reservedLength)
        let job = Array(reserved.prefix(jobLength))
        let occupied = occupiedDates(from: projects, excluding: excludedID)
        let hasConflict = reserved.contains { occupied.contains($0) }
        if hasConflict {
            let suggestedReserved = findFreeSlots(
                duration: reservedLength,
                from: start,
                projects: projects,
                excluding: excludedID,
                resultLimit: 1
            ).first
            return .conflict(suggested: suggestedReserved.flatMap { jobPortion(of: $0, duration: jobLength) })
        }
        return .valid(dates: job)
    }

    func jobPortion(of slot: FreeSlot, duration: Int) -> FreeSlot? {
        let dates = Array(slot.workingDates.prefix(duration))
        guard dates.count == duration, let first = dates.first, let last = dates.last else { return nil }
        return FreeSlot(start: first, end: last, workingDates: dates)
    }
}
