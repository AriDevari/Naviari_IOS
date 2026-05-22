//
//  CourseDMSField.swift
//  Naviari_IOS
//
//  Single-axis DMS (degrees / minutes / seconds / hemisphere) coordinate input.
//  Used exclusively via CoursePositionSection — do not embed directly elsewhere.
//

import SwiftUI

// MARK: - DMSCoordinate

/// A geographic coordinate expressed in degrees, minutes, decimal seconds, and hemisphere.
struct DMSCoordinate: Equatable {
    var degrees: Int
    var minutes: Int
    var seconds: Double
    /// "N", "S", "E", or "W"
    var hemisphere: String

    /// Converts this DMS coordinate to a signed decimal degree value.
    /// Northern and Eastern hemispheres are positive; Southern and Western are negative.
    func toDecimal() -> Double {
        let magnitude = Double(degrees) + Double(minutes) / 60.0 + seconds / 3600.0
        let isNegative = hemisphere == "S" || hemisphere == "W"
        return isNegative ? -magnitude : magnitude
    }

    /// Initialises a DMSCoordinate from a signed decimal degree value.
    /// - Parameters:
    ///   - decimal: Signed decimal degrees.
    ///   - isLat: `true` produces N/S hemisphere; `false` produces E/W.
    init(from decimal: Double, isLat: Bool) {
        let positive = decimal >= 0
        let abs = Swift.abs(decimal)
        let deg = Int(abs)
        let minutesTotal = (abs - Double(deg)) * 60.0
        let min = Int(minutesTotal)
        let sec = (minutesTotal - Double(min)) * 60.0
        self.degrees = deg
        self.minutes = min
        self.seconds = sec
        if isLat {
            self.hemisphere = positive ? "N" : "S"
        } else {
            self.hemisphere = positive ? "E" : "W"
        }
    }

    /// Zero-value initialiser — produces 0° 0' 0" N (or E when used for longitude).
    init(degrees: Int = 0, minutes: Int = 0, seconds: Double = 0.0, hemisphere: String = "N") {
        self.degrees = degrees
        self.minutes = minutes
        self.seconds = seconds
        self.hemisphere = hemisphere
    }

    func isValid(isLatitude: Bool) -> Bool {
        let allowedHemispheres = isLatitude ? ["N", "S"] : ["E", "W"]
        guard allowedHemispheres.contains(hemisphere) else { return false }
        guard degrees >= 0, minutes >= 0, minutes < 60, seconds >= 0, seconds < 60 else { return false }

        let maxDegrees = isLatitude ? 90 : 180
        guard degrees <= maxDegrees else { return false }

        if degrees == maxDegrees {
            return minutes == 0 && seconds == 0
        }

        return true
    }
}

struct DMSFieldEntryState: Equatable {
    var degreesText: String = ""
    var minutesText: String = ""
    var secondsText: String = ""

    var hasAnyEntry: Bool {
        !degreesText.isEmpty || !minutesText.isEmpty || !secondsText.isEmpty
    }

    var isComplete: Bool {
        !degreesText.isEmpty && !minutesText.isEmpty && !secondsText.isEmpty
    }
}

// MARK: - CourseDMSField

private enum DMSPart: Hashable {
    case degrees, minutes, seconds
}

struct CourseDMSField: View {
    let label: String
    /// `true` → N/S toggle, `false` → E/W toggle.
    let isLatitude: Bool
    @Binding var value: DMSCoordinate
    /// Accessibility identifier prefix for the container (e.g. "course_dms_lat").
    var accessibilityIdentifier: String = "course_dms"
    var onBeginEditing: () -> Void = {}
    var onEntryStateChanged: (DMSFieldEntryState) -> Void = { _ in }

    // Local editable strings so the user can partially type numbers.
    @State private var degText: String = ""
    @State private var minText: String = ""
    @State private var secText: String = ""

    @FocusState private var focusedPart: DMSPart?

    private var hemiOptions: [String] { isLatitude ? ["N", "S"] : ["E", "W"] }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Field header: label on left, hint on right.
            HStack {
                Text(label)
                    .font(AppFont.fixed(12, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textSecondary)
                Spacer()
                Text("deg · min · sec")
                    .font(AppFont.fixed(11, weight: .medium))
                    .foregroundStyle(Theme.Colors.textSecondary.opacity(0.6))
            }

            // DMS row.
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

                // Minutes
                numericField(text: $minText, maxLength: 2, placeholder: "00")
                    .frame(width: 48)
                    .focused($focusedPart, equals: .minutes)
                    .onChange(of: minText) { _, newVal in
                        let stripped = stripNonDigits(newVal, maxLen: 2)
                        if stripped != newVal { minText = stripped }
                        value.minutes = Int(stripped) ?? 0
                        notifyEntryStateChanged()
                    }

                separatorLabel("'")

                // Seconds (decimal)
                decimalField(text: $secText, maxLength: 6, placeholder: "0.0")
                    .frame(width: 66)
                    .focused($focusedPart, equals: .seconds)
                    .onChange(of: secText) { _, newVal in
                        let stripped = stripNonDecimal(newVal, maxLen: 6)
                        if stripped != newVal { secText = stripped }
                        value.seconds = Double(stripped) ?? 0.0
                        notifyEntryStateChanged()
                    }

                separatorLabel("\"")

                Spacer(minLength: 4)

                // Hemisphere toggle
                hemisphereToggle
            }
        }
        .padding(12)
        .background(Theme.FormField.background)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.FormField.cornerRadius, style: .continuous)
                .stroke(Theme.FormField.borderDefault, lineWidth: 1)
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
            .foregroundStyle(Theme.Colors.textPrimary)
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .background(Theme.FormField.numericBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Theme.FormField.borderDefault, lineWidth: 1)
            )
    }

    @ViewBuilder
    private func decimalField(text: Binding<String>, maxLength: Int, placeholder: String) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.center)
            .font(.system(size: 17, weight: .bold).monospacedDigit())
            .foregroundStyle(Theme.Colors.textPrimary)
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .background(Theme.FormField.numericBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Theme.FormField.borderDefault, lineWidth: 1)
            )
    }

    @ViewBuilder
    private func separatorLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(Theme.Colors.textSecondary)
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
                                .fill(value.hemisphere == option ? Theme.Colors.brandNavy : Color.clear)
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

    private func syncTextFromBinding() {
        let newDegText = value.degrees == 0 ? "" : "\(value.degrees)"
        let newMinText = value.minutes == 0 ? "" : "\(value.minutes)"
        let secRounded = (value.seconds * 10).rounded() / 10
        let newSecText = secRounded == 0.0 ? "" : secRounded.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(secRounded))"
            : "\(secRounded)"

        if degText != newDegText { degText = newDegText }
        if minText != newMinText { minText = newMinText }
        if secText != newSecText { secText = newSecText }
        notifyEntryStateChanged()
    }

    private func notifyEntryStateChanged() {
        onEntryStateChanged(
            DMSFieldEntryState(
                degreesText: degText,
                minutesText: minText,
                secondsText: secText
            )
        )
    }

    private func stripNonDigits(_ input: String, maxLen: Int) -> String {
        let digits = input.filter(\.isNumber)
        return String(digits.prefix(maxLen))
    }

    private func stripNonDecimal(_ input: String, maxLen: Int) -> String {
        var result = ""
        var hasDot = false
        for char in input {
            if char.isNumber {
                result.append(char)
            } else if char == "." || char == "," {
                if !hasDot {
                    result.append(".")
                    hasDot = true
                }
            }
            if result.count >= maxLen { break }
        }
        return result
    }

}
