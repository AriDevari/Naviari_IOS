//
//  CourseMarkEditView.swift
//  Naviari_IOS
//
//  Edit and add form for course marks only.
//  Start line and finish line forms live in CourseLineEditView (S2).
//

import SwiftUI
import UIKit

// MARK: - Mode enum

enum CourseMarkEditMode {
    case editMark(CourseMarkItem, courseId: String)
    case addMark(courseId: String, afterSequence: Int)
}

// MARK: - Save outcome

enum CourseItemSaveOutcome {
    case saved(activeItemId: String)
    case removed
}

private enum MarkEditScrollTarget: String, Hashable {
    case identity
    case position
}

// MARK: - CourseMarkEditView

struct CourseMarkEditView: View {
    let mode: CourseMarkEditMode
    let accessToken: String
    var onSaved: (CourseItemSaveOutcome) -> Void = { _ in }

    // MARK: Form state
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var selectedStatus: CourseMarkFormStatus = .preliminary
    @State private var selectedRounding: CourseMarkFormRounding = .port
    @State private var lat: DMSCoordinate = DMSCoordinate()
    @State private var lon: DMSCoordinate = DMSCoordinate(hemisphere: "E")
    @State private var latEntryState: DMSFieldEntryState = DMSFieldEntryState()
    @State private var lonEntryState: DMSFieldEntryState = DMSFieldEntryState()

    // MARK: UI state
    @State private var isSaving = false
    @State private var saveError: String? = nil
    @State private var showRemoveConfirm = false
    @State private var showInfoSheet = false
    @State private var isKeyboardVisible = false

    @FocusState private var focusedField: MarkField?
    @EnvironmentObject private var locationManager: LocationDataManager

    private let raceService = RaceService()

    // MARK: - Computed helpers

    private var isEditMode: Bool {
        if case .editMark = mode { return true }
        return false
    }

    private var titleKey: LocalizedStringKey {
        isEditMode ? "course_item_edit_mark_title" : "course_item_add_mark_title"
    }

    private var isSaveDisabled: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving
    }

    private var currentCourseId: String {
        switch mode {
        case let .editMark(_, courseId): return courseId
        case let .addMark(courseId, _): return courseId
        }
    }

    private var existingMarkId: String? {
        if case let .editMark(item, _) = mode { return item.id }
        return nil
    }

    private var existingSequence: Int {
        switch mode {
        case let .editMark(item, _): return item.sequence
        case let .addMark(_, afterSequence): return afterSequence
        }
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
                            .id(MarkEditScrollTarget.identity)
                        statusSection
                        roundingSection
                        positionSection(
                            onLatitudeEditingBegan: { scrollToTarget(.position, using: proxy) },
                            onLongitudeEditingBegan: { scrollToTarget(.position, using: proxy) }
                        )
                        .id(MarkEditScrollTarget.position)

                        if isEditMode {
                            removeButton
                                .padding(.top, 8)
                        }

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
        .alert(
            Text(NSLocalizedString("course_edit_remove_confirm_title", comment: "")),
            isPresented: $showRemoveConfirm
        ) {
            Button(NSLocalizedString("course_edit_remove_confirm_action", comment: ""), role: .destructive) {
                Task { await performRemove() }
            }
            Button(NSLocalizedString("actions_cancel", comment: ""), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("course_edit_remove_confirm_message", comment: ""))
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

    private var roundingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("course_edit_section_rounding", comment: ""))
                .font(AppFont.fixed(16, weight: .bold))
                .foregroundStyle(Theme.Colors.textPrimary)

            HStack(spacing: 0) {
                ForEach(CourseMarkFormRounding.allCases, id: \.self) { rounding in
                    let isSelected = selectedRounding == rounding
                    Button(action: { selectedRounding = rounding }) {
                        Text(rounding.label)
                            .font(AppFont.fixed(15, weight: .semibold))
                            .foregroundStyle(isSelected ? .white : Theme.Colors.textPrimary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(isSelected ? Theme.Colors.brandNavy : Color.clear)
                            .animation(.easeInOut(duration: 0.15), value: selectedRounding)
                    }
                    .buttonStyle(.plain)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.FormField.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.FormField.cornerRadius, style: .continuous)
                    .stroke(Theme.FormField.borderDefault, lineWidth: 1)
            )
            .accessibilityIdentifier("course_edit_rounding_control")
        }
    }

    private func positionSection(
        onLatitudeEditingBegan: @escaping () -> Void = {},
        onLongitudeEditingBegan: @escaping () -> Void = {}
    ) -> some View {
        CoursePositionSection(
            sectionTitle: NSLocalizedString("course_edit_section_position", comment: ""),
            sectionSubtitle: NSLocalizedString("course_edit_position_subtitle", comment: ""),
            lat: $lat,
            lon: $lon,
            onSetGPSPosition: handleUseCurrentGPSPosition,
            onLatitudeEditingBegan: onLatitudeEditingBegan,
            onLongitudeEditingBegan: onLongitudeEditingBegan,
            onLatitudeEntryStateChanged: { latEntryState = $0 },
            onLongitudeEntryStateChanged: { lonEntryState = $0 },
            accessibilityPrefix: "mark",
            gpsButtonAccessibilityId: "course_edit_gps_mark"
        )
    }

    private var removeButton: some View {
        Button(action: { showRemoveConfirm = true }) {
            ZStack {
                Text(NSLocalizedString("course_edit_remove_button", comment: ""))
                    .font(AppFont.fixed(17, weight: .semibold))
                    .foregroundStyle(Theme.RaceManager.primaryColor)
                    .frame(maxWidth: .infinity, alignment: .center)

                HStack {
                    Spacer()
                    Image(systemName: "trash")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Theme.RaceManager.primaryColor)
                        .padding(.trailing, 20)
                }
            }
            .frame(maxWidth: .infinity, minHeight: Theme.Sizing.secondaryButtonHeight)
        }
        .buttonStyle(.plain)
        .overlay(
            Capsule()
                .stroke(Theme.RaceManager.primaryColor, lineWidth: 1.5)
        )
        .accessibilityIdentifier("course_edit_remove_button")
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
        field: MarkField
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
        switch mode {
        case let .editMark(item, _):
            name = item.name ?? ""
            description = item.description ?? ""
            selectedStatus = CourseMarkFormStatus(from: item.status)
            selectedRounding = CourseMarkFormRounding(from: item.rounding_side)
            if let markLat = item.mark_lat, let markLon = item.mark_lon {
                lat = DMSCoordinate(from: markLat, isLat: true)
                lon = DMSCoordinate(from: markLon, isLat: false)
            }
        case .addMark:
            // Auto-focus name in add mode
            focusedField = .name
        }
    }

    private func performSave() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        if let coordinateError = validateCoordinates() {
            saveError = coordinateError
            return
        }

        isSaving = true
        saveError = nil
        defer { isSaving = false }

        do {
            switch mode {
            case let .editMark(item, _):
                let payload = CourseMarkWritePayload(
                    id: item.id,
                    name: trimmedName,
                    description: normalizedOptional(description),
                    roundingSide: selectedRounding.rawValue,
                    type: item.type,
                    status: selectedStatus.rawValue,
                    mark: CoordinatePoint(lat: lat.toDecimal(), lon: lon.toDecimal()),
                    updatedBy: "ios-course-edit"
                )
                let savedMark = try await raceService.updateCourseMark(payload, accessToken: accessToken)
                onSaved(.saved(activeItemId: savedMark.id))

            case let .addMark(courseId, afterSequence):
                let payload = CourseMarkInsertPayload(
                    sequence: afterSequence,
                    name: trimmedName,
                    description: normalizedOptional(description),
                    roundingSide: selectedRounding.rawValue,
                    type: "race_point",
                    status: selectedStatus.rawValue,
                    mark: CoordinatePoint(lat: lat.toDecimal(), lon: lon.toDecimal())
                )
                let savedMark = try await raceService.insertCourseMark(courseId: courseId, payload: payload, accessToken: accessToken)
                onSaved(.saved(activeItemId: savedMark.id))
            }
        } catch {
            saveError = error.localizedDescription.isEmpty
                ? NSLocalizedString("course_edit_save_error", comment: "")
                : error.localizedDescription
        }
    }

    private func performRemove() async {
        guard let markId = existingMarkId else { return }

        isSaving = true
        saveError = nil
        defer { isSaving = false }

        do {
            try await raceService.deleteCourseMark(id: markId, accessToken: accessToken)
            onSaved(.removed)
        } catch {
            saveError = error.localizedDescription.isEmpty
                ? NSLocalizedString("course_edit_remove_error", comment: "")
                : error.localizedDescription
        }
    }

    private func dismissKeyboard() {
        focusedField = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func handleUseCurrentGPSPosition() {
        dismissKeyboard()
        locationManager.start()

        guard locationAuthorizationIsValid else {
            saveError = NSLocalizedString("set_position_error_location_permission_required", comment: "")
            return
        }

        guard let coordinate = locationManager.latestLocation?.coordinate else {
            saveError = NSLocalizedString("set_position_error_location_unavailable", comment: "")
            return
        }

        lat = DMSCoordinate(from: coordinate.latitude, isLat: true)
        lon = DMSCoordinate(from: coordinate.longitude, isLat: false)
        saveError = nil
    }

    private var locationAuthorizationIsValid: Bool {
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return true
        default:
            return false
        }
    }

    private func validateCoordinates() -> String? {
        if !latEntryState.isComplete || !lonEntryState.isComplete {
            return NSLocalizedString("course_edit_coordinate_incomplete_error", comment: "")
        }
        if !lat.isValid(isLatitude: true) {
            return NSLocalizedString("course_edit_coordinate_lat_invalid_error", comment: "")
        }
        if !lon.isValid(isLatitude: false) {
            return NSLocalizedString("course_edit_coordinate_lon_invalid_error", comment: "")
        }
        return nil
    }

    private func scrollToTarget(_ target: MarkEditScrollTarget, using proxy: ScrollViewProxy) {
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

private enum MarkField: Hashable {
    case name
    case descriptionField
}

enum CourseMarkFormStatus: String, CaseIterable {
    case preliminary
    case final_ = "final"

    var label: String {
        switch self {
        case .preliminary: return NSLocalizedString("course_definition_status_preliminary", comment: "")
        case .final_: return NSLocalizedString("course_definition_status_final", comment: "")
        }
    }

    var selectedColor: Color {
        switch self {
        case .preliminary: return Theme.RaceManager.primaryColor
        case .final_: return Theme.Colors.brandBlue
        }
    }

    init(from rawStatus: String?) {
        let normalized = rawStatus?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "final": self = .final_
        default: self = .preliminary
        }
    }
}

enum CourseMarkFormRounding: String, CaseIterable {
    case port
    case starboard

    var label: String {
        switch self {
        case .port: return NSLocalizedString("course_rounding_port", comment: "")
        case .starboard: return NSLocalizedString("course_rounding_starboard", comment: "")
        }
    }

    init(from rawValue: String?) {
        let normalized = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized == "starboard" {
            self = .starboard
        } else {
            self = .port
        }
    }
}

// MARK: - Write payload types (used by RaceService extensions)

struct CourseMarkWritePayload: Encodable {
    let id: String
    let name: String
    let description: String?
    let roundingSide: String?
    let type: String?
    let status: String
    let mark: CoordinatePoint
    let updatedBy: String?
}

struct CourseMarkInsertPayload: Encodable {
    let sequence: Int
    let name: String
    let description: String?
    let roundingSide: String?
    let type: String?
    let status: String
    let mark: CoordinatePoint
}
