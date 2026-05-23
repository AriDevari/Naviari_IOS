import SwiftUI

struct SplitActionButton<Label: View>: View {
    enum Variant {
        case outlined(accentColor: Color)

        var borderColor: Color {
            switch self {
            case let .outlined(accentColor):
                return accentColor
            }
        }

        var foregroundColor: Color {
            switch self {
            case let .outlined(accentColor):
                return accentColor
            }
        }

        var backgroundColor: Color {
            switch self {
            case .outlined:
                return .clear
            }
        }
    }

    let variant: Variant
    let isEnabled: Bool
    let isExpanded: Bool
    let primaryAccessibilityIdentifier: String?
    let secondaryAccessibilityIdentifier: String?
    let onPrimaryTap: () -> Void
    let onSecondaryTap: () -> Void
    let label: () -> Label

    init(
        variant: Variant,
        isEnabled: Bool = true,
        isExpanded: Bool = false,
        primaryAccessibilityIdentifier: String? = nil,
        secondaryAccessibilityIdentifier: String? = nil,
        onPrimaryTap: @escaping () -> Void,
        onSecondaryTap: @escaping () -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.variant = variant
        self.isEnabled = isEnabled
        self.isExpanded = isExpanded
        self.primaryAccessibilityIdentifier = primaryAccessibilityIdentifier
        self.secondaryAccessibilityIdentifier = secondaryAccessibilityIdentifier
        self.onPrimaryTap = onPrimaryTap
        self.onSecondaryTap = onSecondaryTap
        self.label = label
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: Theme.Sizing.primaryButtonHeight / 2,
            style: .continuous
        )
    }

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onPrimaryTap) {
                label()
                    .frame(maxWidth: .infinity, minHeight: Theme.Sizing.primaryButtonHeight)
                    .padding(.horizontal, 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
            .accessibilityIdentifier(primaryAccessibilityIdentifier ?? "")

            Rectangle()
                .fill(variant.borderColor.opacity(isEnabled ? 1.0 : 0.45))
                .frame(width: 1)
                .padding(.vertical, 10)

            Button(action: onSecondaryTap) {
                Image(systemName: "chevron.down")
                    .font(AppFont.fixed(20, weight: .semibold))
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .frame(width: Theme.Sizing.primaryButtonHeight, height: Theme.Sizing.primaryButtonHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
            .accessibilityIdentifier(secondaryAccessibilityIdentifier ?? "")
        }
        .foregroundStyle(variant.foregroundColor)
        .background(variant.backgroundColor)
        .clipShape(shape)
        .overlay(
            shape.stroke(variant.borderColor.opacity(isEnabled ? 1.0 : 0.45), lineWidth: 1.5)
        )
        .opacity(isEnabled ? 1.0 : 0.6)
        .animation(.easeInOut(duration: 0.18), value: isExpanded)
    }
}