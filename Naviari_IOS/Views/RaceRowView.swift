//
//  RaceRowView.swift
//  Naviari_IOS
//
//  Renders a single race summary row for selection lists.
//

import SwiftUI

/// Simple list row presenting a race name + series and an optional checkmark.
struct RaceRowView: View {
    let summary: RaceSummary
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 16) {
            RaceAvatarView(summary: summary)
            VStack(alignment: .leading, spacing: 4) {
                Text(summary.race.nameOrFallback)
                    .font(AppFont.textStyle(.headline))
                    .foregroundStyle(.primary)
                if let seriesName = summary.seriesName {
                    Text(seriesName)
                        .font(AppFont.textStyle(.subheadline))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppUI.brandPrimary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.rowCard)
                .fill(isSelected ? AppUI.brandPrimaryMuted : Theme.Colors.surfaceSecondary)
        )
    }
}
