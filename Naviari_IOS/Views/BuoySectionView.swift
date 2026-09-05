import SwiftUI

struct BuoySectionView: View {
    let titleKey: LocalizedStringKey
    let buoys: [BuoyRecord]
    @Binding var activeBuoyId: String?
    var sectionAccessibilityIdentifier: String = "buoy_section"
    var addButtonAccessibilityIdentifier: String = "buoy_add_button"
    var onAddTapped: () -> Void
    var onEditBuoy: (BuoyRecord) -> Void
    var onSetCoordinates: (BuoyRecord) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(titleKey)
                .font(AppFont.textStyle(.headline))
                .foregroundStyle(Theme.Colors.textPrimary)

            if buoys.isEmpty {
                emptyState
            } else {
                VStack(spacing: Theme.CourseTimeline.rowGap) {
                    ForEach(buoys) { buoy in
                        BuoyRowView(
                            buoy: buoy,
                            isActive: activeBuoyId == buoy.id,
                            onTap: {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    activeBuoyId = activeBuoyId == buoy.id ? nil : buoy.id
                                }
                            },
                            onEdit: { onEditBuoy(buoy) },
                            onSetCoordinates: { onSetCoordinates(buoy) }
                        )
                        .id(buoy.id)
                    }
                }
                .padding(.vertical, 4)
            }

            HStack {
                Spacer()
                addButton(accessibilityIdentifier: addButtonAccessibilityIdentifier)
                Spacer()
            }
            .padding(.top, 8)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(sectionAccessibilityIdentifier)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("buoy_empty_title")
                .font(AppFont.textStyle(.body, weight: .semibold))
                .foregroundStyle(Theme.Colors.textPrimary)

            Text("buoy_empty_message")
                .font(AppFont.textStyle(.footnote, weight: .medium))
                .foregroundStyle(Theme.Colors.textSecondary)
                .accessibilityIdentifier("buoy_empty_message")
        }
        .padding(.vertical, 4)
    }

    private func addButton(accessibilityIdentifier: String) -> some View {
        Button(action: onAddTapped) {
            Image(systemName: "plus")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Theme.RaceManager.primaryColor)
                .frame(width: Theme.Sizing.primaryButtonHeight, height: Theme.Sizing.primaryButtonHeight)
                .background(Theme.Colors.surfacePrimary)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Theme.RaceManager.primaryColor, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct BuoyRowView: View {
    let buoy: BuoyRecord
    let isActive: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let onSetCoordinates: () -> Void

    private var iconSize: CGFloat {
        Theme.CourseTimeline.iconDiameter
    }

    private var cardCornerRadius: CGFloat {
        Theme.CornerRadius.rowCard
    }

    private var cardLeadingOffset: CGFloat {
        Theme.CourseTimeline.iconDiameter / 2
    }

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(Theme.Colors.surfacePrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                        .stroke(
                            isActive ? Theme.CourseTimeline.cardBorderOpen : Theme.CourseTimeline.cardBorderDefault,
                            lineWidth: 1
                        )
                )
                .frame(minHeight: Theme.CourseTimeline.cardMinHeight)
                .padding(.leading, Theme.CourseTimeline.iconDiameter * 0.25)

            VStack(alignment: .leading, spacing: 8) {
                headerButton

                if isActive {
                    expandedSeparator
                    expandedBody
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.top, Theme.CourseTimeline.cardPaddingOther)
            .padding(.bottom, Theme.CourseTimeline.cardPaddingOther)
            .padding(.trailing, Theme.CourseTimeline.cardPaddingOther)
            .padding(.leading, Theme.CourseTimeline.cardPaddingLeading)
            .padding(.leading, Theme.CourseTimeline.iconDiameter * 0.25)

            buoyIcon
                .frame(width: iconSize, height: iconSize)
                .offset(x: -(Theme.CourseTimeline.iconDiameter / 2))
        }
        .padding(.leading, cardLeadingOffset)
        .accessibilityIdentifier("buoy_row_\(buoy.id)")
    }

    private var headerButton: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(buoy.name)
                        .font(AppFont.textStyle(.body, weight: isActive ? .bold : .medium))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if !isActive {
                        Text(collapsedSubtitle)
                            .font(AppFont.textStyle(.footnote, weight: .medium))
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textSecondary.opacity(0.5))
                    .rotationEffect(.degrees(isActive ? 180 : 0))
                    .animation(.easeOut(duration: 0.2), value: isActive)
                    .padding(.top, 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("buoy_row_expand_button_\(buoy.id)")
    }

    private var expandedSeparator: some View {
        Rectangle()
            .stroke(Theme.CourseTimeline.expandedSeparatorColor, style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
            .frame(height: 1)
            .padding(.top, 6)
    }

    private var buoyIcon: some View {
        ZStack {
            Circle()
                .fill(Theme.Colors.brandPrimary)
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    private var collapsedSubtitle: String {
        if let description = buoy.description, !description.isEmpty {
            return description
        }
        return buoy.coordinateSummary(missingText: NSLocalizedString("buoy_coordinates_missing", comment: ""))
    }

    private var expandedBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let description = buoy.description, !description.isEmpty {
                detailRow(
                    label: NSLocalizedString("course_desc_label", comment: ""),
                    value: description
                )
            }

            detailRow(
                label: NSLocalizedString("gps_status_latitude", comment: ""),
                value: latitudeValue,
                valueColor: coordinateValueColor,
                accessibilityIdentifier: "buoy_row_latitude_\(buoy.id)"
            )

            detailRow(
                label: NSLocalizedString("gps_status_longitude", comment: ""),
                value: longitudeValue,
                valueColor: coordinateValueColor,
                accessibilityIdentifier: "buoy_row_longitude_\(buoy.id)"
            )

            detailRow(
                label: NSLocalizedString("buoy_last_updated_label", comment: ""),
                value: lastUpdatedText,
                accessibilityIdentifier: "buoy_row_last_updated_\(buoy.id)"
            )

            HStack(spacing: 10) {
                CourseOutlineTextIconButton(
                    titleKey: "course_position_label",
                    systemName: "mappin.and.ellipse",
                    action: onSetCoordinates
                )
                .accessibilityIdentifier("buoy_set_coordinates_button_\(buoy.id)")

                CourseCircularIconButton(systemName: "pencil", action: onEdit)
                    .accessibilityIdentifier("buoy_edit_button_\(buoy.id)")
            }
        }
    }

    private var lastUpdatedText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: buoy.lastUpdated)
    }

    private var latitudeValue: String {
        guard let lat = buoy.coordinate?.lat else { return "-" }
        return dmsCoordinate(lat, isLatitude: true)
    }

    private var longitudeValue: String {
        guard let lon = buoy.coordinate?.lon else { return "-" }
        return dmsCoordinate(lon, isLatitude: false)
    }

    private var coordinateValueColor: Color {
        buoy.coordinate == nil ? Theme.RaceManager.primaryColor : Theme.Colors.textPrimary
    }

    private func detailRow(
        label: String,
        value: String,
        valueColor: Color = Theme.Colors.textPrimary,
        accessibilityIdentifier: String? = nil
    ) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(AppFont.textStyle(.subheadline))
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(width: 96, alignment: .leading)

            Text(value)
                .font(AppFont.textStyle(.subheadline, weight: .medium))
                .foregroundStyle(valueColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier(accessibilityIdentifier ?? "")
        }
    }

    private func dmsCoordinate(_ value: Double, isLatitude: Bool) -> String {
        let hemisphere: String
        if isLatitude {
            hemisphere = value >= 0 ? "N" : "S"
        } else {
            hemisphere = value >= 0 ? "E" : "W"
        }

        let absValue = abs(value)
        let degrees = Int(absValue)
        let totalMinutes = (absValue - Double(degrees)) * 60.0
        let minutes = Int(totalMinutes)
        let seconds = (totalMinutes - Double(minutes)) * 60.0
        return String(format: "%d° %02d' %04.1f\" %@", degrees, minutes, seconds, hemisphere)
    }

}
