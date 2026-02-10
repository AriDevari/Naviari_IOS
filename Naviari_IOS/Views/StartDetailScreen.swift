//
//  StartDetailScreen.swift
//  Naviari_IOS
//
//  Displays the selected race start metadata and placeholder content.
//

import SwiftUI

/// Shows start-specific metadata and the entry point into the participation flow.
struct StartDetailScreen: View {
    let raceSummary: RaceSummary
    let start: RaceStart
    var onParticipate: () -> Void
    @EnvironmentObject private var viewModel: RaceBrowserViewModel

    var body: some View {
        ScreenContainer(showBack: true, title: Text(start.name ?? raceSummary.race.nameOrFallback)) {
            VStack(spacing: 24) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        LabeledContent {
                            Text(viewModel.formattedStartTime(for: start) ?? "—")
                        } label: {
                            Text("race_date_label")
                                .foregroundStyle(.secondary)
                        }

                        LabeledContent {
                            Text(start.status ?? NSLocalizedString("start_status_unknown", comment: ""))
                        } label: {
                            Text("race_status_label")
                                .foregroundStyle(.secondary)
                        }

                        if let description = start.description, !description.isEmpty {
                            Text(description)
                                .padding(.top, 8)
                        } else {
                            Text("race_selection_placeholder")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                }

                Button(action: onParticipate) {
                    Text("participate_button")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 88)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
            }
        }
    }
}
