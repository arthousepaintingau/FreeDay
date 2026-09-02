import SwiftUI

/// Polished availability answer. Colour plus text; never colour alone.
struct AvailabilityHero: View {
    enum Kind {
        case free
        case booked
    }

    var kind: Kind
    var title: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .center, spacing: FreeDaySpacing.sm) {
            FreeDayMascot(mood: kind == .free ? .free : .booked, size: 44)
            HStack(spacing: 8) {
                Image(systemName: kind == .free ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title3.weight(.bold))
                    .accessibilityHidden(true)
                Text(title)
                    .font(FreeDayFont.headline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(kind == .free ? FreeDayColor.freeOn : FreeDayColor.bookedOn)
        .padding(.horizontal, FreeDaySpacing.md)
        .padding(.vertical, FreeDaySpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(kind == .free ? FreeDayColor.free : FreeDayColor.booked)
        .clipShape(RoundedRectangle(cornerRadius: FreeDayRadius.button, style: .continuous))
        .shadow(color: (kind == .free ? FreeDayColor.free : FreeDayColor.booked).opacity(reduceMotion ? 0 : 0.28), radius: reduceMotion ? 0 : 8, y: 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }
}
