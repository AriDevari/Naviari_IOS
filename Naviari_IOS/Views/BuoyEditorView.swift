import SwiftUI
import UIKit

enum BuoyEditorMode: Identifiable {
    case add(raceId: String)
    case edit(BuoyRecord, focusPosition: Bool = false)

    var id: String {
        switch self {
        case let .add(raceId):
            return "add:\(raceId)"
        case let .edit(buoy, focusPosition):
            return "edit:\(buoy.id):\(focusPosition)"
        }
    }
}

enum BuoyEditorOutcome {
    case saved(BuoyRecord)
    case removed(id: String)
}

enum PendingBuoyManageAction {
    case present(BuoyEditorMode)
    case setPosition(BuoyRecord)
}

private enum BuoyEditorScrollTarget: String, Hashable {
    case identity
    case position
}

private enum BuoyEditorField: Hashable {
    case name
    case descriptionField
}

struct BuoyEditorView: View {
    let mode: BuoyEditorMode
    let storage: BuoyStorage
    var onSaved: (BuoyEditorOutcome) -> Void = { _ in }

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var lat: DMSCoordinate = DMSCoordinate()
    @State private var lon: DMSCoordinate = DMSCoordinate(hemisphere: "E")
    @State private var latEntryState: DMSFieldEntryState = DMSFieldEntryState()
    @State private var lonEntryState: DMSFieldEntryState = DMSFieldEntryState()
    @State private var saveError: String?
    @State private var isSaving = false
    @State private var showRemoveConfirm = false
    @State private var showInfoSheet = false
    @State private var isKeyboardVisible = false
    @State private var didRunInitialSetup = false

    @FocusState private var focusedField: BuoyEditorField?
    @EnvironmentObject private var locationManager: LocationDataManager

    private var isEditMode: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var titleKey: LocalizedStringKey {
        isEditMode ? "buoy_editor_edit_title" : "buoy_editor_add_title"
    }

    private var isSaveDisabled: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !hasCompleteCoordinates
            || coordinateValidationError != nil
            || isSaving
    }

    private var infoBodyKey: LocalizedStringKey {
        "buoy_editor_info_body"
    }

    private var hasCompleteCoordinates: Bool {
        latEntryState.isComplete && lonEntryState.isComplete
    }

    private var coordinateValidationError: String? {
        validateCoordinatesRequired()
    }

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
                            .id(BuoyEditorScrollTarget.identity)
                        positionSection(
                            onLatitudeEditingBegan: { scrollToTarget(.position, using: proxy) },
                            onLongitudeEditingBegan: { scrollToTarget(.position, using: proxy) }
                        )
                        .id(BuoyEditorScrollTarget.position)

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
                .onAppear {
                    guard !didRunInitialSetup else { return }
                    didRunInitialSetup = true
                    prefillFromMode()

                    if startsAtPosition {
                        scrollToTarget(.position, using: proxy)
                    }
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
        .alert(
            Text("buoy_delete_confirm_title"),
            isPresented: $showRemoveConfirm
        ) {
            Button("buoy_delete_button", role: .destructive) {
                performRemove()
            }
            Button("actions_cancel", role: .cancel) {}
        } message: {
            Text("buoy_delete_confirm_message")
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
    }

    private var startsAtPosition: Bool {
        if case let .edit(_, focusPosition) = mode {
            return focusPosition
        }
        return false
    }

    private var identitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("course_edit_section_identity", comment: ""))
                .font(AppFont.fixed(16, weight: .bold))
                .foregroundStyle(Theme.Colors.textPrimary)

            if case let .edit(buoy, _) = mode {
                HStack(spacing: 8) {
                    Text(NSLocalizedString("buoy_id_label", comment: ""))
                        .font(AppFont.fixed(12, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Text(buoy.id)
                        .font(AppFont.fixed(13, weight: .medium))
                        .foregroundStyle(Theme.Colors.textPrimary)
                }
                .accessibilityIdentifier("buoy_edit_id_label")
            }

            formTextField(
                label: NSLocalizedString("course_edit_name_label", comment: ""),
                text: $name,
                placeholder: NSLocalizedString("buoy_edit_name_placeholder", comment: ""),
                field: .name
            )
            .accessibilityIdentifier("buoy_edit_name_field")

            formTextField(
                label: NSLocalizedString("course_edit_description_label", comment: ""),
                text: $description,
                placeholder: NSLocalizedString("buoy_edit_description_placeholder", comment: ""),
                field: .descriptionField
            )
            .accessibilityIdentifier("buoy_edit_description_field")
        }
    }

    private func positionSection(
        onLatitudeEditingBegan: @escaping () -> Void = {},
        onLongitudeEditingBegan: @escaping () -> Void = {}
    ) -> some View {
        CoursePositionSection(
            sectionTitle: NSLocalizedString("course_edit_section_position", comment: ""),
            sectionSubtitle: NSLocalizedString("buoy_edit_position_subtitle", comment: ""),
            lat: $lat,
            lon: $lon,
            onSetGPSPosition: handleUseCurrentGPSPosition,
            onLatitudeEditingBegan: onLatitudeEditingBegan,
            onLongitudeEditingBegan: onLongitudeEditingBegan,
            onLatitudeEntryStateChanged: { latEntryState = $0 },
            onLongitudeEntryStateChanged: { lonEntryState = $0 },
            accessibilityPrefix: "buoy",
            gpsButtonAccessibilityId: "buoy_set_coordinates_button"
        )
    }

    private var removeButton: some View {
        CourseRemoveButton(titleKey: "buoy_delete_button") {
            showRemoveConfirm = true
        }
        .accessibilityIdentifier("buoy_delete_button")
    }

    private var saveBar: some View {
        VStack(spacing: 12) {
            if let saveError {
                Text(saveError)
                    .font(AppFont.fixed(13, weight: .medium))
                    .foregroundStyle(Theme.Colors.error)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("buoy_edit_save_error_label")
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
            .accessibilityIdentifier("buoy_edit_save_button")
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
                Text(infoBodyKey)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .navigationTitle(LocalizedStringKey("buoy_editor_info_title"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("close_button") { showInfoSheet = false }
                        .font(AppUI.buttonFont)
                }
            }
        }
        .presentationDetents([.fraction(0.4), .medium])
    }

    @ViewBuilder
    private func formTextField(
        label: String,
        text: Binding<String>,
        placeholder: String,
        field: BuoyEditorField
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

    private func prefillFromMode() {
        switch mode {
        case .add:
            focusedField = .name
        case let .edit(buoy, _):
            name = buoy.name
            description = buoy.description ?? ""
            if let coordinate = buoy.coordinate {
                lat = DMSCoordinate(from: coordinate.lat, isLat: true)
                lon = DMSCoordinate(from: coordinate.lon, isLat: false)
            }
        }
    }

    private func performSave() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        if let coordinateError = validateCoordinatesRequired() {
            saveError = coordinateError
            return
        }

        isSaving = true
        saveError = nil
        defer { isSaving = false }

        let descriptionValue = normalizedOptional(description)
        let coordinateValue = resolvedCoordinate()

        let savedBuoy: BuoyRecord?
        switch mode {
        case let .add(raceId):
            savedBuoy = storage.createBuoy(
                raceId: raceId,
                name: trimmedName,
                description: descriptionValue,
                coordinate: coordinateValue
            )
        case let .edit(buoy, _):
            savedBuoy = storage.updateBuoy(
                id: buoy.id,
                raceId: buoy.raceId,
                name: trimmedName,
                description: descriptionValue,
                coordinate: coordinateValue
            )
        }

        guard let savedBuoy else {
            saveError = NSLocalizedString("buoy_edit_save_error", comment: "")
            return
        }

        onSaved(.saved(savedBuoy))
    }

    private func performRemove() {
        guard case let .edit(buoy, _) = mode else { return }
        storage.deleteBuoy(id: buoy.id, raceId: buoy.raceId)
        onSaved(.removed(id: buoy.id))
    }

    private func resolvedCoordinate() -> CoordinatePoint? {
        return CoordinatePoint(lat: lat.toDecimal(), lon: lon.toDecimal())
    }

    private func validateCoordinatesRequired() -> String? {
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

    private func scrollToTarget(_ target: BuoyEditorScrollTarget, using proxy: ScrollViewProxy) {
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
