import SwiftUI

struct ProjectCard: View {
    let project: ProjectSnapshot
    let workingDates: [Date]
    let formatters: DateFormatters

    var body: some View {
        FreeDayCard {
            VStack(alignment: .leading, spacing: FreeDaySpacing.sm) {
                Text(project.projectName)
                    .font(FreeDayFont.headline)
                    .foregroundStyle(FreeDayColor.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(project.customerName)
                    .font(FreeDayFont.body)
                    .foregroundStyle(FreeDayColor.muted)
                    .fixedSize(horizontal: false, vertical: true)

                if let start = workingDates.first, let end = workingDates.last {
                    VStack(alignment: .leading, spacing: 2) {
                        FreeDaySectionHeader(title: String(localized: "Dates", comment: "Project card date heading"))
                        Text(formatters.range(start: start, end: end))
                            .font(FreeDayFont.caption)
                            .foregroundStyle(FreeDayColor.ink)
                    }
                }

                Text(durationLabel)
                    .font(FreeDayFont.caption)
                    .foregroundStyle(FreeDayColor.muted)

                if project.bufferInWorkingDays > 0 {
                    Text(bufferLabel)
                        .font(FreeDayFont.label)
                        .foregroundStyle(FreeDayColor.buffer)
                }

                ProjectStatusBadge(status: project.status)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var durationLabel: String {
        if project.durationInWorkingDays == 1 {
            String(localized: "1 day", comment: "Single-day duration on a card")
        } else {
            String(
                localized: "\(project.durationInWorkingDays) days",
                comment: "Project duration on a card"
            )
        }
    }

    private var bufferLabel: String {
        String(
            localized: "+\(project.bufferInWorkingDays) buffer",
            comment: "Secondary buffer note on a project card"
        )
    }

    private var accessibilityText: String {
        var parts = [project.projectName, project.customerName, durationLabel, project.status.title]
        if project.bufferInWorkingDays > 0 {
            parts.append(bufferLabel)
        }
        if let start = workingDates.first, let end = workingDates.last {
            parts.append(formatters.range(start: start, end: end))
        }
        return parts.joined(separator: ", ")
    }
}
