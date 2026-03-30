//
//  WelcomeScreen.swift
//  Naviari_IOS
//
//  Shows the localized onboarding hero with logo and CTA into the race flow.
//

import SwiftUI

/// Landing view shown before the user opens the race browser.
struct WelcomeScreen: View {
    var onOpenRaces: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .shadow(radius: Theme.Effects.logoShadowRadius)

            Spacer()

            Text("welcome_message")
                .font(AppFont.textStyle(.title3))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            Button(action: onOpenRaces) {
                Text("open_races_button")
                    .font(AppUI.buttonFont)
                    .frame(maxWidth: .infinity, minHeight: AppUI.primaryButtonHeight)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppUI.brandPrimary)
            .padding(.horizontal, 48)
            .offset(y: -20)

            Text(.init(NSLocalizedString("welcome_spectator_hint", comment: "")))
                .font(AppFont.textStyle(.footnote))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 12)
                .padding(.horizontal, 32)

            Spacer(minLength: 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 24)
        .background(Theme.Colors.surfacePrimary)
    }
}
