//
//  ErrorStateView.swift
//  Naviari_IOS
//
//  Displays inline error messaging with a localized retry button.
//

import SwiftUI

/// Small helper view for inline error messages and retry CTA.
struct ErrorStateView: View {
    let message: String
    let buttonTitleKey: LocalizedStringKey
    let action: () -> Void
    /// Optional `accessibilityIdentifier` applied to the retry button.
    /// Callers that need to address the retry button from XCUITest pass an
    /// identifier here. Callers that don't (existing call sites) omit it and
    /// the button stays without a non-localized identifier — same as before.
    var buttonAccessibilityIdentifier: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(message.isEmpty ? NSLocalizedString("races_error", comment: "") : message)
                .foregroundStyle(Theme.Colors.error)
            retryButton
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var retryButton: some View {
        if let buttonAccessibilityIdentifier {
            Button(buttonTitleKey, action: action)
                .font(AppUI.buttonFont)
                .accessibilityIdentifier(buttonAccessibilityIdentifier)
        } else {
            Button(buttonTitleKey, action: action)
                .font(AppUI.buttonFont)
        }
    }
}
