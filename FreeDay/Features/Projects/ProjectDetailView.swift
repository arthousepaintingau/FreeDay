import SwiftData
import SwiftUI

struct ProjectDetailView: View {
    @Environment(\.appEnvironment) private var environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var project: Project

    @State private var showEditor = false
    @State private var showReschedule = false
    @State private var showDeleteConfirm = false
    @State private var toast: String?

    var body: some View {
        let engine = environment.scheduling
        let formatters = DateFormatters(workingCalendar: environment.workingCalendar)
        let schedule = ProjectDetailDisplay.workingSchedule(
            startDate: project.startDate,
            durationInWorkingDays: project.durationInWorkingDays,
            engine: engine
        )

        ScrollView {
            VStack(alignment: .leading, spacing: FreeDaySpacing.lg) {
                VStack(alignment: .leading, spacing: FreeDaySpacing.sm) {
                    ProjectStatusBadge(status: project.status)
                    Text(project.projectName)
                        .font(FreeDayFont.display)
                        .foregroundStyle(FreeDayColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(project.customerName)
                        .font(FreeDayFont.title)
                        .foregroundStyle(FreeDayColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                FreeDayLabeledValue(
                    title: String(localized: "Duration", comment: "Project detail"),
                    value: FreeDayDurationCopy.days(project.durationInWorkingDays)
                )

                if let start = schedule.first, let end = schedule.last {
                    FreeDayLabeledValue(
                        title: String(localized: "Dates", comment: "Project detail date range"),
                        value: formatters.fullRange(start: start, end: end),
                        prominent: true
                    )
                } else if let start = project.startDate {
                    FreeDayLabeledValue(
                        title: String(localized: "Start date", comment: "Project detail"),
                        value: formatters.fullDate(start),
                        prominent: true
                    )
                }

                if !schedule.isEmpty {
                    FreeDayCard {
                        SchedulePreview(dates: schedule, formatters: formatters)
                    }
                }

                if project.bufferInWorkingDays > 0 {
                    FreeDayLabeledValue(
                        title: String(localized: "Buffer", comment: "Project detail buffer"),
                        value: bufferDetail
                    )
                }

                if let phone = project.phoneNumber {
                    FreeDayLabeledValue(title: String(localized: "Phone", comment: "Project detail"), value: phone)
                }
                if let address = project.address {
                    FreeDayLabeledValue(title: String(localized: "Address", comment: "Project detail"), value: address)
                }
                if let notes = project.notes {
                    FreeDayLabeledValue(title: String(localized: "Notes", comment: "Project detail"), value: notes)
                }

                PrimaryButton(
                    title: String(localized: "Edit", comment: "Edit project"),
                    systemImage: "pencil",
                    action: { showEditor = true }
                )

                if project.snapshot.canReschedule {
                    SecondaryButton(
                        title: String(localized: "Reschedule", comment: "Open reschedule"),
                        action: { showReschedule = true }
                    )
                    .accessibilityIdentifier("project-reschedule")
                    SecondaryButton(
                        title: String(localized: "Mark Completed", comment: "Complete project"),
                        action: complete
                    )
                } else if project.status == .booked {
                    SecondaryButton(
                        title: String(localized: "Mark Completed", comment: "Complete project"),
                        action: complete
                    )
                }

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Text(String(localized: "Delete", comment: "Delete project"))
                        .font(FreeDayFont.headline)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 52)
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityHint(String(localized: "Deletes this project from the device", comment: "Delete hint"))
            }
            .padding(.horizontal, FreeDaySpacing.screen)
            .padding(.top, FreeDaySpacing.lg)
            .padding(.bottom, 96)
            .freeDayContentWidth()
        }
        .background(FreeDayColor.canvas.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEditor) {
            ProjectEditorView(mode: .edit(project))
        }
        .sheet(isPresented: $showReschedule) {
            RescheduleView(project: project) { message in
                if let message {
                    toast = message
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(2.2))
                        if toast == message {
                            toast = nil
                        }
                    }
                }
            }
        }
        .alert(
            String(localized: "Delete this project?", comment: "Delete confirmation"),
            isPresented: $showDeleteConfirm
        ) {
            Button(String(localized: "Delete", comment: "Confirm delete"), role: .destructive) {
                modelContext.delete(project)
                try? modelContext.save()
                dismiss()
            }
            Button(String(localized: "Cancel", comment: "Cancel delete"), role: .cancel) {}
        }
        .overlay(alignment: .top) {
            if let toast {
                ToastBanner(message: toast)
                    .padding(.top, FreeDaySpacing.xs)
                    .allowsHitTesting(false)
            }
        }
    }

    private var bufferDetail: String {
        if project.bufferInWorkingDays == 1 {
            String(localized: "1 day after job", comment: "Single buffer day on project details")
        } else {
            String(
                localized: "\(project.bufferInWorkingDays) days after job",
                comment: "Buffer days on project details"
            )
        }
    }

    private func complete() {
        project.markCompleted()
        try? modelContext.save()
        FreeDayHaptics.success()
        toast = PersonalityCopy.jobDone
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            toast = nil
        }
    }
}

/// Project Details date range. Uses the same working-day snap as the scheduler; does not rewrite storage.
enum ProjectDetailDisplay {
    static func workingSchedule(
        startDate: Date?,
        durationInWorkingDays: Int,
        engine: SchedulingEngine
    ) -> [Date] {
        guard let startDate else { return [] }
        return engine.workingDates(start: startDate, duration: durationInWorkingDays)
    }
}
