//
//  RaceStartRowView.swift
//  Naviari_IOS
//
//  Shows basic info for a single start inside a race.
//

import SwiftUI

struct RaceStartRowView: View {
    let start: RaceStart
    let timeText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(start.name?.isEmpty == false ? start.name! : NSLocalizedString("race_unnamed_placeholder", comment: ""))
                .font(.subheadline)
                .bold()
            if let timeText {
                Text(timeText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if let status = start.status {
                Text(status)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemBackground))
        )
    }
}
