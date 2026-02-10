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
            Spacer()

            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .shadow(radius: 4)

            Spacer()

            Text("welcome_message")
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            Button(action: onOpenRaces) {
                Text("open_races_button")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 48)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 24)
        .background(Color(.systemBackground))
    }
}
