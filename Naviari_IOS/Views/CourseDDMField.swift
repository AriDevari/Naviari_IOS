//
//  CourseDDMField.swift
//  Naviari_IOS
//
//  Single-axis DDM (degrees / decimal-minutes / hemisphere) coordinate input,
//  e.g. `60° 07.407' N`. Used exclusively via CourseCoordinateEditorSection — do not
//  embed directly elsewhere. Binds to the same shared `DMSCoordinate` state as
//  CourseDMSField so mode round-trips (DMS <-> DDM <-> decimal) stay lossless.
//

import SwiftUI

// MARK: - CourseDDMField

private enum DDMPart: Hashable {
    case degrees, minutes
}

struct CourseDDMField: View {
    let label: String
    /// `true` → N/S toggle, `false` → E/W toggle.
    let isLatitude: Bool
    /// Shared coordinate state. DDM edits degrees + decimal minutes and writes them back
    /// as `minutes`/`seconds` (`minutes = Int(decimalMinutes); seconds = frac * 60`), so the
    /// same underlying `DMSCoordinate` powers every entry mode.
    @Binding var value: DMSCoordinate
    /// Accessibility identifier prefix for the container (e.g. "course_ddm_lat").
    var accessibilityIdentifier: String = "course_ddm"
    var isPendingSaveHighlight: Bool = false
    var onBeginEditing: () -> Void = {}
    var onEntryStateChanged: (DDMFieldEntryState) -> Void = { _ in }

    // Local editable strings so the user can partially type numbers.
    @State private var degText: String = ""
    @State private var minText: String = ""

    @FocusState private var focusedPart: DDMPart?

    private var hemiOptions: [String] { isLatitude ? ["N", "S"] : ["E", "W"] }

    private var containerBackgroundColor: Color {
        Theme.FormField.background
    }

    private var fieldBackgroundColor: Color {
        isPendingSaveHighlight ? Theme.FormField.pendingNumericBackground : Theme.FormField.numericBackground
    }

    private var primaryForegroundColor: Color {
        isPendingSaveHighlight ? Theme.FormField.pendingForeground : Theme.Colors.textPrimary
    }

    private var secondaryForegroundColor: Color {
        Theme.Colors.textSecondary
    }

    private var borderColor: Color {
        Theme.FormField.borderDefault
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Field header: label on left, hint on right.
            HStack {
                Text(label)
                    .font(AppFont.fixed(12, weight: .semibold))
                    .foregroundStyle(secondaryForegroundColor)
                Spacer()
                Text("deg · min")
                    .font(AppFont.fixed(11, weight: .medium))
                    .foregroundStyle(secondaryForegroundColor.opacity(0.82))
            }

            // DDM row.
            HStack(spacing: 4) {
                // Degrees
                numericField(text: $degText, maxLength: 3, placeholder: "0")
                    .frame(width: 54)
                    .focused($focusedPart, equals: .degrees)
                    .onChange(of: degText) { _, newVal in
                        let stripped = stripNonDigits(newVal, maxLen: 3)
                        if stripped != newVal { degText = stripped }
                        value.degrees = Int(stripped) ?? 0
                        notifyEntryStateChanged()
                    }

                separatorLabel("°")

                // Decimal minutes
                decimalField(text: $minText, maxLength: 6, placeholder: DDMMinutesTextCodec.placeholder())
                    .frame(width: 82)
                    .focused($focusedPart, equals: .minutes)
                    .onChange(of: minText) { _, newVal in
                        let stripped = DDMMinutesTextCodec.sanitize(newVal, maxLength: 6)
                        if stripped != newVal { minText = stripped }
                        applyDecimalMinutes(from: stripped)
                        notifyEntryStateChanged()
                    }

                separatorLabel("'")

                Spacer(minLength: 4)

                // Hemisphere toggle
                hemisphereToggle
            }
        }
        .padding(12)
        .background(containerBackgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.FormField.cornerRadius, style: .continuous)
            .stroke(borderColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.FormField.cornerRadius, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(accessibilityIdentifier)
        .onAppear { syncTextFromBinding() }
        .onChange(of: value) { _, _ in
            guard focusedPart == nil else { return }
            syncTextFromBinding()
        }
        .onChange(of: focusedPart) { _, newValue in
            guard newValue != nil else { return }
            onBeginEditing()
        }
    }

    // MARK: - Sub-views

    @ViewBuilder
    private func numericField(text: Binding<String>, maxLength: Int, placeholder: String) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .font(.system(size: 17, weight: .bold).monospacedDigit())
            .foregroundStyle(primaryForegroundColor)
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .background(fieldBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
    }

    @ViewBuilder
    private func decimalField(text: Binding<String>, maxLength: Int, placeholder: String) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.center)
            .font(.system(size: 17, weight: .bold).monospacedDigit())
            .foregroundStyle(primaryForegroundColor)
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .background(fieldBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
    }

    @ViewBuilder
    private func separatorLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(secondaryForegroundColor)
            .padding(.horizontal, 2)
    }

    private var hemisphereToggle: some View {
        HStack(spacing: 2) {
            ForEach(hemiOptions, id: \.self) { option in
                Button(action: { value.hemisphere = option }) {
                    Text(option)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(value.hemisphere == option ? .white : Theme.Colors.textPrimary)
                        .frame(width: 30, height: 30)
                        .background(
                            Circle()
                                .fill(hemisphereBackgroundColor(for: option))
                        )
                }
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.15), value: value.hemisphere)
            }
        }
        .padding(3)
        .background(Theme.Segmented.containerBackground)
        .clipShape(Capsule())
        .frame(width: 72, height: 36)
    }

    // MARK: - Helpers

    /// Splits the typed decimal minutes back into the shared coordinate's whole minutes and
    /// seconds so DDM and DMS remain two views of the exact same value.
    private func applyDecimalMinutes(from text: String) {
        let decimalMinutes = DDMMinutesTextCodec.parse(text) ?? 0.0
        let wholeMinutes = Int(decimalMinutes)
        value.minutes = wholeMinutes
        value.seconds = (decimalMinutes - Double(wholeMinutes)) * 60.0
    }

    private func syncTextFromBinding() {
        let decimalMinutes = DDMCoordinate(dms: value).decimalMinutes
        let newDegText = value.degrees == 0 ? "" : "\(value.degrees)"
        let newMinText = DDMMinutesTextCodec.displayString(for: decimalMinutes)

        if degText != newDegText { degText = newDegText }
        if minText != newMinText { minText = newMinText }
        notifyEntryStateChanged()
    }

    private func notifyEntryStateChanged() {
        onEntryStateChanged(
            DDMFieldEntryState(
                degreesText: degText,
                minutesText: minText
            )
        )
    }

    private func stripNonDigits(_ input: String, maxLen: Int) -> String {
        let digits = input.filter(\.isNumber)
        return String(digits.prefix(maxLen))
    }

    private func hemisphereBackgroundColor(for option: String) -> Color {
        return value.hemisphere == option ? Theme.Colors.brandNavy : Color.clear
    }

}
