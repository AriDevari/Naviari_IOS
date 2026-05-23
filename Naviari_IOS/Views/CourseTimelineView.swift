import SwiftUI

struct CourseTimelineView: View {
    let items: [CourseTimelineItem]
    @Binding var activeItemId: String?
    @Binding var activeSubIndexByItemId: [String: Int]
    var horizontalPadding: CGFloat = 20
    var onPositionSelected: (CoursePositionSelection) -> Void = { _ in }
    var onEditSelected: ((String) -> Void)? = nil
    var onAddAfter: ((String) -> Void)? = nil

    var body: some View {
        Group {
            if items.isEmpty {
                EmptyView()
            } else {
                ScrollViewReader { proxy in
                    VStack(spacing: Theme.CourseTimeline.rowGap) {
                        ForEach(items) { item in
                            CourseStepRow(
                                item: item,
                                isActive: activeItemId == item.id,
                                activeSubIndex: subIndexBinding(for: item.id),
                                onPositionSelected: onPositionSelected,
                                onEditSelected: onEditSelected,
                                onTap: {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        activeItemId = activeItemId == item.id ? nil : item.id
                                    }
                                    scrollToActiveItem(using: proxy)
                                }
                            )
                            .id(item.id)

                            if activeItemId == item.id && item.type != .finish {
                                Button(action: { onAddAfter?(item.id) }) {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .fill(Theme.RaceManager.primaryColor)
                                            Image(systemName: "plus")
                                                .font(.system(size: 22, weight: .semibold))
                                                .foregroundStyle(.white)
                                        }
                                        .frame(width: Theme.CourseTimeline.iconDiameter, height: Theme.CourseTimeline.iconDiameter)
                                        .shadow(color: Theme.RaceManager.primaryColor.opacity(0.3), radius: 3, x: 0, y: 2)
                                        Text(NSLocalizedString("course_add_mark_button", comment: ""))
                                            .font(.system(size: 12, weight: .heavy))
                                            .kerning(0.6)
                                            .foregroundStyle(Theme.RaceManager.primaryColor)
                                        Spacer()
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("course_add_mark_button")
                            }
                        }
                    }
                    .background(alignment: .leading) {
                        Rectangle()
                            .fill(Theme.Colors.brandPrimary.opacity(Theme.CourseTimeline.railOpacity))
                            .frame(width: 2)
                            .frame(maxHeight: .infinity)
                            .padding(.top, Theme.CourseTimeline.iconDiameter / 2)
                            .padding(.bottom, Theme.CourseTimeline.iconDiameter / 2)
                            .padding(.leading, (Theme.CourseTimeline.iconDiameter / 2) - 1)
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, horizontalPadding)
                    .onAppear {
                        scrollToActiveItem(using: proxy)
                    }
                    .onChange(of: activeItemId) { _, _ in
                        scrollToActiveItem(using: proxy)
                    }
                    .onChange(of: items.map(\.id)) { _, _ in
                        scrollToActiveItem(using: proxy)
                    }
                }
            }
        }
    }

    private func subIndexBinding(for itemId: String) -> Binding<Int?> {
        Binding<Int?>(
            get: { activeSubIndexByItemId[itemId] },
            set: { newValue in
                if let newValue {
                    activeSubIndexByItemId[itemId] = newValue
                } else {
                    activeSubIndexByItemId.removeValue(forKey: itemId)
                }
            }
        )
    }

    private func scrollToActiveItem(using proxy: ScrollViewProxy) {
        guard let activeItemId else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation {
                proxy.scrollTo(activeItemId, anchor: .center)
            }
        }
    }
}

private struct CourseStepRow: View {
    let item: CourseTimelineItem
    let isActive: Bool
    @Binding var activeSubIndex: Int?
    let onPositionSelected: (CoursePositionSelection) -> Void
    let onEditSelected: ((String) -> Void)?
    let onTap: () -> Void

    private var iconSize: CGFloat {
        Theme.CourseTimeline.iconDiameter
    }

    private var symbolSize: CGFloat {
        14
    }

    private var markDotSize: CGFloat {
        7
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

            stepIcon
                .frame(width: iconSize, height: iconSize)
                .offset(x: -(Theme.CourseTimeline.iconDiameter / 2))
        }
        .padding(.leading, cardLeadingOffset)
    }

    private var headerButton: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(AppFont.textStyle(.body, weight: isActive ? .bold : .medium))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if !isActive, let collapsedSubtitle {
                        Text(collapsedSubtitle)
                            .font(AppFont.textStyle(.footnote, weight: .medium))
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .clipped()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textSecondary.opacity(0.5))
                    .rotationEffect(.degrees(isActive ? 180 : 0))
                    .animation(.easeOut(duration: 0.2), value: isActive)
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var expandedSeparator: some View {
        Rectangle()
            .stroke(Theme.CourseTimeline.expandedSeparatorColor, style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
            .frame(height: 1)
            .padding(.top, 6)
    }

    @ViewBuilder
    private var expandedBody: some View {
        if item.type == .mark {
            markDetail
        } else if item.type == .start || item.type == .finish {
            lineSubStepper
        }
    }

    private var collapsedSubtitle: String? {
        guard let description = item.description?.trimmingCharacters(in: .whitespacesAndNewlines),
              !description.isEmpty else { return nil }
        return description
    }

    @ViewBuilder
    private var stepIcon: some View {
        CourseStepStatusIcon(
            itemType: item.type,
            status: item.status,
            diameter: iconSize,
            symbolSize: symbolSize,
            markDotSize: markDotSize,
            ringLineWidth: 2,
            addWhiteBackdrop: true
        )
    }

    private var markDetail: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let description = item.description?.trimmingCharacters(in: .whitespacesAndNewlines),
               !description.isEmpty {
                Text(description)
                    .font(AppFont.textStyle(.footnote, weight: .medium))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            statusRow

            if let rounding = item.roundingSide {
                detailRow(
                    label: NSLocalizedString("course_rounding_label", comment: ""),
                    value: roundingLabel(for: rounding),
                    labelWidth: 90
                )
            }

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

            if let toNextValue {
                detailRow(
                    label: NSLocalizedString("course_to_next_mark_label", comment: ""),
                    value: toNextValue,
                    lineLimit: 1,
                    labelWidth: 90
                )
            }

            HStack(spacing: 10) {
                CoursePositionButton {
                    onPositionSelected(.mark(markId: item.id))
                }
                CourseEditButton { onEditSelected?(item.id) }
            }
        }
    }

    private var statusValueLabel: String {
        switch item.status {
        case .final_:
            return NSLocalizedString("course_definition_status_final", comment: "")
        case .preliminary:
            return NSLocalizedString("course_definition_status_preliminary", comment: "")
        case .none:
            return NSLocalizedString("course_definition_status_not_set", comment: "")
        }
    }

    private var statusRow: some View {
        detailRow(
            label: NSLocalizedString("race_status_label", comment: ""),
            value: statusValueLabel,
            lineLimit: 1,
            labelWidth: 90
        )
    }

    private var toNextValue: String? {
        guard let bearingToNextRad = item.bearingToNextRad,
              let distanceToNextM = item.distanceToNextM else {
            return nil
        }

        let bearingDeg = bearingToNextRad * 180.0 / .pi
        let distanceNm = distanceToNextM / 1852.0
        let distanceFormatted = String(format: "%.1f", distanceNm)
        return "\(Int(round(bearingDeg)))° · \(distanceFormatted) nm"
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

    private func normalizedLineStatus(_ rawStatus: String?) -> String {
        rawStatus?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
    }

    private func endpointStatus(for side: CourseEndpointSide) -> DefinitionStatus {
        switch normalizedLineStatus(item.rawStatus) {
        case "leftset":
            return side == .left ? .final_ : .preliminary
        case "rightset":
            return side == .right ? .final_ : .preliminary
        default:
            return item.status
        }
    }

    private var lineSubStepper: some View {
        VStack(alignment: .leading, spacing: 10) {
            statusRow

            if item.lineBearingLabel != nil || item.lineLengthLabel != nil {
                detailRow(
                    label: NSLocalizedString("course_line_label", comment: ""),
                    value: lineSummaryValue
                )
            }

            Text(NSLocalizedString("course_left_end", comment: ""))
                .font(AppFont.textStyle(.body, weight: .bold))
                .foregroundStyle(Theme.Colors.textPrimary)
                .padding(.top, 8)

            detailRow(
                label: NSLocalizedString("gps_status_latitude", comment: ""),
                value: item.lineLeftLat.map { dmsCoordinate($0, isLatitude: true) } ?? "-",
                lineLimit: 1,
                labelWidth: 90
            )
            detailRow(
                label: NSLocalizedString("gps_status_longitude", comment: ""),
                value: item.lineLeftLon.map { dmsCoordinate($0, isLatitude: false) } ?? "-",
                lineLimit: 1,
                labelWidth: 90
            )
            HStack(spacing: 10) {
                CoursePositionButton {
                    if let selection = lineEndpointSelection(for: .left) {
                        onPositionSelected(selection)
                    }
                }
                CourseEditButton { onEditSelected?(item.id) }
            }

            Text(NSLocalizedString("course_right_end", comment: ""))
                .font(AppFont.textStyle(.body, weight: .bold))
                .foregroundStyle(Theme.Colors.textPrimary)
                .padding(.top, 18)

            detailRow(
                label: NSLocalizedString("gps_status_latitude", comment: ""),
                value: item.lineRightLat.map { dmsCoordinate($0, isLatitude: true) } ?? "-",
                lineLimit: 1,
                labelWidth: 90
            )
            detailRow(
                label: NSLocalizedString("gps_status_longitude", comment: ""),
                value: item.lineRightLon.map { dmsCoordinate($0, isLatitude: false) } ?? "-",
                lineLimit: 1,
                labelWidth: 90
            )
            HStack(spacing: 10) {
                CoursePositionButton {
                    if let selection = lineEndpointSelection(for: .right) {
                        onPositionSelected(selection)
                    }
                }
                CourseEditButton { onEditSelected?(item.id) }
            }
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
        let components: [String] = [item.lineBearingLabel, item.lineLengthLabel].compactMap { value in
            guard let value, !value.isEmpty else { return nil }
            return value
        }
        guard !components.isEmpty else { return "-" }
        return components.joined(separator: " · ")
    }
}

private struct CourseEditButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "pencil")
                .font(.system(size: 22, weight: .medium))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.RaceManager.primaryColor)
        .frame(width: Theme.Sizing.primaryButtonHeight, height: Theme.Sizing.primaryButtonHeight)
        .overlay(
            Circle()
                .stroke(Theme.RaceManager.primaryColor, lineWidth: 1.5)
        )
    }
}

private struct CourseStatusChip: View {
    let status: DefinitionStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.system(size: 16))
                .foregroundStyle(foregroundColor)

            Text(labelText)
                .font(AppFont.textStyle(.subheadline, weight: .bold))
                .foregroundStyle(foregroundColor)
        }
        .padding(.leading, 10)
        .padding(.trailing, 12)
        .padding(.vertical, 4)
        .background(backgroundColor)
        .clipShape(Capsule())
    }

    private var iconName: String {
        switch status {
        case .final_:
            return "checkmark.circle.fill"
        case .preliminary:
            return "clock.arrow.circlepath"
        case .none:
            return "circle"
        }
    }

    private var backgroundColor: Color {
        switch status {
        case .final_:
            return Theme.CourseTimeline.chipFinalBackground
        case .preliminary:
            return Theme.CourseTimeline.chipPrelimBackground
        case .none:
            return Theme.CourseTimeline.chipNoneBackground
        }
    }

    private var foregroundColor: Color {
        switch status {
        case .final_:
            return Theme.CourseTimeline.chipFinalForeground
        case .preliminary:
            return Theme.CourseTimeline.chipPrelimForeground
        case .none:
            return Theme.CourseTimeline.chipNoneForeground
        }
    }

    private var labelText: String {
        switch status {
        case .final_:
            return NSLocalizedString("course_definition_status_final", comment: "")
        case .preliminary:
            return NSLocalizedString("course_definition_status_preliminary", comment: "")
        case .none:
            return NSLocalizedString("course_definition_status_not_set", comment: "")
        }
    }
}

private struct CourseStepStatusIcon: View {
    let itemType: CourseMarkType
    let status: DefinitionStatus
    let diameter: CGFloat
    let symbolSize: CGFloat
    let markDotSize: CGFloat
    let ringLineWidth: CGFloat
    let addWhiteBackdrop: Bool

    private var innerDiameter: CGFloat {
        addWhiteBackdrop ? max(0, diameter - 4) : diameter
    }

    var body: some View {
        ZStack {
            if addWhiteBackdrop {
                Circle()
                    .fill(Theme.Colors.surfacePrimary)
            }

            iconForeground
        }
    }

    @ViewBuilder
    private var iconForeground: some View {
        switch status {
        case .final_:
            ZStack {
                Circle()
                    .fill(Theme.Colors.brandPrimary)
                    .frame(width: innerDiameter, height: innerDiameter)
                Image(systemName: "checkmark")
                    .font(.system(size: symbolSize, weight: .bold))
                    .foregroundStyle(Theme.Colors.surfacePrimary)
            }
        case .preliminary:
            ZStack {
                Circle()
                    .fill(Theme.RaceManager.primaryColor)
                    .frame(width: innerDiameter, height: innerDiameter)
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: symbolSize, weight: .bold))
                    .foregroundStyle(Theme.Colors.surfacePrimary)
            }
        case .none:
            switch itemType {
            case .start:
                ZStack {
                    Circle()
                        .fill(Theme.Colors.brandPrimary)
                        .frame(width: innerDiameter, height: innerDiameter)
                    Image(systemName: "flag.fill")
                        .font(.system(size: symbolSize, weight: .bold))
                        .foregroundStyle(Theme.Colors.surfacePrimary)
                }
            case .finish:
                ZStack {
                    Circle()
                        .fill(Theme.Colors.brandPrimary)
                        .frame(width: innerDiameter, height: innerDiameter)
                    Image(systemName: "flag.checkered")
                        .font(.system(size: symbolSize, weight: .bold))
                        .foregroundStyle(Theme.Colors.surfacePrimary)
                }
            case .mark:
                ZStack {
                    Circle()
                        .fill(Theme.Colors.surfacePrimary)
                        .frame(width: innerDiameter, height: innerDiameter)
                    Circle()
                        .stroke(Theme.Colors.brandPrimary, lineWidth: ringLineWidth)
                        .frame(width: innerDiameter, height: innerDiameter)
                    Circle()
                        .fill(Theme.Colors.brandPrimary)
                        .frame(width: markDotSize, height: markDotSize)
                }
            }
        }
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
    }
}

private struct CourseTimelinePreviewHost: View {
    @State private var activeItemId: String? = nil
    @State private var activeSubIndexByItemId: [String: Int] = [:]

    var body: some View {
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
            ],
            activeItemId: $activeItemId,
            activeSubIndexByItemId: $activeSubIndexByItemId
        )
    }
}

#Preview {
    CourseTimelinePreviewHost()
}
