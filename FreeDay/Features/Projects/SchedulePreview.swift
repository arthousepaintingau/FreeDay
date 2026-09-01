import SwiftUI

struct SchedulePreview: View {
    let dates: [Date]
    let formatters: DateFormatters

    var body: some View {
        VStack(alignment: .leading, spacing: FreeDaySpacing.xs) {
            FreeDaySectionHeader(title: String(localized: "Schedule", comment: "Working-day breakdown heading"))

            ForEach(Array(dates.enumerated()), id: \.offset) { index, date in
                HStack {
                    Text(formatters.weekdayFull(date))
                        .foregroundStyle(FreeDayColor.ink)
                    Spacer()
                    Text(
                        String(
                            localized: "Day \(index + 1)",
                            comment: "Nth working day in a project schedule"
                        )
                    )
                    .foregroundStyle(FreeDayColor.muted)
                }
                .font(FreeDayFont.body)
                .accessibilityLabel(
                    "\(formatters.weekdayFull(date)), \(String(localized: "Day \(index + 1)", comment: "Nth working day in a project schedule"))"
                )
            }
        }
    }
}
