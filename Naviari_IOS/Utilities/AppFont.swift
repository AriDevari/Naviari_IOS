import SwiftUI
import UIKit

/// Centralized app typography using the bundled Nunito font family.
enum AppFont {
    private static let fontName = "Nunito-Regular"

    static func textStyle(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        Font.custom(fontName, size: pointSize(for: style), relativeTo: style).weight(weight)
    }

    static func fixed(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.custom(fontName, size: size).weight(weight)
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
