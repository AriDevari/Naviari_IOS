//
//  CourseLineEditView.swift
//  Naviari_IOS
//
//  Edit form for start lines and finish lines.
//  Intentionally a separate file from CourseMarkEditView so both can evolve independently.
//  Reuses CoursePositionSection (and its embedded CourseDMSField) from S1.
//

import SwiftUI
import UIKit

// MARK: - Mode enum

enum CourseLineEditMode {
    case editStartLine(CourseLine, courseId: String)
    case editFinishLine(CourseLine, courseId: String)
}

private enum LineEditScrollTarget: String, Hashable {
    case identity
    case leftEnd
    case rightEnd
}

// MARK: - CourseLineEditView

struct CourseLineEditView: View {
    let mode: CourseLineEditMode
    let accessToken: String
    let buoyOptions: [BuoyRecord]
    var onSaved: (CourseItemSaveOutcome) -> Void = { _ in }

    // MARK: Form state
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var selectedStatus: CourseMarkFormStatus = .preliminary
    @StateObject private var leftCoordinateEditor = CourseCoordinateEditorController()
    @StateObject private var rightCoordinateEditor = CourseCoordinateEditorController()

    // MARK: UI state
    @State private var isSaving = false
    @State private var saveError: String? = nil
    @State private var showInfoSheet = false
    @State private var isKeyboardVisible = false

    @FocusState private var focusedField: LineField?
    @EnvironmentObject private var locationManager: LocationDataManager

    private let raceService = RaceService()

    // MARK: - Computed helpers

    private var isStartLine: Bool {
        if case .editStartLine = mode { return true }
        return false
    }

    private var titleKey: LocalizedStringKey {
        isStartLine ? "course_item_edit_start_line_title" : "course_item_edit_finish_line_title"
    }

    private var currentLine: CourseLine {
        switch mode {
        case let .editStartLine(line, _): return line
        case let .editFinishLine(line, _): return line
        }
    }

    private var isSaveDisabled: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving
    }

    // MARK: - Body

    var body: some View {
        ScreenContainer(
            showBack: true,
            title: Text(titleKey),
            trailing: AnyView(
                Button(action: { showInfoSheet = true }) {
                    Image(systemName: "info.circle")
                        .font(Theme.Typography.iconLarge)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            )
        ) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        identitySection
                            .id(LineEditScrollTarget.identity)
                        statusSection
                        leftEndSection(
                            onLatitudeEditingBegan: { scrollToTarget(.leftEnd, using: proxy) },
                            onLongitudeEditingBegan: { scrollToTarget(.leftEnd, using: proxy) }
                        )
                        .id(LineEditScrollTarget.leftEnd)
                        rightEndSection(
                            onLatitudeEditingBegan: { scrollToTarget(.rightEnd, using: proxy) },
                            onLongitudeEditingBegan: { scrollToTarget(.rightEnd, using: proxy) }
                        )
                        .id(LineEditScrollTarget.rightEnd)

                        saveBar
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: focusedField) { _, newValue in
                    guard newValue != nil else { return }
                    scrollToTarget(.identity, using: proxy)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if isKeyboardVisible {
                keyboardCloseBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showInfoSheet) {
            infoSheet
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                isKeyboardVisible = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                isKeyboardVisible = false
            }
        }
        .onAppear { prefillFromMode() }
    }

    // MARK: - Section views

    private var identitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("course_edit_section_identity", comment: ""))
                .font(AppFont.fixed(16, weight: .bold))
                .foregroundStyle(Theme.Colors.textPrimary)

            formTextField(
                label: NSLocalizedString("course_edit_name_label", comment: ""),
                text: $name,
                placeholder: NSLocalizedString("course_edit_name_placeholder", comment: ""),
                field: .name
            )
            .accessibilityIdentifier("course_edit_name_field")

            formTextField(
                label: NSLocalizedString("course_edit_description_label", comment: ""),
                text: $description,
                placeholder: NSLocalizedString("course_edit_description_placeholder", comment: ""),
                field: .descriptionField
            )
            .accessibilityIdentifier("course_edit_description_field")
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("course_edit_section_status", comment: ""))
                .font(AppFont.fixed(16, weight: .bold))
                .foregroundStyle(Theme.Colors.textPrimary)

            HStack(spacing: 0) {
                ForEach(CourseMarkFormStatus.allCases, id: \.self) { status in
                    let isSelected = selectedStatus == status
                    Button(action: { selectedStatus = status }) {
                        HStack(spacing: 6) {
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            Text(status.label)
                                .font(AppFont.fixed(15, weight: .semibold))
                        }
                        .foregroundStyle(isSelected ? .white : Theme.Colors.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(isSelected ? status.selectedColor : Color.clear)
                        .animation(.easeInOut(duration: 0.15), value: selectedStatus)
                    }
                    .buttonStyle(.plain)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.FormField.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.FormField.cornerRadius, style: .continuous)
                    .stroke(Theme.FormField.borderDefault, lineWidth: 1)
            )
            .accessibilityIdentifier("course_edit_status_control")
        }
    }

    private func leftEndSection(
        onLatitudeEditingBegan: @escaping () -> Void = {},
        onLongitudeEditingBegan: @escaping () -> Void = {}
    ) -> some View {
        CourseCoordinateEditorSection(
            sectionTitle: NSLocalizedString("course_edit_section_left_end", comment: ""),
            sectionSubtitle: NSLocalizedString("course_edit_left_end_subtitle", comment: ""),
            controller: leftCoordinateEditor,
            errorMessage: $saveError,
            buoyOptions: buoyOptions,
            onLatitudeEditingBegan: onLatitudeEditingBegan,
            onLongitudeEditingBegan: onLongitudeEditingBegan,
            accessibilityPrefix: "left",
            gpsButtonAccessibilityId: "course_edit_gps_left"
        )
    }

    private func rightEndSection(
        onLatitudeEditingBegan: @escaping () -> Void = {},
        onLongitudeEditingBegan: @escaping () -> Void = {}
    ) -> some View {
        CourseCoordinateEditorSection(
            sectionTitle: NSLocalizedString("course_edit_section_right_end", comment: ""),
            sectionSubtitle: NSLocalizedString("course_edit_right_end_subtitle", comment: ""),
            controller: rightCoordinateEditor,
            errorMessage: $saveError,
            buoyOptions: buoyOptions,
            onLatitudeEditingBegan: onLatitudeEditingBegan,
            onLongitudeEditingBegan: onLongitudeEditingBegan,
            accessibilityPrefix: "right",
            gpsButtonAccessibilityId: "course_edit_gps_right"
        )
    }

    private var saveBar: some View {
        VStack(spacing: 12) {
            if let saveError {
                Text(saveError)
                    .font(AppFont.fixed(13, weight: .medium))
                    .foregroundStyle(Theme.Colors.error)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("course_edit_save_error_label")
            }

            Button(action: { Task { await performSave() } }) {
                ZStack {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(NSLocalizedString("course_edit_save_button", comment: ""))
                            .font(AppFont.fixed(17, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .center)

                        HStack {
                            Spacer()
                            Image(systemName: "checkmark")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.trailing, 20)
                        }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: Theme.Sizing.primaryButtonHeight)
                .background(
                    isSaveDisabled
                        ? Theme.RaceManager.primaryColor.opacity(0.4)
                        : Theme.RaceManager.primaryColor
                )
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(0.04), radius: 14, x: 0, y: -4)
            }
            .buttonStyle(.plain)
            .disabled(isSaveDisabled)
            .accessibilityIdentifier("course_edit_save_button")
        }
        .padding(.top, 8)
    }

    private var keyboardCloseBar: some View {
        HStack {
            Spacer()
            Button("close_button") {
                dismissKeyboard()
            }
            .font(AppUI.buttonFont)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.Colors.surfacePrimary)
        .overlay(alignment: .top) {
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Theme.FormField.borderDefault)
        }
    }

    @ViewBuilder
    private var infoSheet: some View {
        NavigationStack {
            ScrollView {
                Text(LocalizedStringKey("course_item_edit_info_body"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .navigationTitle(LocalizedStringKey("course_item_edit_info_title"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("close_button") { showInfoSheet = false }
                        .font(AppUI.buttonFont)
                }
            }
        }
        .presentationDetents([.fraction(0.4), .medium])
    }

    // MARK: - Form text field

    @ViewBuilder
    private func formTextField(
        label: String,
        text: Binding<String>,
        placeholder: String,
        field: LineField
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(AppFont.fixed(12, weight: .semibold))
                .foregroundStyle(Theme.Colors.textSecondary)

            TextField(placeholder, text: text)
                .font(AppFont.fixed(17, weight: .semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
                .focused($focusedField, equals: field)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Theme.FormField.background)
                .clipShape(RoundedRectangle(cornerRadius: Theme.FormField.cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.FormField.cornerRadius, style: .continuous)
                        .stroke(
                            focusedField == field ? Theme.FormField.borderFocused : Theme.FormField.borderDefault,
                            lineWidth: 1
                        )
                )
        }
    }

    // MARK: - Actions

    private func prefillFromMode() {
        let line = currentLine
        name = line.name ?? ""
        description = line.description ?? ""
        selectedStatus = CourseMarkFormStatus(from: line.status)

        if let leftLatVal = line.mark_left_lat, let leftLonVal = line.mark_left_lon {
            leftCoordinateEditor.prefill(coordinate: CoordinatePoint(lat: leftLatVal, lon: leftLonVal))
        } else {
            leftCoordinateEditor.prefill(coordinate: nil)
        }
        if let rightLatVal = line.mark_right_lat, let rightLonVal = line.mark_right_lon {
            rightCoordinateEditor.prefill(coordinate: CoordinatePoint(lat: rightLatVal, lon: rightLonVal))
        } else {
            rightCoordinateEditor.prefill(coordinate: nil)
        }
    }

    private func performSave() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let leftCoordinate: CoordinatePoint
        switch leftCoordinateEditor.resolvedCoordinate(locationManager: locationManager) {
        case let .success(resolvedCoordinate):
            leftCoordinate = resolvedCoordinate
        case let .failure(error):
            saveError = error
            return
        }

        let rightCoordinate: CoordinatePoint
        switch rightCoordinateEditor.resolvedCoordinate(locationManager: locationManager) {
        case let .success(resolvedCoordinate):
            rightCoordinate = resolvedCoordinate
        case let .failure(error):
            saveError = error
            return
        }

        isSaving = true
        saveError = nil
        defer { isSaving = false }

        do {
            let payload = CourseLineWritePayload(
                id: currentLine.id,
                name: trimmedName,
                description: normalizedOptional(description),
                status: selectedStatus.rawValue,
                markLeft: leftCoordinate,
                markRight: rightCoordinate,
                updatedBy: "ios-course-edit"
            )

            switch mode {
            case .editStartLine:
                try await raceService.updateStartLine(payload, accessToken: accessToken)
            case .editFinishLine:
                try await raceService.updateFinishLine(payload, accessToken: accessToken)
            }

            onSaved(.saved(activeItemId: currentLine.id))
        } catch {
            saveError = error.localizedDescription.isEmpty
                ? NSLocalizedString("course_edit_save_error", comment: "")
                : error.localizedDescription
        }
    }

    private func dismissKeyboard() {
        focusedField = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func scrollToTarget(_ target: LineEditScrollTarget, using proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 0.2)) {
                proxy.scrollTo(target, anchor: .center)
            }
        }
    }

    private func normalizedOptional(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// MARK: - Supporting types

private enum LineField: Hashable {
    case name
    case descriptionField
}

// MARK: - Write payload

struct CourseLineWritePayload: Encodable {
    let id: String
    let name: String
    let description: String?
    let status: String
    let markLeft: CoordinatePoint
    let markRight: CoordinatePoint
    let updatedBy: String?
}
