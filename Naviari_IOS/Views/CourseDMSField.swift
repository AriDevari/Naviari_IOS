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

enum DMSSecondsTextCodec {
    static func placeholder(locale: Locale = .autoupdatingCurrent) -> String {
        "0\(decimalSeparator(in: locale))0"
    }

    static func displayString(for seconds: Double, locale: Locale = .autoupdatingCurrent) -> String {
        let roundedSeconds = (seconds * 10).rounded() / 10

        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1

        return formatter.string(from: NSNumber(value: roundedSeconds)) ?? fallbackDisplayString(for: roundedSeconds)
    }

    static func sanitize(_ input: String, maxLength: Int, locale: Locale = .autoupdatingCurrent) -> String {
        let separator = decimalSeparator(in: locale)
        var result = ""
        var hasSeparator = false

        for scalar in input.unicodeScalars {
            if CharacterSet.decimalDigits.contains(scalar) {
                result.unicodeScalars.append(scalar)
            } else if isSupportedDecimalSeparator(scalar) {
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
        guard !input.isEmpty else { return nil }

        let normalized = input.replacingOccurrences(of: decimalSeparator(in: locale), with: ".")
        return Double(normalized)
    }

    private static func decimalSeparator(in locale: Locale) -> String {
        locale.decimalSeparator ?? "."
    }

    private static func isSupportedDecimalSeparator(_ scalar: UnicodeScalar) -> Bool {
        scalar == "." || scalar == ","
    }

    private static func fallbackDisplayString(for seconds: Double) -> String {
        let integerSeconds = Int(seconds)
        if seconds.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(integerSeconds)"
        }
        return "\(seconds)"
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
    var isPendingSaveHighlight: Bool = false
    var onBeginEditing: () -> Void = {}
    var onEntryStateChanged: (DMSFieldEntryState) -> Void = { _ in }

    // Local editable strings so the user can partially type numbers.
    @State private var degText: String = ""
    @State private var minText: String = ""
    @State private var secText: String = ""

    @FocusState private var focusedPart: DMSPart?

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
                Text("deg · min · sec")
                    .font(AppFont.fixed(11, weight: .medium))
                    .foregroundStyle(secondaryForegroundColor.opacity(0.82))
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
                decimalField(text: $secText, maxLength: 6, placeholder: DMSSecondsTextCodec.placeholder())
                    .frame(width: 66)
                    .focused($focusedPart, equals: .seconds)
                    .onChange(of: secText) { _, newVal in
                        let stripped = DMSSecondsTextCodec.sanitize(newVal, maxLength: 6)
                        if stripped != newVal { secText = stripped }
                        value.seconds = DMSSecondsTextCodec.parse(stripped) ?? 0.0
                        notifyEntryStateChanged()
                    }

                separatorLabel("\"")

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

    private func syncTextFromBinding() {
        let newDegText = value.degrees == 0 ? "" : "\(value.degrees)"
        let newMinText = "\(value.minutes)"
        let newSecText = DMSSecondsTextCodec.displayString(for: value.seconds)

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

    private func hemisphereBackgroundColor(for option: String) -> Color {
        return value.hemisphere == option ? Theme.Colors.brandNavy : Color.clear
    }

}
