import Foundation
@testable import FreeDay
import Testing

struct PersonalityCopyTests {
    @Test("Home copy when today is free and nothing is upcoming")
    func homeLookingGoodWhenEmpty() {
        let copy = PersonalityCopy.home(today: .free, nextAvailable: TestCalendar.date("2026-08-31"), upcomingCount: 0)
        #expect(copy == "Looking good — plenty of space.")
    }

    @Test("Home copy when today is free and jobs are coming")
    func homeGotRoomWhenUpcoming() {
        let copy = PersonalityCopy.home(today: .free, nextAvailable: TestCalendar.date("2026-08-31"), upcomingCount: 2)
        #expect(copy == "Nice! You’ve got some room.")
    }

    @Test("Home copy when booked with later availability")
    func homeBusyWithRoom() {
        let copy = PersonalityCopy.home(today: .booked, nextAvailable: TestCalendar.date("2026-09-03"), upcomingCount: 1)
        #expect(copy == "Looking busy, but you’ve got some room.")
    }

    @Test("Home copy when fully booked")
    func homeFullyBooked() {
        let copy = PersonalityCopy.home(today: .booked, nextAvailable: nil, upcomingCount: 3)
        #expect(copy == "😅 You’re fully booked!")
    }
}
