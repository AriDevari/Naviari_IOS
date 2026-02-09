//
//  RaceRowView.swift
//  Naviari_IOS
//
//  Renders a single race summary row for selection lists.
//

import SwiftUI

struct RaceRowView: View {
    let summary: RaceSummary
    let isSelected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(summary.race.nameOrFallback)
                    .font(.headline)
                    .foregroundStyle(.primary)
                if let seriesName = summary.seriesName {
                    Text(seriesName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.blue)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.blue.opacity(0.15) : Color(.secondarySystemBackground))
        )
    }
}
