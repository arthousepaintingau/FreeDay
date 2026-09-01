import SwiftData
import SwiftUI

struct ProjectEditorView: View {
    enum Mode {
        case create(ProjectPrefill)
        case edit(Project)
    }

    @Environment(\.appEnvironment) private var environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var projects: [Project]

    let mode: Mode
    var onSaved: (String?) -> Void

    @State private var draft: ProjectDraft
    @State private var hasStartDate: Bool
    @State private var startDateValue: Date
    @State private var showOptional = false
    @State private var validationMessage: String?
    @State private var conflict: FreeSlot?
    @State private var showConflict = false

    init(mode: Mode, onSaved: @escaping (String?) -> Void = { _ in }) {
        self.mode = mode
        self.onSaved = onSaved
        switch mode {
        case .create(let prefill):
            _draft = State(
                initialValue: ProjectDraft(
                    projectName: prefill.projectName,
                    customerName: prefill.customerName,
                    status: prefill.status,
                    startDate: prefill.startDate,
                    durationInWorkingDays: prefill.durationInWorkingDays
                )
            )
            _hasStartDate = State(initialValue: prefill.startDate != nil || prefill.status == .booked)
            _startDateValue = State(initialValue: prefill.startDate ?? .now)
        case .edit(let project):
            let existing = project.draft
            _draft = State(initialValue: existing)
            _hasStartDate = State(initialValue: existing.startDate != nil || existing.status == .booked)
            _startDateValue = State(initialValue: existing.startDate ?? .now)
            _showOptional = State(
                initialValue: !existing.phoneNumber.isEmpty || !existing.address.isEmpty || !existing.notes.isEmpty
            )
        }
    }

    private var navigationTitle: String {
        switch mode {
        case .create: String(localized: "Add Project", comment: "Add project title")
        case .edit: String(localized: "Edit Project", comment: "Edit project title")
        }
    }

    private var showFitMessage: Bool {
        if case .create(let prefill) = mode { return prefill.showFitMessage }
        return false
    }

    var body: some View {
        let engine = environment.scheduling
        let formatters = DateFormatters(workingCalendar: environment.workingCalendar)
        let resolvedStart = hasStartDate ? startDateValue : nil
        let schedule = resolvedStart.map { engine.workingDates(start: $0, duration: draft.durationInWorkingDays) } ?? []

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FreeDaySpacing.lg) {
                    if showFitMessage {
                        PersonalityLine(text: PersonalityCopy.perfectFit)
                    }

                    FreeDayCard {
                        VStack(alignment: .leading, spacing: FreeDaySpacing.md) {
                            FreeDayField(
                                title: String(localized: "Project name", comment: "Project field"),
                                hint: String(localized: "Interior painting", comment: "Project name placeholder"),
                                isRequired: true,
                                text: $draft.projectName,
                                submitLabel: .next
                            )

                            FreeDayField(
                                title: String(localized: "Customer name", comment: "Project field"),
                                hint: String(localized: "Smith House", comment: "Customer name placeholder"),
                                isRequired: true,
                                text: $draft.customerName,
                                textContentType: .organizationName,
                                submitLabel: .done
                            )
                        }
                    }

                    statusPicker

                    FreeDayCard {
                        VStack(alignment: .leading, spacing: FreeDaySpacing.sm) {
                            FreeDaySectionHeader(title: String(localized: "Project duration", comment: "Duration stepper heading"))
                            DayStepper(days: $draft.durationInWorkingDays, unitPlacement: .value)
                        }
                    }

                    FreeDayCard(padding: FreeDaySpacing.md) {
                        VStack(alignment: .leading, spacing: FreeDaySpacing.sm) {
                            FreeDaySectionHeader(title: String(localized: "Buffer after job", comment: "Buffer stepper heading"))
                            DayStepper(
                                days: $draft.bufferInWorkingDays,
                                range: 0...10,
                                unitPlacement: .value,
                                decreaseAccessibilityLabel: String(localized: "Decrease buffer days", comment: "Buffer stepper"),
                                increaseAccessibilityLabel: String(localized: "Increase buffer days", comment: "Buffer stepper"),
                                valueAccessibilityLabel: { count in
                                    String(localized: "\(count) buffer days", comment: "Buffer value")
                                }
                            )
                            Text(String(localized: "Reserved time after the job.", comment: "Buffer helper"))
                                .font(FreeDayFont.caption)
                                .foregroundStyle(FreeDayColor.muted)
                        }
                    }
                    .accessibilityIdentifier("project-buffer")

                    startDateCard(schedule: schedule, formatters: formatters)

                    optionalFields
                }
                .padding(.horizontal, FreeDaySpacing.screen)
                .padding(.vertical, FreeDaySpacing.lg)
                .freeDayContentWidth()
            }
            .scrollDismissesKeyboard(.interactively)
            .background(FreeDayColor.canvas.ignoresSafeArea())
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel", comment: "Dismiss project editor")) {
                        dismiss()
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(String(localized: "Done", comment: "Dismiss keyboard")) {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: FreeDaySpacing.sm) {
                    if let validationMessage {
                        Text(validationMessage)
                            .font(FreeDayFont.caption)
                            .foregroundStyle(FreeDayColor.booked)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityAddTraits(.updatesFrequently)
                    }
                    PrimaryButton(
                        title: String(localized: "Save Project", comment: "Save project"),
                        action: save
                    )
                }
                .padding(.horizontal, FreeDaySpacing.screen)
                .padding(.vertical, FreeDaySpacing.xs)
                .background(FreeDayColor.canvas.opacity(0.96))
                .freeDayContentWidth()
            }
            .onChange(of: draft.status) { _, newStatus in
                if newStatus == .booked {
                    hasStartDate = true
                }
            }
            .alert(
                PersonalityCopy.notEnoughDays,
                isPresented: $showConflict
            ) {
                if let conflict {
                    Button(String(localized: "Use this slot", comment: "Apply suggested free slot")) {
                        startDateValue = conflict.start
                        hasStartDate = true
                    }
                    Button(String(localized: "Choose another", comment: "Dismiss conflict"), role: .cancel) {}
                } else {
                    Button(String(localized: "OK", comment: "Dismiss conflict"), role: .cancel) {}
                }
            } message: {
                if let conflict {
                    Text(
                        String(
                            localized: "Next free slot: \(formatters.range(start: conflict.start, end: conflict.end))",
                            comment: "Suggested slot after a booking conflict"
                        )
                    )
                } else {
                    Text(String(localized: "No free slot found in the next year.", comment: "No suggested slot"))
                }
            }
        }
    }

    private var statusPicker: some View {
        FreeDayCard {
            VStack(alignment: .leading, spacing: FreeDaySpacing.sm) {
                FreeDaySectionHeader(title: String(localized: "Status", comment: "Project field"))
                Picker(
                    String(localized: "Status", comment: "Project field"),
                    selection: $draft.status
                ) {
                    ForEach(ProjectStatus.allCases) { status in
                        Text(status.title).tag(status)
                    }
                }
                .pickerStyle(.segmented)
                .tint(FreeDayColor.brand)
                ProjectStatusBadge(status: draft.status)
            }
        }
    }

    @ViewBuilder
    private func startDateCard(schedule: [Date], formatters: DateFormatters) -> some View {
        FreeDayCard {
            if draft.status == .booked {
                VStack(alignment: .leading, spacing: FreeDaySpacing.xs) {
                    FreeDaySectionHeader(title: String(localized: "Start date", comment: "Required start date"))
                    Text(String(localized: "This job is scheduled.", comment: "Booked start date helper"))
                        .font(FreeDayFont.caption)
                        .foregroundStyle(FreeDayColor.ink)
                    Text(formatters.fullDate(startDateValue))
                        .font(FreeDayFont.title)
                        .foregroundStyle(FreeDayColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    DatePicker(
                        String(localized: "Start date", comment: "Start date picker"),
                        selection: $startDateValue,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(FreeDayColor.brand)
                    .padding(.top, FreeDaySpacing.xxs)
                }
            } else {
                Toggle(
                    String(localized: "Start date", comment: "Optional start date toggle"),
                    isOn: $hasStartDate
                )
                .font(FreeDayFont.headline)
                .foregroundStyle(FreeDayColor.ink)
                .tint(FreeDayColor.brand)

                if hasStartDate {
                    DatePicker(
                        String(localized: "Start date", comment: "Start date picker"),
                        selection: $startDateValue,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(FreeDayColor.brand)
                    .padding(.top, FreeDaySpacing.xs)
                }
            }

            if hasStartDate, !schedule.isEmpty {
                SchedulePreview(dates: schedule, formatters: formatters)
                    .padding(.top, FreeDaySpacing.sm)
            }
        }
    }

    private var optionalFields: some View {
        VStack(alignment: .leading, spacing: FreeDaySpacing.sm) {
            Button {
                showOptional.toggle()
            } label: {
                HStack {
                    Text(String(localized: "Phone, address, notes", comment: "Optional fields disclosure"))
                    Spacer()
                    Text(String(localized: "Optional", comment: "Optional fields marker"))
                        .font(FreeDayFont.label)
                    Image(systemName: showOptional ? "chevron.up" : "chevron.down")
                }
                .font(FreeDayFont.caption)
                .foregroundStyle(FreeDayColor.muted)
                .frame(minHeight: FreeDaySpacing.touch)
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityHint(String(localized: "Shows optional contact fields", comment: "Optional fields hint"))

            if showOptional {
                FreeDayCard {
                    VStack(alignment: .leading, spacing: FreeDaySpacing.md) {
                        FreeDayField(
                            title: String(localized: "Phone", comment: "Optional phone"),
                            text: $draft.phoneNumber,
                            keyboardType: .phonePad,
                            textContentType: .telephoneNumber
                        )

                        FreeDayField(
                            title: String(localized: "Address", comment: "Optional address"),
                            text: $draft.address,
                            textContentType: .fullStreetAddress
                        )

                        FreeDayField(
                            title: String(localized: "Notes", comment: "Optional notes"),
                            text: $draft.notes,
                            axis: .vertical,
                            submitLabel: .done
                        )
                    }
                }
            }
        }
    }

    private func save() {
        draft.startDate = hasStartDate ? startDateValue : nil
        if let message = ProjectValidator.firstMessage(in: draft) {
            validationMessage = message
            FreeDayHaptics.warning()
            return
        }
        validationMessage = nil

        let excludingID: UUID? = {
            if case .edit(let project) = mode { return project.id }
            return nil
        }()

        if draft.status == .booked, let start = draft.startDate {
            switch environment.scheduling.validateBooking(
                start: start,
                duration: draft.durationInWorkingDays,
                projects: projects.map(\.snapshot),
                excluding: excludingID,
                buffer: draft.bufferInWorkingDays
            ) {
            case .valid:
                break
            case .conflict(let suggested):
                conflict = suggested
                showConflict = true
                FreeDayHaptics.warning()
                return
            }
        }

        switch mode {
        case .create:
            let trimmed = draft.trimmed()
            let project = Project(
                projectName: trimmed.projectName,
                customerName: trimmed.customerName,
                phoneNumber: trimmed.phoneNumber.isEmpty ? nil : trimmed.phoneNumber,
                address: trimmed.address.isEmpty ? nil : trimmed.address,
                notes: trimmed.notes.isEmpty ? nil : trimmed.notes,
                status: trimmed.status,
                startDate: trimmed.startDate,
                durationInWorkingDays: trimmed.durationInWorkingDays,
                bufferInWorkingDays: trimmed.bufferInWorkingDays
            )
            if trimmed.status == .completed {
                project.markCompleted()
            }
            modelContext.insert(project)
            try? modelContext.save()
            if trimmed.status == .booked {
                FreeDayHaptics.success()
            } else {
                FreeDayHaptics.light()
            }
            onSaved(
                trimmed.bufferInWorkingDays > 0
                    ? PersonalityCopy.breathingRoom
                    : PersonalityCopy.thingsGettingBusy
            )
        case .edit(let project):
            project.apply(draft)
            try? modelContext.save()
            FreeDayHaptics.light()
            onSaved(nil)
        }
        dismiss()
    }
}

/// Keeps the existing add-project call site name.
struct AddProjectView: View {
    let prefill: ProjectPrefill
    var onSaved: (String?) -> Void

    var body: some View {
        ProjectEditorView(mode: .create(prefill), onSaved: onSaved)
    }
}
