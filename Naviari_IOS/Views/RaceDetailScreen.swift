//
//  RaceDetailScreen.swift
//  Naviari_IOS
//
//  Shows metadata and start list for a single race selection.
//

import SwiftUI

struct RaceDetailScreen: View {
    let summary: RaceSummary
    var onSelectStart: (RaceStart) -> Void
    @EnvironmentObject private var viewModel: RaceBrowserViewModel

    var body: some View {
        ScreenContainer(showBack: true, title: Text(summary.race.nameOrFallback)) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let dateText = viewModel.formattedDate(for: summary.race) {
                        LabeledContent {
                            Text(dateText)
                        } label: {
                            Text("race_date_label")
                                .foregroundStyle(.secondary)
                        }
                    }

                    LabeledContent {
                    Text(summary.race.status ?? NSLocalizedString("start_status_unknown", comment: ""))
                } label: {
                    Text("race_status_label")
                        .foregroundStyle(.secondary)
                }

                    if let description = summary.race.description, !description.isEmpty {
                        LabeledContent {
                            Text(description)
                        } label: {
                            Text("race_description_label")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Divider().padding(.vertical, 8)

                    Text("race_starts_title")
                        .font(.headline)

                    if viewModel.isLoadingStarts(for: summary) && viewModel.starts(for: summary).isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 16)
                    } else if let errorMessage = viewModel.startError(for: summary) {
                        ErrorStateView(
                            message: errorMessage,
                            buttonTitleKey: "races_retry_button",
                            action: {
                                Task {
                                    await viewModel.retryStarts()
                                }
                            }
                        )
                    } else {
                        let starts = viewModel.starts(for: summary)
                        if starts.isEmpty {
                            Text("starts_empty")
                                .foregroundStyle(.secondary)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(starts) { start in
                                    Button {
                                        onSelectStart(start)
                                    } label: {
                                        RaceStartRowView(
                                            start: start,
                                            timeText: viewModel.formattedStartTime(for: start)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .task {
            await viewModel.ensureRaceData(for: summary)
        }
    }
}
