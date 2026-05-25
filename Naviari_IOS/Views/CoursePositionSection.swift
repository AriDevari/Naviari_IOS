//
//  CoursePositionSection.swift
//  Naviari_IOS
//
//  Reusable position-entry section used by CourseMarkEditView (once) and
//  CourseLineEditView (twice — left end and right end).
//
//  This is the single place to improve when coordinate entry evolves
//  (decimal fields, map picker, MGRS, etc.).
//

import SwiftUI

struct CoursePositionSection: View {
    let sectionTitle: String
    let sectionSubtitle: String
    @Binding var lat: DMSCoordinate
    @Binding var lon: DMSCoordinate
    let onSetGPSPosition: () -> Void
    var onLatitudeEditingBegan: () -> Void = {}
    var onLongitudeEditingBegan: () -> Void = {}
    var onLatitudeEntryStateChanged: (DMSFieldEntryState) -> Void = { _ in }
    var onLongitudeEntryStateChanged: (DMSFieldEntryState) -> Void = { _ in }
    /// Used as the prefix for DMS field accessibility identifiers, e.g. "mark", "left", "right".
    var accessibilityPrefix: String = "mark"
    /// Optional override for the GPS button accessibility identifier.
    var gpsButtonAccessibilityId: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            VStack(alignment: .leading, spacing: 4) {
                Text(sectionTitle)
                    .font(AppFont.fixed(16, weight: .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text(sectionSubtitle)
                    .font(AppFont.fixed(13, weight: .medium))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            // Lat DMS field
            CourseDMSField(
                label: NSLocalizedString("course_edit_lat_label", comment: ""),
                isLatitude: true,
                value: $lat,
                accessibilityIdentifier: "\(accessibilityPrefix)_dms_lat",
                onBeginEditing: onLatitudeEditingBegan,
                onEntryStateChanged: onLatitudeEntryStateChanged
            )

            // Lon DMS field
            CourseDMSField(
                label: NSLocalizedString("course_edit_lon_label", comment: ""),
                isLatitude: false,
                value: $lon,
                accessibilityIdentifier: "\(accessibilityPrefix)_dms_lon",
                onBeginEditing: onLongitudeEditingBegan,
                onEntryStateChanged: onLongitudeEntryStateChanged
            )

            // GPS button — outlined pill
            Button(action: onSetGPSPosition) {
                ZStack {
                    Text(NSLocalizedString("course_position_label", comment: ""))
                        .font(AppFont.fixed(15, weight: .semibold))
                        .foregroundStyle(Theme.RaceManager.primaryColor)
                        .frame(maxWidth: .infinity, alignment: .center)

                    HStack {
                        Spacer()
                        Image(systemName: "location.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(Theme.RaceManager.primaryColor)
                            .padding(.trailing, 16)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: Theme.Sizing.secondaryButtonHeight)
            }
            .buttonStyle(.plain)
            .overlay(
                Capsule()
                    .stroke(Theme.RaceManager.primaryColor, lineWidth: 1.5)
            )
            .accessibilityIdentifier(gpsButtonAccessibilityId ?? "course_edit_gps_\(accessibilityPrefix)")
        }
    }
}
