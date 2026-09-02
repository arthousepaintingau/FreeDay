import SwiftUI

/// Tiny sun-character mark. One shape, three moods — never a full illustration.
struct FreeDayMascot: View {
    enum Mood {
        case free
        case booked
        case idle
    }

    var mood: Mood
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.72, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(fill)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    private var symbol: String {
        switch mood {
        case .free: "sun.max.fill"
        case .booked: "cloud.sun.fill"
        case .idle: "sun.min.fill"
        }
    }

    private var fill: Color {
        switch mood {
        case .free: FreeDayColor.freeOn
        case .booked: FreeDayColor.bookedOn
        case .idle: FreeDayColor.brand
        }
    }
}
