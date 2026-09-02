import SwiftUI

enum FreeDayCardEmphasis {
    case none
    case free
    case booked
    case current
    case proposed
}

struct FreeDayCard<Content: View>: View {
    var padding: CGFloat = FreeDaySpacing.lg
    var emphasize: FreeDayCardEmphasis = .none
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: FreeDayRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FreeDayRadius.card, style: .continuous)
                    .stroke(border, lineWidth: emphasize == .none ? 1 : 2)
            )
            .shadow(color: emphasize == .none ? FreeDayColor.lift : .clear, radius: 8, y: 3)
    }

    private var fill: Color {
        switch emphasize {
        case .none, .current: FreeDayColor.surface
        case .free, .proposed: FreeDayColor.surface
        case .booked: FreeDayColor.surface
        }
    }

    private var border: Color {
        switch emphasize {
        case .none: FreeDayColor.hairline
        case .free: FreeDayColor.free.opacity(0.7)
        case .booked: FreeDayColor.booked.opacity(0.7)
        case .current: FreeDayColor.muted.opacity(0.35)
        case .proposed: FreeDayColor.free.opacity(0.7)
        }
    }
}

enum FreeDayDurationCopy {
    static func days(_ count: Int) -> String {
        if count == 1 {
            String(localized: "1 day", comment: "Singular duration value")
        } else {
            String(localized: "\(count) days", comment: "Duration value with unit")
        }
    }

    static func workingDays(_ count: Int) -> String {
        if count == 1 {
            String(localized: "1 working day", comment: "Singular working-day duration")
        } else {
            String(localized: "\(count) working days", comment: "Working-day duration")
        }
    }
}

struct StatusBadge: View {
    let availability: DayAvailability

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: availability == .free ? "checkmark.circle.fill" : availability == .booked ? "xmark.circle.fill" : "circle.fill")
                .font(.system(size: 12, weight: .bold))
                .accessibilityHidden(true)
            Text(availability.title.uppercased())
                .font(FreeDayFont.label)
                .tracking(0.6)
        }
        .foregroundStyle(FreeDayColor.status(availability))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(FreeDayColor.status(availability).opacity(0.18))
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(availability.title)
    }
}

struct CalendarStatusBadge: View {
    let kind: CalendarDayKind

    var body: some View {
        let tint = FreeDayColor.status(kind)
        HStack(spacing: 6) {
            Image(systemName: calendarBadgeSymbol(kind))
                .font(.system(size: 11, weight: .bold))
                .accessibilityHidden(true)
            Text(kind.badgeTitle.uppercased())
                .font(FreeDayFont.label)
                .tracking(0.6)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(tint.opacity(0.2))
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(kind.badgeTitle)
    }

    private func calendarBadgeSymbol(_ kind: CalendarDayKind) -> String {
        switch kind {
        case .free, .completed: "checkmark.circle.fill"
        case .booked: "xmark.circle.fill"
        case .buffer: "pause.circle.fill"
        case .quoted: "circle.fill"
        case .nonWorking: "moon.zzz.fill"
        }
    }
}

struct ProjectStatusBadge: View {
    let status: ProjectStatus

    var body: some View {
        let availability: DayAvailability = switch status {
        case .booked: .booked
        case .quoted: .tentative
        case .completed: .nonWorking
        }
        HStack(spacing: 6) {
            Image(systemName: status == .booked ? "xmark.circle.fill" : status == .quoted ? "circle.fill" : "checkmark.circle.fill")
                .font(.system(size: 12, weight: .bold))
                .accessibilityHidden(true)
            Text(status.title.uppercased())
                .font(FreeDayFont.label)
                .tracking(0.6)
        }
        .foregroundStyle(FreeDayColor.status(availability))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(FreeDayColor.status(availability).opacity(0.18))
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(status.title)
    }
}

struct DayStepper: View {
    @Binding var days: Int
    var range: ClosedRange<Int> = 1...30
    var unitPlacement: UnitPlacement = .header
    var decreaseAccessibilityLabel: String = String(localized: "Decrease days", comment: "Duration stepper")
    var increaseAccessibilityLabel: String = String(localized: "Increase days", comment: "Duration stepper")
    var valueAccessibilityLabel: ((Int) -> String)? = nil

    enum UnitPlacement {
        case header
        case value
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: FreeDaySpacing.sm) {
            if unitPlacement == .header {
                FreeDaySectionHeader(title: String(localized: "Days", comment: "Duration stepper label"))
            }

            HStack(spacing: FreeDaySpacing.lg) {
                stepperButton(systemImage: "minus", delta: -1)
                    .accessibilityLabel(decreaseAccessibilityLabel)

                Group {
                    if unitPlacement == .value {
                        Text(daysLabel)
                        .textCase(.uppercase)
                    } else {
                        Text("\(days)")
                    }
                }
                .font(FreeDayFont.display)
                .foregroundStyle(FreeDayColor.ink)
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(Motion.animation(reduceMotion), value: days)
                .frame(minWidth: FreeDaySpacing.touch)
                .accessibilityLabel(
                    valueAccessibilityLabel?(days)
                        ?? String(localized: "\(days) working days", comment: "Duration value")
                )

                stepperButton(systemImage: "plus", delta: 1)
                    .accessibilityLabel(increaseAccessibilityLabel)
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .contain)
    }

    private var daysLabel: String {
        FreeDayDurationCopy.days(days)
    }

    private func stepperButton(systemImage: String, delta: Int) -> some View {
        Button {
            days = min(max(days + delta, range.lowerBound), range.upperBound)
            FreeDayHaptics.selection()
        } label: {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(FreeDayColor.ink)
                .frame(width: 48, height: 48)
                .background(FreeDayColor.hairline.opacity(0.45))
                .clipShape(Circle())
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(
            (delta < 0 && days <= range.lowerBound) ||
            (delta > 0 && days >= range.upperBound)
        )
    }
}
