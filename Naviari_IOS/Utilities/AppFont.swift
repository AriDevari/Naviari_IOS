import SwiftUI
import UIKit

/// Centralized app typography using the bundled Nunito font family.
enum AppFont {
    /// Maps a SwiftUI `Font.Weight` to the matching Nunito font-file PostScript name.
    private static func fontName(for weight: Font.Weight) -> String {
        switch weight {
        case .ultraLight: return "Nunito-Regular"
        case .thin:       return "Nunito-Regular"
        case .light:      return "Nunito-Regular"
        case .regular:    return "Nunito-Regular"
        case .medium:     return "Nunito-Medium"
        case .semibold:   return "Nunito-SemiBold"
        case .bold:       return "Nunito-Bold"
        case .heavy:      return "Nunito-ExtraBold"
        case .black:      return "Nunito-ExtraBold"
        default:          return "Nunito-Regular"
        }
    }

    static func textStyle(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        Font.custom(fontName(for: weight), size: pointSize(for: style), relativeTo: style)
    }

    static func fixed(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.custom(fontName(for: weight), fixedSize: size)
    }

    private static func pointSize(for style: Font.TextStyle) -> CGFloat {
        let uiTextStyle: UIFont.TextStyle
        switch style {
        case .largeTitle:
            uiTextStyle = .largeTitle
        case .title:
            uiTextStyle = .title1
        case .title2:
            uiTextStyle = .title2
        case .title3:
            uiTextStyle = .title3
        case .headline:
            uiTextStyle = .headline
        case .subheadline:
            uiTextStyle = .subheadline
        case .body:
            uiTextStyle = .body
        case .callout:
            uiTextStyle = .callout
        case .footnote:
            uiTextStyle = .footnote
        case .caption:
            uiTextStyle = .caption1
        case .caption2:
            uiTextStyle = .caption2
        @unknown default:
            uiTextStyle = .body
        }
        return UIFont.preferredFont(forTextStyle: uiTextStyle).pointSize
    }
}
