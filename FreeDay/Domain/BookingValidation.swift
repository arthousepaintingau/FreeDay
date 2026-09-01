import Foundation

enum BookingValidation: Equatable, Sendable {
    case valid(dates: [Date])
    case conflict(suggested: FreeSlot?)
}
