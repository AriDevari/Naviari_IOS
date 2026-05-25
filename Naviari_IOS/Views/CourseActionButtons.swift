import SwiftUI

struct CourseCircularIconButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 22, weight: .medium))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.RaceManager.primaryColor)
        .frame(width: Theme.Sizing.primaryButtonHeight, height: Theme.Sizing.primaryButtonHeight)
        .overlay(
            Circle()
                .stroke(Theme.RaceManager.primaryColor, lineWidth: 1.5)
        )
    }
}

struct CourseOutlineTextIconButton: View {
    let titleKey: LocalizedStringKey
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(titleKey)
                    .font(Theme.Typography.button)

                HStack {
                    Spacer()
                    Image(systemName: systemName)
                        .font(Theme.Typography.iconMedium)
                        .padding(.trailing, Theme.Sizing.primaryButtonHeight / 3)
                }
            }
            .frame(maxWidth: .infinity, minHeight: Theme.Sizing.primaryButtonHeight)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.RaceManager.primaryColor)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Sizing.primaryButtonHeight / 2, style: .continuous)
                .stroke(Theme.RaceManager.primaryColor, lineWidth: 1.5)
        )
    }
}

struct CourseRemoveButton: View {
    let titleKey: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(titleKey)
                    .font(AppFont.fixed(17, weight: .semibold))
                    .foregroundStyle(Theme.RaceManager.primaryColor)
                    .frame(maxWidth: .infinity, alignment: .center)

                HStack {
                    Spacer()
                    Image(systemName: "trash")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Theme.RaceManager.primaryColor)
                        .padding(.trailing, 20)
                }
            }
            .frame(maxWidth: .infinity, minHeight: Theme.Sizing.secondaryButtonHeight)
        }
        .buttonStyle(.plain)
        .overlay(
            Capsule()
                .stroke(Theme.RaceManager.primaryColor, lineWidth: 1.5)
        )
    }
}