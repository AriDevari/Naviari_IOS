import SwiftUI

/// Reusable label for race-manager action buttons.
/// Centers the title text and places a role-indicator icon at the trailing edge.
struct RaceManagerButtonLabel: View {
    let titleKey: LocalizedStringKey

    init(_ titleKey: LocalizedStringKey) {
        self.titleKey = titleKey
    }

    var body: some View {
        ZStack {
            Text(titleKey)
                .font(Theme.Typography.button)
            HStack {
                Spacer()
                Image(systemName: Theme.RaceManager.iconName)
                    .font(Theme.Typography.iconMedium)
                    .padding(.trailing, Theme.Sizing.primaryButtonHeight / 3)
            }
        }
        .frame(maxWidth: .infinity, minHeight: Theme.Sizing.primaryButtonHeight)
    }
}
