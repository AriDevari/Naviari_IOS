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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(message.isEmpty ? NSLocalizedString("races_error", comment: "") : message)
                .foregroundStyle(Theme.Colors.error)
            Button(buttonTitleKey, action: action)
                .font(AppUI.buttonFont)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
