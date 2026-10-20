//
//  CentrifugoPOCLabel.swift
//  Naviari_IOS
//
//  THROWAWAY Centrifugo proof of concept — see CentrifugoPOCClient.swift.
//  Renders nothing until a publication arrives, then "Centrifugo: <value>".
//

import SwiftUI

/// Small gray evidence that a Centrifugo push reached the app.
struct CentrifugoPOCLabel: View {
    @ObservedObject private var client = CentrifugoPOCClient.shared

    var body: some View {
        if let value = client.latestValue {
            // POC: debug text, intentionally not localized.
            Text(verbatim: "Centrifugo: \(Self.format(value))")
                .font(AppFont.textStyle(.caption))
                .foregroundStyle(Theme.Colors.textSecondary)
                .padding(.bottom, Theme.Spacing.floatingInset)
                .accessibilityIdentifier("centrifugo_poc_label")
        }
    }

    private static func format(_ value: Double) -> String {
        value.rounded() == value && abs(value) < 1e15 ? String(Int64(value)) : String(value)
    }
}
