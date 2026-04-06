import SwiftUI

struct CourseTimelineView: View {
    let items: [CourseTimelineItem]
    var onPositionSelected: (CoursePositionSelection) -> Void = { _ in }

    @State private var activeIndex: Int? = nil

    var body: some View {
        Group {
            if items.isEmpty {
                EmptyView()
            } else {
                ScrollViewReader { proxy in
                    VStack(spacing: 0) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            CourseStepRow(
                                item: item,
                                isFirst: index == 0,
                                isLast: index == items.count - 1,
                                isActive: activeIndex == index,
                                onPositionSelected: onPositionSelected,
                                onTap: {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        activeIndex = index
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                        withAnimation {
                                            proxy.scrollTo(item.id, anchor: .center)
                                        }
                                    }
                                }
                            )
                            .id(item.id)
                        }
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 20)
                }
            }
        }
    }
}

private struct CourseStepRow: View {
    let item: CourseTimelineItem
    let isFirst: Bool
    let isLast: Bool
    let isActive: Bool
    let onPositionSelected: (CoursePositionSelection) -> Void
    let onTap: () -> Void

    @State private var activeSubIndex: Int?

    private var iconSize: CGFloat {
        isActive ? 30 : 24
    }

    private var symbolSize: CGFloat {
        isActive ? 14 : 11
    }

    private var markDotSize: CGFloat {
        isActive ? 10 : 7
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            stepRail

            VStack(alignment: .leading, spacing: 8) {
                Button(action: onTap) {
                    Text(item.name)
                        .font(AppFont.textStyle(.body, weight: isActive ? .bold : .medium))
                        .foregroundStyle(isActive ? Theme.Colors.brandPrimary : Theme.Colors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if isActive {
                    if item.type == .mark {
                        markDetail
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    } else if item.type == .start || item.type == .finish {
                        lineSubStepper
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    } else {
                        Text("detail placeholder")
                            .font(AppFont.textStyle(.subheadline))
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
            .padding(.vertical, 10)
        }
    }

    private var stepRail: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(isFirst ? Color.clear : Theme.Colors.brandPrimary.opacity(0.3))
                .frame(width: 2, height: 12)

            stepIcon
                .frame(width: iconSize, height: iconSize)

            if !isLast {
                Rectangle()
                    .fill(Theme.Colors.brandPrimary.opacity(0.3))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(width: 30, alignment: .top)
    }

    @ViewBuilder
    private var stepIcon: some View {
        switch item.status {
        case .final_:
            ZStack {
                Circle()
                    .fill(Theme.Colors.brandPrimary)
                Image(systemName: "checkmark")
                    .font(.system(size: symbolSize, weight: .bold))
                    .foregroundStyle(Theme.Colors.surfacePrimary)
            }
        case .preliminary:
            ZStack {
                Circle()
                    .fill(Theme.RaceManager.primaryColor)
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: symbolSize, weight: .bold))
                    .foregroundStyle(Theme.Colors.surfacePrimary)
            }
        case .none:
            switch item.type {
            case .start:
                ZStack {
                    Circle()
                        .fill(Theme.Colors.brandPrimary.opacity(isActive ? 1.0 : 0.7))
                    Image(systemName: "flag.fill")
                        .font(.system(size: symbolSize, weight: .bold))
                        .foregroundStyle(Theme.Colors.surfacePrimary)
                }
            case .finish:
                ZStack {
                    Circle()
                        .fill(Theme.Colors.brandPrimary.opacity(isActive ? 1.0 : 0.7))
                    Image(systemName: "flag.checkered")
                        .font(.system(size: symbolSize, weight: .bold))
                        .foregroundStyle(Theme.Colors.surfacePrimary)
                }
            case .mark:
                ZStack {
                    Circle()
                        .fill(Theme.Colors.surfacePrimary)
                    Circle()
                        .stroke(Theme.Colors.brandPrimary, lineWidth: 2)
                    Circle()
                        .fill(Theme.Colors.brandPrimary)
                        .frame(width: markDotSize, height: markDotSize)
                }
            }
        }
    }

    private var markDetail: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                if let description = item.description, !description.isEmpty {
                    detailRow(label: NSLocalizedString("course_desc_label", comment: ""), value: description)
                }

                if let rounding = item.roundingSide {
                    detailRow(
                        label: NSLocalizedString("course_rounding_label", comment: ""),
                        value: roundingLabel(for: rounding)
                    )
                }
                detailRow(
                    label: NSLocalizedString("race_status_label", comment: ""),
                    value: definitionStatusLabel(for: item.status),
                    valueColor: definitionStatusValueColor(for: item.status)
                )

                detailRow(
                    label: NSLocalizedString("gps_status_latitude", comment: ""),
                    value: latitudeDmsValue,
                    valueColor: coordinateValueColor,
                    lineLimit: 1,
                    labelWidth: 90
                )
                detailRow(
                    label: NSLocalizedString("gps_status_longitude", comment: ""),
                    value: longitudeDmsValue,
                    valueColor: coordinateValueColor,
                    lineLimit: 1,
                    labelWidth: 90
                )

                if let bearing = item.bearingToNextDeg, let distance = item.distanceToNextNm {
                    detailRow(
                        label: NSLocalizedString("course_to_next_mark_label", comment: ""),
                        value: "\(bearing) - \(distance)",
                        lineLimit: 1,
                        labelWidth: 90
                    )
                } else {
                    if let bearing = item.bearingToNextDeg {
                        detailRow(label: NSLocalizedString("course_bearing_to_next_label", comment: ""), value: bearing)
                    }

                    if let distance = item.distanceToNextNm {
                        detailRow(label: NSLocalizedString("course_distance_to_next_label", comment: ""), value: distance)
                    }
                }

                if let updatedAtLabel = item.updatedAtLabel {
                    detailRow(
                        label: NSLocalizedString("course_last_updated_label", comment: ""),
                        value: updatedAtLabel,
                        valueColor: Theme.Colors.textSecondary,
                        lineLimit: 1,
                        labelWidth: 90
                    )
                }
            }

            CoursePositionButton {
                onPositionSelected(.mark(markId: item.id))
            }
        }
    }

    private var latitudeDmsValue: String {
        guard let lat = item.markLat else { return "-" }
        return dmsCoordinate(lat, isLatitude: true)
    }

    private var longitudeDmsValue: String {
        guard let lon = item.markLon else { return "-" }
        return dmsCoordinate(lon, isLatitude: false)
    }

    private var coordinateValueColor: Color {
        item.status == .preliminary ? Theme.RaceManager.primaryColor : Theme.Colors.textPrimary
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

    private func detailRow(
        label: String,
        value: String,
        valueColor: Color = Theme.Colors.textPrimary,
        lineLimit: Int? = nil,
        labelWidth: CGFloat = 70
    ) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(AppFont.textStyle(.subheadline))
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(width: labelWidth, alignment: .leading)

            Text(value)
                .font(AppFont.textStyle(.subheadline, weight: .medium))
                .foregroundStyle(valueColor)
                .lineLimit(lineLimit)
        }
    }

    private func roundingLabel(for rounding: RoundingSide) -> String {
        switch rounding {
        case .port:
            return NSLocalizedString("course_rounding_port", comment: "")
        case .starboard:
            return NSLocalizedString("course_rounding_starboard", comment: "")
        case .gate:
            return NSLocalizedString("course_rounding_gate", comment: "")
        }
    }

    private func definitionStatusLabel(for status: DefinitionStatus) -> String {
        switch status {
        case .final_:
            return NSLocalizedString("course_definition_status_final", comment: "")
        case .preliminary:
            return NSLocalizedString("course_definition_status_preliminary", comment: "")
        case .none:
            return NSLocalizedString("course_definition_status_not_set", comment: "")
        }
    }

    private func definitionStatusValueColor(for status: DefinitionStatus) -> Color {
        status == .preliminary ? Theme.RaceManager.primaryColor : Theme.Colors.textPrimary
    }

    private var lineSubStepper: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let description = item.description, !description.isEmpty {
                detailRow(label: NSLocalizedString("course_desc_label", comment: ""), value: description)
            }

            if item.lineBearingLabel != nil || item.lineLengthLabel != nil {
                detailRow(
                    label: NSLocalizedString("course_line_label", comment: ""),
                    value: lineSummaryValue
                )
            }

            if let updatedAtLabel = item.updatedAtLabel {
                detailRow(
                    label: NSLocalizedString("course_last_updated_label", comment: ""),
                    value: updatedAtLabel,
                    valueColor: Theme.Colors.textSecondary,
                    lineLimit: 1,
                    labelWidth: 90
                )
            }

            VStack(spacing: 0) {
                LineEndRow(
                    title: NSLocalizedString("course_left_end", comment: ""),
                    latitude: item.lineLeftLat,
                    longitude: item.lineLeftLon,
                    status: item.status,
                    isActive: activeSubIndex == 0,
                    isFirst: true,
                    isLast: false,
                    onTap: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            activeSubIndex = activeSubIndex == 0 ? nil : 0
                        }
                    },
                    onPositionTap: {
                        if let selection = lineEndpointSelection(for: .left) {
                            onPositionSelected(selection)
                        }
                    }
                )

                LineEndRow(
                    title: NSLocalizedString("course_right_end", comment: ""),
                    latitude: item.lineRightLat,
                    longitude: item.lineRightLon,
                    status: item.status,
                    isActive: activeSubIndex == 1,
                    isFirst: false,
                    isLast: true,
                    onTap: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            activeSubIndex = activeSubIndex == 1 ? nil : 1
                        }
                    },
                    onPositionTap: {
                        if let selection = lineEndpointSelection(for: .right) {
                            onPositionSelected(selection)
                        }
                    }
                )
            }
            .padding(.top, 10)
            .padding(.leading, 4)
        }
    }

    private func lineEndpointSelection(for side: CourseEndpointSide) -> CoursePositionSelection? {
        switch item.type {
        case .start:
            return .startLineEndpoint(lineId: item.id, side: side)
        case .finish:
            return .finishLineEndpoint(lineId: item.id, side: side)
        case .mark:
            return nil
        }
    }

    private var lineSummaryValue: String {
        let bearing = item.lineBearingLabel ?? "-"
        let length = (item.lineLengthLabel ?? "-").replacingOccurrences(of: " ", with: "")
        return "\(bearing) - \(length)"
    }
}

private struct LineEndRow: View {
    let title: String
    let latitude: Double?
    let longitude: Double?
    let status: DefinitionStatus
    let isActive: Bool
    let isFirst: Bool
    let isLast: Bool
    let onTap: () -> Void
    let onPositionTap: () -> Void

    private var nodeSize: CGFloat {
        isActive ? 22 : 18
    }

    private var dotSize: CGFloat {
        isActive ? 7 : 5
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            subRail

            VStack(alignment: .leading, spacing: 4) {
                Button(action: onTap) {
                    Text(title)
                        .font(AppFont.textStyle(.subheadline, weight: isActive ? .bold : .medium))
                        .foregroundStyle(isActive ? Theme.Colors.brandPrimary : Theme.Colors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if isActive {
                    VStack(alignment: .leading, spacing: 8) {
                        detailRow(
                            label: NSLocalizedString("gps_status_latitude", comment: ""),
                            value: latitudeDmsValue,
                            valueColor: coordinateValueColor,
                            lineLimit: 1,
                            labelWidth: 90
                        )

                        detailRow(
                            label: NSLocalizedString("gps_status_longitude", comment: ""),
                            value: longitudeDmsValue,
                            valueColor: coordinateValueColor,
                            lineLimit: 1,
                            labelWidth: 90
                        )

                        CoursePositionButton(action: onPositionTap)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.vertical, 10)
        }
    }

    private var coordinateValueColor: Color {
        status == .preliminary ? Theme.RaceManager.primaryColor : Theme.Colors.textPrimary
    }

    private var latitudeDmsValue: String {
        guard let latitude else { return "-" }
        return dmsCoordinate(latitude, isLatitude: true)
    }

    private var longitudeDmsValue: String {
        guard let longitude else { return "-" }
        return dmsCoordinate(longitude, isLatitude: false)
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

    private func detailRow(
        label: String,
        value: String,
        valueColor: Color = Theme.Colors.textPrimary,
        lineLimit: Int? = nil,
        labelWidth: CGFloat = 70
    ) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(AppFont.textStyle(.subheadline))
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(width: labelWidth, alignment: .leading)

            Text(value)
                .font(AppFont.textStyle(.subheadline, weight: .medium))
                .foregroundStyle(valueColor)
                .lineLimit(lineLimit)
        }
    }

    private var subRail: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(isFirst ? Color.clear : Theme.Colors.brandPrimary.opacity(0.25))
                .frame(width: 1.5, height: 12)

            ZStack {
                Circle()
                    .fill(Theme.Colors.surfacePrimary)
                Circle()
                    .stroke(Theme.Colors.brandPrimary, lineWidth: 1.5)
                Circle()
                    .fill(Theme.Colors.brandPrimary)
                    .frame(width: dotSize, height: dotSize)
            }
            .frame(width: nodeSize, height: nodeSize)

            if !isLast {
                Rectangle()
                    .fill(Theme.Colors.brandPrimary.opacity(0.25))
                    .frame(width: 1.5)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(width: 22)
    }
}

private struct CoursePositionButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Text("course_position_label")
                    .font(Theme.Typography.button)

                HStack {
                    Spacer()
                    Image(systemName: "mappin.and.ellipse")
                        .font(Theme.Typography.iconMedium)
                        .padding(.trailing, Theme.Sizing.primaryButtonHeight / 3)
                }
            }
            .frame(maxWidth: .infinity, minHeight: Theme.Sizing.primaryButtonHeight)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.RaceManager.primaryColor)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Sizing.primaryButtonHeight / 2, style: .continuous)
                .stroke(Theme.RaceManager.primaryColor, lineWidth: 1.5)
        )
        .padding(.horizontal)
    }
}

#Preview {
    CourseTimelineView(
        items: [
            CourseTimelineItem(
                id: "start",
                name: "Start Line",
                description: "",
                type: .start,
                status: .none,
                markLat: nil,
                markLon: nil,
                roundingSide: nil,
                bearingToNextRad: nil,
                distanceToNextM: nil,
                lineLengthM: 120,
                lineBearingDeg: 270,
                lineLeftLat: 60.17,
                lineLeftLon: 24.94,
                lineRightLat: 60.16,
                lineRightLon: 24.95,
                updatedAt: Date()
            ),
            CourseTimelineItem(
                id: "mark-1",
                name: "Mark 1",
                description: "Windward",
                type: .mark,
                status: .none,
                markLat: 60.175,
                markLon: 24.97,
                roundingSide: .port,
                bearingToNextRad: 1.2,
                distanceToNextM: 1852,
                lineLengthM: nil,
                lineBearingDeg: nil,
                lineLeftLat: nil,
                lineLeftLon: nil,
                lineRightLat: nil,
                lineRightLon: nil,
                updatedAt: Date()
            ),
            CourseTimelineItem(
                id: "finish",
                name: "Finish Line",
                description: "",
                type: .finish,
                status: .final_,
                markLat: nil,
                markLon: nil,
                roundingSide: nil,
                bearingToNextRad: nil,
                distanceToNextM: nil,
                lineLengthM: 100,
                lineBearingDeg: 90,
                lineLeftLat: 60.18,
                lineLeftLon: 24.98,
                lineRightLat: 60.19,
                lineRightLon: 24.99,
                updatedAt: Date()
            ),
            CourseTimelineItem(
                id: "mark-2",
                name: "Mark 2",
                description: "Leeward",
                type: .mark,
                status: .preliminary,
                markLat: 60.165,
                markLon: 24.99,
                roundingSide: .starboard,
                bearingToNextRad: 0.4,
                distanceToNextM: 926,
                lineLengthM: nil,
                lineBearingDeg: nil,
                lineLeftLat: nil,
                lineLeftLon: nil,
                lineRightLat: nil,
                lineRightLon: nil,
                updatedAt: Date()
            )
        ]
    )
}
