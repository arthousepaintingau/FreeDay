import SwiftUI

struct MonthView: View {
    let month: CalendarMonthModel
    let formatters: DateFormatters
    var onSelect: (CalendarDayModel) -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        VStack(spacing: FreeDaySpacing.sm) {
            LazyVGrid(columns: columns, spacing: FreeDaySpacing.xxs) {
                ForEach(Array(weekdayHeaders.enumerated()), id: \.offset) { index, symbol in
                    Text(symbol)
                        .font(FreeDayFont.label)
                        .foregroundStyle(index >= 5 ? FreeDayColor.muted.opacity(0.7) : FreeDayColor.muted)
                        .frame(maxWidth: .infinity)
                        .accessibilityHidden(true)
                }
            }

            LazyVGrid(columns: columns, spacing: FreeDaySpacing.xxs) {
                ForEach(Array(month.days.enumerated()), id: \.offset) { _, day in
                    if let day {
                        monthCell(day)
                    } else {
                        Color.clear.frame(minHeight: cellHeight)
                    }
                }
            }
        }
    }

    private var cellHeight: CGFloat {
        sizeClass == .regular ? 80 : 64
    }

    private var weekdayHeaders: [String] {
        month.days.prefix(7).compactMap { day in
            guard let day else { return nil }
            return String(formatters.weekday(day.date).uppercased().prefix(3))
        }
    }

    private func monthCell(_ day: CalendarDayModel) -> some View {
        let inMonth = day.isoDate.hasPrefix(month.monthStamp)
        return Button {
            onSelect(day)
        } label: {
            VStack(spacing: 4) {
                if day.isToday {
                    Text(String(localized: "Today", comment: "Today marker in month grid"))
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .foregroundStyle(FreeDayColor.brand)
                        .textCase(.uppercase)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Text(formatters.dayNumber(day.date))
                    .font(FreeDayFont.caption.weight(.semibold))
                    .foregroundStyle(inMonth ? FreeDayColor.ink : FreeDayColor.muted.opacity(0.45))
                    .monospacedDigit()
                Text(day.kind.badgeTitle)
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .foregroundStyle(FreeDayColor.status(day.kind))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .opacity(dotOpacity(day, inMonth: inMonth))
            }
            .frame(maxWidth: .infinity, minHeight: cellHeight)
            .background(
                RoundedRectangle(cornerRadius: FreeDayRadius.chip, style: .continuous)
                    .fill(FreeDayColor.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: FreeDayRadius.chip, style: .continuous)
                    .stroke(day.isToday ? FreeDayColor.brand : FreeDayColor.hairline.opacity(inMonth ? 0.7 : 0.35), lineWidth: day.isToday ? 2 : 1)
            )
            .opacity(inMonth ? 1 : 0.55)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(day.spokenLabel(fullDate: formatters.fullDate(day.date)))
        .accessibilityHint(hint(for: day))
        .accessibilityIdentifier("calendar-day-\(day.isoDate)")
        .accessibilityAddTraits(.isButton)
    }

    private func dotOpacity(_ day: CalendarDayModel, inMonth: Bool) -> Double {
        if !inMonth { return 0.25 }
        switch day.kind {
        case .nonWorking: return 0.28
        case .completed: return 0.45
        default: return 1
        }
    }

    private func hint(for day: CalendarDayModel) -> String {
        if day.projectToOpen != nil {
            return String(localized: "Opens project details", comment: "Calendar booked or quoted day")
        }
        if day.canUseDay {
            return String(localized: "Use this free day", comment: "Calendar free day")
        }
        return String(localized: "Not a working day", comment: "Calendar weekend")
    }
}
