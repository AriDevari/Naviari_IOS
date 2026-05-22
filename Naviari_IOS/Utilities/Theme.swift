import SwiftUI

enum Theme {
    enum Colors {
        static let brandPrimary = Color(red: 0 / 255, green: 136 / 255, blue: 255 / 255)
        static let brandPrimaryMuted = brandPrimary.opacity(0.15)
        /// Brand blue (#0088FF) — same as brandPrimary; named alias for segmented control "Final" state.
        static let brandBlue = Color(red: 0 / 255, green: 136 / 255, blue: 255 / 255)
        /// Brand navy (#0A2946) — used for rounding segmented control selected state.
        static let brandNavy = Color(red: 10 / 255, green: 41 / 255, blue: 70 / 255)

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
        static let secondaryButtonHeight: CGFloat = 48
        static let floatingButtonDiameter: CGFloat = 62
    }

    enum Spacing {
        static let floatingInset: CGFloat = 24
    }

    enum RaceManager {
        static let primaryColor = Color(red: 255 / 255, green: 0 / 255, blue: 136 / 255)
        static let primaryColorMuted = primaryColor.opacity(0.15)
        static let iconName = "gearshape"
    }

    enum CourseTimeline {
        static let roundingPort = Color.red
        static let roundingStarboard = Color.green
        static let roundingGate = Color.orange
        static let iconForeground = Color.white
        static let cardBorderDefault = Color(red: 239 / 255, green: 239 / 255, blue: 242 / 255)
        static let cardBorderOpen = Color(red: 214 / 255, green: 215 / 255, blue: 220 / 255)
        static let cardPaddingLeading: CGFloat = 28
        static let cardPaddingOther: CGFloat = 14
        static let iconDiameter: CGFloat = 34
        static let railOpacity: Double = 0.7
        static let rowGap: CGFloat = 14

        static let chipFinalBackground = Color(red: 0 / 255, green: 136 / 255, blue: 255 / 255)
        static let chipFinalForeground = Color.white
        static let chipPrelimBackground = Color(red: 255 / 255, green: 230 / 255, blue: 242 / 255)
        static let chipPrelimForeground = Color(red: 204 / 255, green: 0 / 255, blue: 109 / 255)
        static let chipNoneBackground = Color(red: 233 / 255, green: 234 / 255, blue: 238 / 255)
        static let chipNoneForeground = Color(red: 122 / 255, green: 126 / 255, blue: 140 / 255)

        static let cardMinHeight: CGFloat = 68
        static let expandedSeparatorColor = Color(red: 236 / 255, green: 236 / 255, blue: 239 / 255)
    }

    enum FormField {
        /// Default background for text input fields (#FFFFFF — same as surface primary).
        static let background = Color(.systemBackground)
        /// Numeric sub-field background (#FAFAFC).
        static let numericBackground = Color(red: 250 / 255, green: 250 / 255, blue: 252 / 255)
        /// Default border colour for fields (#EFEFF2).
        static let borderDefault = Color(red: 239 / 255, green: 239 / 255, blue: 242 / 255)
        /// Focused border colour for fields (#D6D7DC).
        static let borderFocused = Color(red: 214 / 255, green: 215 / 255, blue: 220 / 255)
        /// Standard field corner radius (12 pt).
        static let cornerRadius: CGFloat = 12
    }

    enum Segmented {
        /// Navy fill for the selected segment in the rounding control (#0A2946).
        static let selectedNavy = Color(red: 10 / 255, green: 41 / 255, blue: 70 / 255)
        /// Background of the unselected toggle container (#F2F2F7).
        static let containerBackground = Color(red: 242 / 255, green: 242 / 255, blue: 247 / 255)
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
