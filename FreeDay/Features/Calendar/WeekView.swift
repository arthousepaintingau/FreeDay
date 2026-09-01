import SwiftUI

struct WeekView: View {
    let week: CalendarWeekModel
    let formatters: DateFormatters
    var onSelect: (CalendarDayModel) -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if sizeClass == .regular {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .animation(Motion.animation(reduceMotion), value: week.start)
    }

    private var iPhoneLayout: some View {
        VStack(spacing: FreeDaySpacing.sm) {
            ForEach(week.workingDays) { day in
                CalendarDayCard(day: day, formatters: formatters, style: .prominent) {
                    onSelect(day)
                }
            }
            HStack(spacing: FreeDaySpacing.sm) {
                ForEach(week.weekendDays) { day in
                    CalendarDayCard(day: day, formatters: formatters, style: .weekend) {
                        onSelect(day)
                    }
                }
            }
        }
    }

    private var iPadLayout: some View {
        VStack(spacing: FreeDaySpacing.sm) {
            HStack(alignment: .top, spacing: FreeDaySpacing.sm) {
                ForEach(week.workingDays) { day in
                    CalendarDayCard(day: day, formatters: formatters, style: .prominent) {
                        onSelect(day)
                    }
                }
            }
            HStack(spacing: FreeDaySpacing.sm) {
                ForEach(week.weekendDays) { day in
                    CalendarDayCard(day: day, formatters: formatters, style: .weekend) {
                        onSelect(day)
                    }
                }
                ForEach(0..<3, id: \.self) { _ in
                    Color.clear.frame(maxWidth: .infinity)
                }
            }
        }
    }
}

struct CalendarDayCard: View {
    let day: CalendarDayModel
    let formatters: DateFormatters
    var style: Style = .prominent
    var onSelect: () -> Void

    enum Style {
        case prominent
        case weekend
    }

    var body: some View {
        Button(action: onSelect) {
            Group {
                if style == .weekend {
                    weekendContent
                } else {
                    prominentContent
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(style == .weekend ? FreeDaySpacing.md : FreeDaySpacing.md)
            .background(FreeDayColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: FreeDayRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FreeDayRadius.card, style: .continuous)
                    .stroke(border, lineWidth: day.isToday ? 2 : 1)
            )
            .opacity(style == .weekend ? 0.62 : 1)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(day.spokenLabel(fullDate: formatters.fullDate(day.date)))
        .accessibilityHint(hint)
        .accessibilityIdentifier("calendar-day-\(day.isoDate)")
        .accessibilityAddTraits(.isButton)
    }

    private var border: Color {
        if day.isToday { return FreeDayColor.brand }
        if style == .weekend { return FreeDayColor.hairline.opacity(0.6) }
        switch day.kind {
        case .free, .completed: return FreeDayColor.free.opacity(0.45)
        case .booked: return FreeDayColor.booked.opacity(0.5)
        case .buffer: return FreeDayColor.buffer.opacity(0.55)
        case .quoted: return FreeDayColor.tentative.opacity(0.5)
        case .nonWorking: return FreeDayColor.hairline.opacity(0.6)
        }
    }

    private var prominentContent: some View {
        VStack(alignment: .leading, spacing: FreeDaySpacing.xs) {
            if day.isToday {
                Text(String(localized: "Today", comment: "Today marker on a calendar card"))
                    .font(FreeDayFont.label)
                    .foregroundStyle(FreeDayColor.brand)
                    .textCase(.uppercase)
                    .tracking(1.2)
            }
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    dayHeading
                    Spacer(minLength: 8)
                    CalendarStatusBadge(kind: day.kind)
                        .fixedSize(horizontal: true, vertical: false)
                }
                VStack(alignment: .leading, spacing: 8) {
                    dayHeading
                    CalendarStatusBadge(kind: day.kind)
                }
            }
            if day.kind == .booked || day.kind == .quoted, let name = day.displayName {
                Text(name)
                    .font(FreeDayFont.headline)
                    .foregroundStyle(FreeDayColor.ink)
                    .lineLimit(1)
            }
            if day.kind == .buffer, let name = day.displayName {
                Text(name)
                    .font(FreeDayFont.caption)
                    .foregroundStyle(FreeDayColor.muted)
                    .lineLimit(1)
            }
            if let duration = day.durationHint {
                Text(duration)
                    .font(FreeDayFont.caption)
                    .foregroundStyle(FreeDayColor.muted)
            }
            if day.kind == .completed, let name = day.historyProject?.customerName {
                Text(name)
                    .font(FreeDayFont.caption)
                    .foregroundStyle(FreeDayColor.muted)
                    .lineLimit(1)
            }
        }
        .frame(minHeight: 72, alignment: .topLeading)
    }

    private var dayHeading: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(formatters.weekday(day.date).uppercased())
                .font(FreeDayFont.label)
                .tracking(0.8)
                .foregroundStyle(FreeDayColor.muted)
            Text(formatters.dayNumber(day.date))
                .font(FreeDayFont.title)
                .foregroundStyle(FreeDayColor.ink)
                .monospacedDigit()
        }
    }

    private var weekendContent: some View {
        VStack(alignment: .leading, spacing: FreeDaySpacing.xxs) {
            if day.isToday {
                Text(String(localized: "Today", comment: "Today marker on a calendar card"))
                    .font(FreeDayFont.label)
                    .foregroundStyle(FreeDayColor.brand)
                    .textCase(.uppercase)
                    .tracking(1.2)
            }
            Text(formatters.weekday(day.date).uppercased())
                .font(FreeDayFont.label)
                .tracking(0.8)
                .foregroundStyle(FreeDayColor.muted)
            Text(formatters.dayNumber(day.date))
                .font(FreeDayFont.headline)
                .foregroundStyle(FreeDayColor.muted)
                .monospacedDigit()
            CalendarStatusBadge(kind: day.kind)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    }

    private var hint: String {
        if day.projectToOpen != nil {
            return String(localized: "Opens project details", comment: "Calendar booked or quoted day")
        }
        if day.canUseDay {
            return String(localized: "Use this free day", comment: "Calendar free day")
        }
        return String(localized: "Not a working day", comment: "Calendar weekend")
    }
}
