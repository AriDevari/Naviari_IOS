import CoreLocation
import SwiftUI
import UIKit

@MainActor
final class CourseCoordinateEditorController: ObservableObject {
    @Published var lat: DMSCoordinate = DMSCoordinate()
    @Published var lon: DMSCoordinate = DMSCoordinate(hemisphere: "E")
    @Published var latEntryState: DMSFieldEntryState = DMSFieldEntryState()
    @Published var lonEntryState: DMSFieldEntryState = DMSFieldEntryState()
    @Published var latDecimalText: String = ""
    @Published var lonDecimalText: String = ""
    @Published var bearingDegreesText: String = ""
    @Published var distanceMetersText: String = ""
    @Published var positionInputMode: CourseCoordinatePositionInputMode = .coordinateEntry
    @Published var coordinateEntryMode: CourseCoordinateEntryMode = .dms
    @Published var isPositionActionMenuExpanded = false
    @Published var isBuoyPickerExpanded = false
    @Published var selectedBuoyId: String?

    func resetForNewItem() {
        lat = DMSCoordinate()
        lon = DMSCoordinate(hemisphere: "E")
        latEntryState = DMSFieldEntryState()
        lonEntryState = DMSFieldEntryState()
        latDecimalText = ""
        lonDecimalText = ""
        bearingDegreesText = ""
        distanceMetersText = ""
        positionInputMode = .coordinateEntry
        coordinateEntryMode = .dms
        isPositionActionMenuExpanded = false
        isBuoyPickerExpanded = false
        selectedBuoyId = nil
    }

    func prefill(coordinate: CoordinatePoint?) {
        resetForNewItem()
        guard let coordinate else { return }
        applyCoordinate(coordinate)
    }

    func validationError(locationManager: LocationDataManager) -> String? {
        switch resolvedCoordinate(locationManager: locationManager, persistChanges: false) {
        case .success:
            return nil
        case let .failure(error):
            return error
        }
    }

    func resolvedCoordinate(
        locationManager: LocationDataManager,
        persistChanges: Bool = true
    ) -> CourseCoordinateResolution<CoordinatePoint> {
        switch coordinateEntryMode {
        case .dms:
            guard latEntryState.isComplete, lonEntryState.isComplete else {
                return .failure(NSLocalizedString("course_edit_coordinate_incomplete_error", comment: ""))
            }
            guard lat.isValid(isLatitude: true) else {
                return .failure(NSLocalizedString("course_edit_coordinate_lat_invalid_error", comment: ""))
            }
            guard lon.isValid(isLatitude: false) else {
                return .failure(NSLocalizedString("course_edit_coordinate_lon_invalid_error", comment: ""))
            }

            return .success(CoordinatePoint(lat: lat.toDecimal(), lon: lon.toDecimal()))

        case .decimal:
            guard let latitude = DecimalCoordinateTextCodec.parse(latDecimalText) else {
                return .failure(NSLocalizedString("course_edit_coordinate_incomplete_error", comment: ""))
            }
            guard let longitude = DecimalCoordinateTextCodec.parse(lonDecimalText) else {
                return .failure(NSLocalizedString("course_edit_coordinate_incomplete_error", comment: ""))
            }
            guard abs(latitude) <= 90 else {
                return .failure(NSLocalizedString("course_edit_coordinate_lat_invalid_error", comment: ""))
            }
            guard abs(longitude) <= 180 else {
                return .failure(NSLocalizedString("course_edit_coordinate_lon_invalid_error", comment: ""))
            }

            let coordinate = CoordinatePoint(lat: latitude, lon: longitude)
            if persistChanges {
                applyCoordinate(coordinate)
            }
            return .success(coordinate)

        case .bearingDistance:
            guard locationAuthorizationIsValid(locationManager) else {
                return .failure(NSLocalizedString("set_position_error_location_permission_required", comment: ""))
            }
            guard let origin = currentLocationPoint(from: locationManager) else {
                return .failure(NSLocalizedString("set_position_error_location_unavailable", comment: ""))
            }
            guard let bearing = DecimalCoordinateTextCodec.parse(bearingDegreesText) else {
                return .failure(NSLocalizedString("course_edit_coordinate_incomplete_error", comment: ""))
            }
            guard let distance = DecimalCoordinateTextCodec.parse(distanceMetersText) else {
                return .failure(NSLocalizedString("course_edit_coordinate_incomplete_error", comment: ""))
            }
            guard (0 ... 360).contains(bearing) else {
                return .failure(NSLocalizedString("course_edit_bearing_invalid_error", comment: ""))
            }
            guard distance >= 0 else {
                return .failure(NSLocalizedString("course_edit_distance_invalid_error", comment: ""))
            }

            let coordinate = BearingDistanceProjection.destination(
                from: origin,
                bearingDegrees: bearing,
                distanceMeters: distance
            )
            if persistChanges {
                applyCoordinate(coordinate)
            }
            return .success(coordinate)
        }
    }

    func handlePrimaryPositionAction(locationManager: LocationDataManager) -> String? {
        positionInputMode = .coordinateEntry
        isBuoyPickerExpanded = false
        isPositionActionMenuExpanded = false
        return handleUseCurrentGPSPosition(locationManager: locationManager)
    }

    func handleUseCurrentGPSPosition(locationManager: LocationDataManager) -> String? {
        locationManager.start()

        guard locationAuthorizationIsValid(locationManager) else {
            return NSLocalizedString("set_position_error_location_permission_required", comment: "")
        }

        guard let coordinate = currentLocationPoint(from: locationManager) else {
            return NSLocalizedString("set_position_error_location_unavailable", comment: "")
        }

        applyCoordinate(coordinate)
        return nil
    }

    func handleCopyFromBuoyAction() {
        isPositionActionMenuExpanded = false
        selectedBuoyId = nil
        positionInputMode = .copyFromBuoy
        isBuoyPickerExpanded = true
    }

    func handleDMSAction() {
        isPositionActionMenuExpanded = false
        isBuoyPickerExpanded = false
        positionInputMode = .coordinateEntry
        coordinateEntryMode = .dms
    }

    func handleDecimalNumbersAction() {
        isPositionActionMenuExpanded = false
        isBuoyPickerExpanded = false
        positionInputMode = .coordinateEntry
        coordinateEntryMode = .decimal
        syncDecimalCoordinateTexts()
    }

    func handleBearingDistanceAction(locationManager: LocationDataManager) {
        locationManager.start()
        isPositionActionMenuExpanded = false
        isBuoyPickerExpanded = false
        positionInputMode = .coordinateEntry
        coordinateEntryMode = .bearingDistance
        syncBearingDistanceTexts(origin: currentLocationPoint(from: locationManager))
    }

    func clipboardCoordinateString(locationManager: LocationDataManager) -> CourseCoordinateResolution<String> {
        switch resolvedCoordinate(locationManager: locationManager) {
        case let .success(coordinate):
            return .success(String(format: "%.6f, %.6f", coordinate.lat, coordinate.lon))
        case let .failure(error):
            return .failure(error)
        }
    }

    func handlePasteFromClipboard(_ text: String?) -> String? {
        guard let text,
              let coordinate = clipboardCoordinate(from: text) else {
            return NSLocalizedString("course_edit_paste_from_clipboard_invalid_error", comment: "")
        }

        applyCoordinate(coordinate)
        return nil
    }

    func handleSelectedBuoyCopy(_ buoy: BuoyRecord) {
        guard let coordinate = buoy.coordinate else { return }
        selectedBuoyId = buoy.id
        applyCoordinate(coordinate)
    }

    func syncCoordinateBinding(
        from text: String,
        field: CourseCoordinateEditorField,
        locationManager: LocationDataManager
    ) {
        switch field {
        case .latitudeDecimal:
            syncDecimalCoordinateBinding(from: text, isLatitude: true)
        case .longitudeDecimal:
            syncDecimalCoordinateBinding(from: text, isLatitude: false)
        case .bearingDegrees, .distanceMeters:
            syncBearingDistanceCoordinate(origin: currentLocationPoint(from: locationManager))
        }
    }

    func handleLocationUpdate(locationManager: LocationDataManager) {
        guard coordinateEntryMode == .bearingDistance else { return }
        guard bearingDegreesText.isEmpty, distanceMetersText.isEmpty else { return }
        syncBearingDistanceTexts(origin: currentLocationPoint(from: locationManager))
    }

    private func applyCoordinate(_ coordinate: CoordinatePoint) {
        lat = DMSCoordinate(from: coordinate.lat, isLat: true)
        lon = DMSCoordinate(from: coordinate.lon, isLat: false)
        latEntryState = entryState(for: lat)
        lonEntryState = entryState(for: lon)
        syncDecimalCoordinateTexts()
        if coordinateEntryMode != .bearingDistance {
            bearingDegreesText = ""
            distanceMetersText = ""
        }
        positionInputMode = .coordinateEntry
        isBuoyPickerExpanded = false
        isPositionActionMenuExpanded = false
    }

    private func syncDecimalCoordinateTexts() {
        latDecimalText = latEntryState.hasAnyEntry ? DecimalCoordinateTextCodec.displayString(for: lat.toDecimal()) : ""
        lonDecimalText = lonEntryState.hasAnyEntry ? DecimalCoordinateTextCodec.displayString(for: lon.toDecimal()) : ""
    }

    private func syncDecimalCoordinateBinding(from text: String, isLatitude: Bool) {
        guard let parsed = DecimalCoordinateTextCodec.parse(text) else { return }

        if isLatitude {
            guard abs(parsed) <= 90 else { return }
            lat = DMSCoordinate(from: parsed, isLat: true)
            latEntryState = entryState(for: lat)
        } else {
            guard abs(parsed) <= 180 else { return }
            lon = DMSCoordinate(from: parsed, isLat: false)
            lonEntryState = entryState(for: lon)
        }
    }

    private func syncBearingDistanceCoordinate(origin: CoordinatePoint?) {
        guard coordinateEntryMode == .bearingDistance else { return }
        guard let origin else { return }
        guard let bearing = DecimalCoordinateTextCodec.parse(bearingDegreesText) else { return }
        guard let distance = DecimalCoordinateTextCodec.parse(distanceMetersText) else { return }
        guard (0 ... 360).contains(bearing), distance >= 0 else { return }

        let coordinate = BearingDistanceProjection.destination(
            from: origin,
            bearingDegrees: bearing,
            distanceMeters: distance
        )
        lat = DMSCoordinate(from: coordinate.lat, isLat: true)
        lon = DMSCoordinate(from: coordinate.lon, isLat: false)
        latEntryState = entryState(for: lat)
        lonEntryState = entryState(for: lon)
        syncDecimalCoordinateTexts()
    }

    private func syncBearingDistanceTexts(origin: CoordinatePoint?) {
        guard coordinateEntryMode == .bearingDistance else { return }
        guard latEntryState.hasAnyEntry, lonEntryState.hasAnyEntry else {
            bearingDegreesText = ""
            distanceMetersText = ""
            return
        }
        guard let origin else {
            bearingDegreesText = ""
            distanceMetersText = ""
            return
        }

        let projection = BearingDistanceProjection.bearingAndDistance(
            from: origin,
            to: CoordinatePoint(lat: lat.toDecimal(), lon: lon.toDecimal())
        )
        bearingDegreesText = DecimalCoordinateTextCodec.displayString(
            for: projection.bearingDegrees,
            maximumFractionDigits: 1
        )
        distanceMetersText = DecimalCoordinateTextCodec.displayString(
            for: projection.distanceMeters,
            maximumFractionDigits: 1
        )
    }

    private func currentLocationPoint(from locationManager: LocationDataManager) -> CoordinatePoint? {
        guard let coordinate = locationManager.latestLocation?.coordinate else { return nil }
        return CoordinatePoint(lat: coordinate.latitude, lon: coordinate.longitude)
    }

    private func locationAuthorizationIsValid(_ locationManager: LocationDataManager) -> Bool {
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return true
        default:
            return false
        }
    }

    private func entryState(for coordinate: DMSCoordinate) -> DMSFieldEntryState {
        let secondsText = DMSSecondsTextCodec.displayString(for: coordinate.seconds, locale: Locale(identifier: "en_US_POSIX"))

        return DMSFieldEntryState(
            degreesText: "\(coordinate.degrees)",
            minutesText: String(format: "%02d", coordinate.minutes),
            secondsText: secondsText
        )
    }

    private func clipboardCoordinate(from text: String) -> CoordinatePoint? {
        let components = text
            .replacingOccurrences(of: "\n", with: ",")
            .replacingOccurrences(of: ";", with: ",")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard components.count == 2,
              let latitude = Double(components[0]),
              let longitude = Double(components[1]),
              abs(latitude) <= 90,
              abs(longitude) <= 180 else {
            return nil
        }

        return CoordinatePoint(lat: latitude, lon: longitude)
    }
}

struct CourseCoordinateEditorSection: View {
    let sectionTitle: String
    let sectionSubtitle: String
    @ObservedObject var controller: CourseCoordinateEditorController
    @Binding var errorMessage: String?
    let buoyOptions: [BuoyRecord]
    var onLatitudeEditingBegan: () -> Void = {}
    var onLongitudeEditingBegan: () -> Void = {}
    var accessibilityPrefix: String = "mark"
    var gpsButtonAccessibilityId: String? = nil

    @FocusState private var focusedField: CourseCoordinateEditorField?
    @EnvironmentObject private var locationManager: LocationDataManager
    @EnvironmentObject private var userNotifications: UserNotifications

    private var copyableBuoys: [BuoyRecord] {
        buoyOptions
            .filter { $0.coordinate != nil }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var hasBuoyCopyOption: Bool {
        !copyableBuoys.isEmpty
    }

    private var selectedBuoyPickerTitle: String {
        guard let selectedBuoyId = controller.selectedBuoyId,
              let buoy = copyableBuoys.first(where: { $0.id == selectedBuoyId }) else {
            return NSLocalizedString("course_edit_select_buoy_button", comment: "")
        }
        return buoySelectionTitle(buoy)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(sectionTitle)
                    .font(AppFont.fixed(16, weight: .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text(sectionSubtitle)
                    .font(AppFont.fixed(13, weight: .medium))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            if controller.positionInputMode == .copyFromBuoy {
                buoySelectorButton

                if controller.isBuoyPickerExpanded {
                    CourseBuoyPickerDropdown(
                        buoys: copyableBuoys,
                        optionIdentifierPrefix: "course_edit_buoy_option_",
                        onBuoySelected: handleSelectedBuoyCopy
                    )
                }
            } else {
                coordinateEntrySection
            }

            positionSplitButton

            if controller.isPositionActionMenuExpanded {
                positionActionDropdown
            }
        }
        .onReceive(locationManager.$latestLocation) { _ in
            controller.handleLocationUpdate(locationManager: locationManager)
        }
    }

    private var buoySelectorButton: some View {
        SplitActionButton(
            variant: .outlined(accentColor: Theme.RaceManager.primaryColor),
            isEnabled: true,
            isExpanded: controller.isBuoyPickerExpanded,
            primaryAccessibilityIdentifier: "course_edit_buoy_selector_button",
            secondaryAccessibilityIdentifier: "course_edit_buoy_selector_button_disclosure",
            onPrimaryTap: { controller.isBuoyPickerExpanded.toggle() },
            onSecondaryTap: { controller.isBuoyPickerExpanded.toggle() }
        ) {
            HStack {
                Spacer()
                Text(selectedBuoyPickerTitle)
                    .font(Theme.Typography.button)
                    .multilineTextAlignment(.center)
                Spacer()
            }
        }
    }

    private var positionSplitButton: some View {
        let buttonId = gpsButtonAccessibilityId ?? "course_edit_gps_\(accessibilityPrefix)"

        return SplitActionButton(
            variant: .outlined(accentColor: Theme.RaceManager.primaryColor),
            isEnabled: true,
            isExpanded: controller.isPositionActionMenuExpanded,
            primaryAccessibilityIdentifier: buttonId,
            secondaryAccessibilityIdentifier: "\(buttonId)_disclosure",
            onPrimaryTap: handlePrimaryPositionAction,
            onSecondaryTap: {
                dismissKeyboard()
                controller.isPositionActionMenuExpanded.toggle()
            }
        ) {
            SetPositionPrimaryButtonLabel()
        }
    }

    private var positionActionDropdown: some View {
        VStack(spacing: 0) {
            if hasBuoyCopyOption {
                positionActionButton(
                    titleKey: "course_edit_copy_from_buoy_action",
                    accessibilityIdentifier: "course_edit_copy_from_buoy_action",
                    showsDivider: true,
                    action: handleCopyFromBuoyAction
                )
            }

            coordinateEntryModeActionButtons

            positionActionButton(
                titleKey: "course_edit_copy_to_clipboard_action",
                accessibilityIdentifier: "course_edit_copy_to_clipboard_action",
                showsDivider: true,
                action: handleCopyToClipboard
            )

            positionActionButton(
                titleKey: "course_edit_paste_from_clipboard_action",
                accessibilityIdentifier: "course_edit_paste_from_clipboard_action",
                showsDivider: false,
                action: handlePasteFromClipboard
            )
        }
        .background(Theme.Colors.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.materialCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.materialCard, style: .continuous)
                .stroke(Theme.RaceManager.primaryColor.opacity(0.35), lineWidth: 1)
        )
        .shadow(
            color: Color.black.opacity(Theme.Effects.floatingStatusShadowOpacity * 0.35),
            radius: Theme.Effects.floatingStatusShadowRadius,
            x: 0,
            y: Theme.Effects.floatingStatusShadowYOffset
        )
    }

    @ViewBuilder
    private var coordinateEntryModeActionButtons: some View {
        if controller.coordinateEntryMode != .dms {
            positionActionButton(
                titleKey: "course_edit_dms_action",
                accessibilityIdentifier: "course_edit_dms_action",
                showsDivider: true,
                action: handleDMSAction
            )
        }

        if controller.coordinateEntryMode != .decimal {
            positionActionButton(
                titleKey: "course_edit_decimal_numbers_action",
                accessibilityIdentifier: "course_edit_decimal_numbers_action",
                showsDivider: true,
                action: handleDecimalNumbersAction
            )
        }

        if controller.coordinateEntryMode != .bearingDistance {
            positionActionButton(
                titleKey: "course_edit_bearing_distance_action",
                accessibilityIdentifier: "course_edit_bearing_distance_action",
                showsDivider: true,
                action: handleBearingDistanceAction
            )
        }
    }

    @ViewBuilder
    private var coordinateEntrySection: some View {
        switch controller.coordinateEntryMode {
        case .dms:
            CourseDMSField(
                label: NSLocalizedString("course_edit_lat_label", comment: ""),
                isLatitude: true,
                value: $controller.lat,
                accessibilityIdentifier: "\(accessibilityPrefix)_dms_lat",
                onBeginEditing: onLatitudeEditingBegan,
                onEntryStateChanged: { controller.latEntryState = $0 }
            )

            CourseDMSField(
                label: NSLocalizedString("course_edit_lon_label", comment: ""),
                isLatitude: false,
                value: $controller.lon,
                accessibilityIdentifier: "\(accessibilityPrefix)_dms_lon",
                onBeginEditing: onLongitudeEditingBegan,
                onEntryStateChanged: { controller.lonEntryState = $0 }
            )

        case .decimal:
            decimalCoordinateField(
                label: NSLocalizedString("course_edit_lat_label", comment: ""),
                text: $controller.latDecimalText,
                placeholder: DecimalCoordinateTextCodec.placeholder(for: 60.123456),
                field: .latitudeDecimal,
                accessibilityIdentifier: "\(accessibilityPrefix)_decimal_lat",
                onBeginEditing: onLatitudeEditingBegan
            )

            decimalCoordinateField(
                label: NSLocalizedString("course_edit_lon_label", comment: ""),
                text: $controller.lonDecimalText,
                placeholder: DecimalCoordinateTextCodec.placeholder(for: 24.123456),
                field: .longitudeDecimal,
                accessibilityIdentifier: "\(accessibilityPrefix)_decimal_lon",
                onBeginEditing: onLongitudeEditingBegan
            )

        case .bearingDistance:
            decimalCoordinateField(
                label: NSLocalizedString("course_edit_bearing_label", comment: ""),
                text: $controller.bearingDegreesText,
                placeholder: DecimalCoordinateTextCodec.placeholder(for: 90, maximumFractionDigits: 1),
                field: .bearingDegrees,
                accessibilityIdentifier: "\(accessibilityPrefix)_bearing_degrees",
                onBeginEditing: onLatitudeEditingBegan
            )

            decimalCoordinateField(
                label: NSLocalizedString("course_edit_distance_label", comment: ""),
                text: $controller.distanceMetersText,
                placeholder: DecimalCoordinateTextCodec.placeholder(for: 150, maximumFractionDigits: 1),
                field: .distanceMeters,
                accessibilityIdentifier: "\(accessibilityPrefix)_distance_meters",
                onBeginEditing: onLongitudeEditingBegan
            )
        }
    }

    private func positionActionButton(
        titleKey: String,
        accessibilityIdentifier: String,
        showsDivider: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                Text(LocalizedStringKey(titleKey))
                    .font(AppFont.textStyle(.body))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: Theme.Sizing.primaryButtonHeight, alignment: .leading)
            .background(Theme.Colors.surfacePrimary)
            .overlay(alignment: .bottom) {
                if showsDivider {
                    Rectangle()
                        .fill(Theme.FormField.borderDefault)
                        .frame(height: 1)
                        .padding(.horizontal, 16)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    @ViewBuilder
    private func decimalCoordinateField(
        label: String,
        text: Binding<String>,
        placeholder: String,
        field: CourseCoordinateEditorField,
        accessibilityIdentifier: String,
        onBeginEditing: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(AppFont.fixed(12, weight: .semibold))
                .foregroundStyle(Theme.Colors.textSecondary)

            TextField(placeholder, text: text)
                .font(AppFont.fixed(17, weight: .semibold).monospacedDigit())
                .foregroundStyle(Theme.Colors.textPrimary)
                .keyboardType(.decimalPad)
                .textInputAutocapitalization(.never)
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
                .accessibilityIdentifier(accessibilityIdentifier)
                .onChange(of: text.wrappedValue) { _, newValue in
                    let sanitized = DecimalCoordinateTextCodec.sanitize(newValue, maxLength: 16)
                    if sanitized != newValue {
                        text.wrappedValue = sanitized
                    }
                    controller.syncCoordinateBinding(from: sanitized, field: field, locationManager: locationManager)
                }
                .onTapGesture {
                    onBeginEditing()
                }
        }
    }

    private func dismissKeyboard() {
        focusedField = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func handlePrimaryPositionAction() {
        dismissKeyboard()
        errorMessage = controller.handlePrimaryPositionAction(locationManager: locationManager)
    }

    private func handleCopyFromBuoyAction() {
        dismissKeyboard()
        controller.handleCopyFromBuoyAction()
        errorMessage = nil
    }

    private func handleDMSAction() {
        dismissKeyboard()
        controller.handleDMSAction()
        errorMessage = nil
    }

    private func handleDecimalNumbersAction() {
        dismissKeyboard()
        controller.handleDecimalNumbersAction()
        errorMessage = nil
    }

    private func handleBearingDistanceAction() {
        dismissKeyboard()
        controller.handleBearingDistanceAction(locationManager: locationManager)
        errorMessage = nil
    }

    private func handleCopyToClipboard() {
        dismissKeyboard()
        controller.isPositionActionMenuExpanded = false

        switch controller.clipboardCoordinateString(locationManager: locationManager) {
        case let .success(text):
            UIPasteboard.general.string = text
            errorMessage = nil
            userNotifications.show(
                message: NSLocalizedString("course_edit_copy_to_clipboard_success", comment: ""),
                severity: .success
            )
        case let .failure(error):
            errorMessage = error
        }
    }

    private func handlePasteFromClipboard() {
        dismissKeyboard()
        controller.isPositionActionMenuExpanded = false
        errorMessage = controller.handlePasteFromClipboard(UIPasteboard.general.string)
    }

    private func handleSelectedBuoyCopy(_ buoy: BuoyRecord) {
        controller.handleSelectedBuoyCopy(buoy)
        errorMessage = nil
    }
}

enum CourseCoordinatePositionInputMode {
    case coordinateEntry
    case copyFromBuoy
}

enum CourseCoordinateEntryMode {
    case dms
    case decimal
    case bearingDistance
}

enum DecimalCoordinateTextCodec {
    static func placeholder(
        for value: Double,
        locale: Locale = .autoupdatingCurrent,
        maximumFractionDigits: Int = 6
    ) -> String {
        displayString(for: value, locale: locale, maximumFractionDigits: maximumFractionDigits)
    }

    static func displayString(
        for value: Double,
        locale: Locale = .autoupdatingCurrent,
        maximumFractionDigits: Int = 6
    ) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maximumFractionDigits
        return formatter.string(from: NSNumber(value: value)) ?? fallbackString(for: value, maximumFractionDigits: maximumFractionDigits)
    }

    static func sanitize(_ input: String, maxLength: Int, locale: Locale = .autoupdatingCurrent) -> String {
        let separator = locale.decimalSeparator ?? "."
        var result = ""
        var hasSeparator = false
        var hasMinus = false

        for scalar in input.unicodeScalars {
            if CharacterSet.decimalDigits.contains(scalar) {
                result.unicodeScalars.append(scalar)
            } else if scalar == "-" {
                if !hasMinus && result.isEmpty {
                    result.append("-")
                    hasMinus = true
                }
            } else if scalar == "." || scalar == "," {
                if !hasSeparator {
                    result.append(separator)
                    hasSeparator = true
                }
            }

            if result.count >= maxLength {
                break
            }
        }

        return result
    }

    static func parse(_ input: String, locale: Locale = .autoupdatingCurrent) -> Double? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        if let number = formatter.number(from: trimmed) {
            return number.doubleValue
        }

        let normalized = trimmed
            .replacingOccurrences(of: locale.decimalSeparator ?? ".", with: ".")
            .replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }

    private static func fallbackString(for value: Double, maximumFractionDigits: Int) -> String {
        String(format: "%0.*f", maximumFractionDigits, value)
            .replacingOccurrences(of: #"0+$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\.$"#, with: "", options: .regularExpression)
    }
}

enum BearingDistanceProjection {
    private static let earthRadiusMeters = 6_371_000.0

    static func destination(from origin: CoordinatePoint, bearingDegrees: Double, distanceMeters: Double) -> CoordinatePoint {
        let angularDistance = distanceMeters / earthRadiusMeters
        let bearingRadians = bearingDegrees * .pi / 180
        let latitudeRadians = origin.lat * .pi / 180
        let longitudeRadians = origin.lon * .pi / 180

        let destinationLatitude = asin(
            sin(latitudeRadians) * cos(angularDistance)
                + cos(latitudeRadians) * sin(angularDistance) * cos(bearingRadians)
        )

        let destinationLongitude = longitudeRadians + atan2(
            sin(bearingRadians) * sin(angularDistance) * cos(latitudeRadians),
            cos(angularDistance) - sin(latitudeRadians) * sin(destinationLatitude)
        )

        let normalizedLongitude = fmod((destinationLongitude + 3 * .pi), (2 * .pi)) - .pi

        return CoordinatePoint(
            lat: destinationLatitude * 180 / .pi,
            lon: normalizedLongitude * 180 / .pi
        )
    }

    static func bearingAndDistance(from origin: CoordinatePoint, to destination: CoordinatePoint) -> (bearingDegrees: Double, distanceMeters: Double) {
        let originLocation = CLLocation(latitude: origin.lat, longitude: origin.lon)
        let destinationLocation = CLLocation(latitude: destination.lat, longitude: destination.lon)
        let distanceMeters = originLocation.distance(from: destinationLocation)

        let latitude1 = origin.lat * .pi / 180
        let latitude2 = destination.lat * .pi / 180
        let deltaLongitude = (destination.lon - origin.lon) * .pi / 180

        let y = sin(deltaLongitude) * cos(latitude2)
        let x = cos(latitude1) * sin(latitude2)
            - sin(latitude1) * cos(latitude2) * cos(deltaLongitude)
        let bearingRadians = atan2(y, x)
        let bearingDegrees = fmod((bearingRadians * 180 / .pi) + 360, 360)

        return (bearingDegrees, distanceMeters)
    }
}

enum CourseCoordinateEditorField: Hashable {
    case latitudeDecimal
    case longitudeDecimal
    case bearingDegrees
    case distanceMeters
}

enum CourseCoordinateResolution<Value> {
    case success(Value)
    case failure(String)
}