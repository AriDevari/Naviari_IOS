import SwiftUI

enum Theme {
    enum Colors {
        static let brandPrimary = Color(red: 0 / 255, green: 136 / 255, blue: 255 / 255)
        static let brandPrimaryMuted = brandPrimary.opacity(0.15)

        static let error = Color.red
        static let destructive = Color.red

        static let statusInactive = Color.gray
        static let statusGreen = Color.green
        static let statusYellow = Color.orange
        static let statusRed = Color.red

        static let textPrimary = Color.primary
        static let textSecondary = Color.secondary

        static let surfacePrimary = Color(.systemBackground)
        static let surfaceSecondary = Color(.secondarySystemBackground)

        static func statusBlend(normalized: Double) -> Color {
            let clamped = min(max(normalized, 0), 1)
            let minHue: Double = 0.33
            let maxHue: Double = 0.14
            let hue = minHue - (minHue - maxHue) * clamped
            return Color(hue: hue, saturation: 0.9, brightness: 0.9)
        }
    }

    enum Typography {
        static let button = AppFont.fixed(21, weight: .semibold)
        static let headline = AppFont.textStyle(.headline)
        static let subheadline = AppFont.textStyle(.subheadline)

        static let iconMedium = AppFont.fixed(24)
        static let iconLarge = AppFont.fixed(28)
        static let metricValue = AppFont.fixed(48, weight: .semibold)
    }

    enum CornerRadius {
        static let rowCard: CGFloat = 12
        static let materialCard: CGFloat = 18
    }

    enum Sizing {
        static let primaryButtonHeight: CGFloat = 66
        static let floatingButtonDiameter: CGFloat = 62
    }

    enum Spacing {
        static let floatingInset: CGFloat = 24
    }

    enum Effects {
        static let logoShadowRadius: CGFloat = 4

        static let floatingStatusShadowOpacity: Double = 0.5
        static let floatingStatusShadowRadius: CGFloat = 8
        static let floatingStatusShadowYOffset: CGFloat = 4

        static let avatarBorderOpacity: Double = 0.4
        static let avatarBorderLineWidth: CGFloat = 1

        static let statusPulseStrokeOpacity: Double = 0.55
        static let statusPulseLineWidth: CGFloat = 2
    }
}
