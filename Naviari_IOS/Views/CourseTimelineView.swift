import SwiftUI

struct CourseTimelineView: View {
    let items: [CourseTimelineItem]

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
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                if let description = item.description, !description.isEmpty {
                    detailRow(label: NSLocalizedString("course_desc_label", comment: ""), value: description)
                }

                if let rounding = item.roundingSide {
                    detailRow(
                        label: NSLocalizedString("course_rounding_label", comment: ""),
                        value: roundingLabel(for: rounding),
                        valueColor: roundingColor(for: rounding)
                    )
                }

                if let coordinate = item.coordinateLabel {
                    detailRow(label: NSLocalizedString("course_position_label", comment: ""), value: coordinate, lineLimit: 1)
                }

                if item.bearingToNextRad != nil || item.distanceToNextM != nil {
                    Divider()
                        .padding(.vertical, 4)
                }

                if let bearing = item.bearingToNextDeg {
                    detailRow(label: NSLocalizedString("course_bearing_to_next_label", comment: ""), value: bearing)
                }

                if let distance = item.distanceToNextNm {
                    detailRow(label: NSLocalizedString("course_distance_to_next_label", comment: ""), value: distance)
                }

                if let updatedAtLabel = item.updatedAtLabel {
                    Text(updatedAtLabel)
                        .font(AppFont.textStyle(.caption2))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .padding(.top, 2)
                }
            }

            Spacer(minLength: 0)

            Button(action: {}) {
                Image(systemName: "mappin.and.ellipse.circle.fill")
                    .font(.system(size: 44))
                    .modifier(CoordinateIconStyle(status: item.status))
                    .padding(.top, 4)
            }
            .buttonStyle(.plain)
        }
    }

    private func detailRow(
        label: String,
        value: String,
        valueColor: Color = Theme.Colors.textPrimary,
        lineLimit: Int? = nil
    ) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(AppFont.textStyle(.subheadline))
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(width: 70, alignment: .leading)

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

    private func roundingColor(for rounding: RoundingSide) -> Color {
        switch rounding {
        case .port:
            return Theme.CourseTimeline.roundingPort
        case .starboard:
            return Theme.CourseTimeline.roundingStarboard
        case .gate:
            return Theme.CourseTimeline.roundingGate
        }
    }

    private var lineSubStepper: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let description = item.description, !description.isEmpty {
                detailRow(label: NSLocalizedString("course_desc_label", comment: ""), value: description)
            }

            if let bearing = item.lineBearingLabel {
                detailRow(label: NSLocalizedString("course_line_bearing_label", comment: ""), value: bearing)
            }

            if let length = item.lineLengthLabel {
                detailRow(label: NSLocalizedString("course_line_length_label", comment: ""), value: length)
            }

            if let updatedAtLabel = item.updatedAtLabel {
                Text(updatedAtLabel)
                    .font(AppFont.textStyle(.caption2))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .padding(.top, 2)
            }

            VStack(spacing: 0) {
                LineEndRow(
                    title: NSLocalizedString("course_left_end", comment: ""),
                    coordinateLabel: item.lineLeftCoordinateLabel,
                    status: item.status,
                    isActive: activeSubIndex == 0,
                    isFirst: true,
                    isLast: false,
                    onTap: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            activeSubIndex = activeSubIndex == 0 ? nil : 0
                        }
                    }
                )

                LineEndRow(
                    title: NSLocalizedString("course_right_end", comment: ""),
                    coordinateLabel: item.lineRightCoordinateLabel,
                    status: item.status,
                    isActive: activeSubIndex == 1,
                    isFirst: false,
                    isLast: true,
                    onTap: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            activeSubIndex = activeSubIndex == 1 ? nil : 1
                        }
                    }
                )
            }
            .padding(.top, 10)
            .padding(.leading, 4)
        }
    }
}

private struct LineEndRow: View {
    let title: String
    let coordinateLabel: String?
    let status: DefinitionStatus
    let isActive: Bool
    let isFirst: Bool
    let isLast: Bool
    let onTap: () -> Void

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
                    HStack(alignment: .top) {
                        HStack(spacing: 8) {
                            Text(NSLocalizedString("course_position_label", comment: ""))
                                .font(AppFont.textStyle(.footnote))
                                .foregroundStyle(Theme.Colors.textSecondary)
                                .frame(width: 55, alignment: .leading)

                            Text(coordinateLabel ?? NSLocalizedString("course_position_not_set", comment: ""))
                                .font(AppFont.textStyle(.footnote, weight: .medium))
                                .foregroundStyle(Theme.Colors.textPrimary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 0)

                        Button(action: {}) {
                            Image(systemName: "mappin.and.ellipse.circle.fill")
                                .font(.system(size: 36))
                                .modifier(CoordinateIconStyle(status: status))
                        }
                        .buttonStyle(.plain)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.vertical, 6)
        }
    }

    private var subRail: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(isFirst ? Color.clear : Theme.Colors.brandPrimary.opacity(0.25))
                .frame(width: 1.5)
                .frame(minHeight: 8)

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

private struct CoordinateIconStyle: ViewModifier {
    let status: DefinitionStatus

    func body(content: Content) -> some View {
        switch status {
        case .final_:
            content
                .foregroundStyle(Theme.RaceManager.primaryColor, Theme.Colors.surfacePrimary)
                .overlay(
                    Circle().stroke(Theme.RaceManager.primaryColor, lineWidth: 1.5)
                )
        case .preliminary, .none:
            content
                .foregroundStyle(Theme.CourseTimeline.iconForeground, Theme.RaceManager.primaryColor)
        }
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
