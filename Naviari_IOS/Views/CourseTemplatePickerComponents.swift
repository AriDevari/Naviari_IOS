import SwiftUI

func courseTemplateDisplayName(_ template: RaceCourse) -> String {
    let trimmed = template.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return trimmed.isEmpty
        ? NSLocalizedString("start_detail_course_template_unnamed", comment: "")
        : trimmed
}

func courseTemplateLengthLabel(_ template: RaceCourse) -> String? {
    if let nauticalMiles = template.total_length_nm, nauticalMiles.isFinite {
        return String(
            format: NSLocalizedString("start_detail_course_template_length_nm_format", comment: ""),
            nauticalMiles
        )
    }
    if let meters = template.total_length_m, meters.isFinite {
        if meters >= 1000 {
            return String(
                format: NSLocalizedString("start_detail_course_template_length_km_format", comment: ""),
                meters / 1000
            )
        }
        return String(
            format: NSLocalizedString("start_detail_course_template_length_m_format", comment: ""),
            meters
        )
    }
    return nil
}

func courseTemplateSelectionTitle(_ template: RaceCourse) -> String {
    let name = courseTemplateDisplayName(template)
    guard let lengthLabel = courseTemplateLengthLabel(template) else {
        return name
    }
    return "\(name) · \(lengthLabel)"
}

struct CourseTemplatePickerButton: View {
    let isEnabled: Bool
    let isExpanded: Bool
    let isCopying: Bool
    let titleKey: LocalizedStringKey
    let accessibilityIdentifier: String
    let onTap: () -> Void

    var body: some View {
        SplitActionButton(
            variant: .outlined(accentColor: Theme.RaceManager.primaryColor),
            isEnabled: isEnabled,
            isExpanded: isExpanded,
            primaryAccessibilityIdentifier: accessibilityIdentifier,
            secondaryAccessibilityIdentifier: "\(accessibilityIdentifier)_disclosure",
            onPrimaryTap: onTap,
            onSecondaryTap: onTap
        ) {
            HStack {
                Spacer()
                if isCopying {
                    ProgressView()
                        .tint(Theme.RaceManager.primaryColor)
                } else {
                    Text(titleKey)
                        .font(Theme.Typography.button)
                        .multilineTextAlignment(.center)
                }
                Spacer()
            }
        }
    }
}

struct CourseTemplatePickerDropdown: View {
    let templates: [RaceCourse]
    let optionIdentifierPrefix: String
    let onTemplateSelected: (RaceCourse) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(templates.enumerated()), id: \.element.id) { index, template in
                Button {
                    onTemplateSelected(template)
                } label: {
                    HStack(alignment: .center, spacing: 12) {
                        Text(courseTemplateSelectionTitle(template))
                            .font(AppFont.textStyle(.body))
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, minHeight: Theme.Sizing.primaryButtonHeight, alignment: .leading)
                    .background(Theme.Colors.surfacePrimary)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("\(optionIdentifierPrefix)\(template.id)")

                if index < templates.count - 1 {
                    Divider()
                        .padding(.leading, 16)
                }
            }
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
}

func buoySelectionTitle(_ buoy: BuoyRecord) -> String {
    buoy.name.trimmingCharacters(in: .whitespacesAndNewlines)
}

struct CourseBuoyPickerDropdown: View {
    let buoys: [BuoyRecord]
    let optionIdentifierPrefix: String
    let onBuoySelected: (BuoyRecord) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(buoys.enumerated()), id: \.element.id) { index, buoy in
                Button {
                    onBuoySelected(buoy)
                } label: {
                    HStack(alignment: .center, spacing: 12) {
                        Text(buoySelectionTitle(buoy))
                            .font(AppFont.textStyle(.body))
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, minHeight: Theme.Sizing.primaryButtonHeight, alignment: .leading)
                    .background(Theme.Colors.surfacePrimary)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("\(optionIdentifierPrefix)\(buoy.id)")

                if index < buoys.count - 1 {
                    Divider()
                        .padding(.leading, 16)
                }
            }
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
}