//
//  RaceStartRowView.swift
//  Naviari_IOS
//
//  Shows basic info for a single start inside a race.
//

import SwiftUI

/// Compact row summarizing a single race start, used inside race detail lists.
struct RaceStartRowView: View {
    let start: RaceStart
    let timeText: String?

    var body: some View {
        HStack(spacing: 16) {
            StartAvatarView(start: start)
            VStack(alignment: .leading, spacing: 4) {
                Text(start.name?.isEmpty == false ? start.name! : NSLocalizedString("race_unnamed_placeholder", comment: ""))
                    .font(AppFont.textStyle(.subheadline))
                    .bold()
                if let timeText {
                    Text(timeText)
                        .font(AppFont.textStyle(.footnote))
                        .foregroundStyle(.secondary)
                }
                if let status = start.status {
                    Text(status)
                        .font(AppFont.textStyle(.footnote))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemBackground))
        )
    }
}
