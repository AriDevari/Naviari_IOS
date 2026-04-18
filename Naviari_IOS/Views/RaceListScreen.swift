//
//  RaceListScreen.swift
//  Naviari_IOS
//
//  Presents the top-level list of races fetched from the backend.
//

import SwiftUI

/// Lists every race summary fetched from the backend and forwards selections upstream.
struct RaceListScreen: View {
    @EnvironmentObject private var viewModel: RaceBrowserViewModel
    var onSelectRace: (RaceSummary) -> Void

    private let footerMarkdown = NSLocalizedString(
        "races_finished_footer",
        comment: "Guidance for users looking for finished races"
    )

    var body: some View {
        ScreenContainer(showBack: true, title: Text("races_title")) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if viewModel.isLoadingRaces && viewModel.raceItems.isEmpty {
                        ProgressView("races_loading")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else if let errorMessage = viewModel.raceError {
                        ErrorStateView(
                            message: errorMessage,
                            buttonTitleKey: "races_retry_button",
                            action: {
                                Task {
                                    await viewModel.reloadRaces()
                                }
                            }
                        )
                    } else if viewModel.raceItems.isEmpty {
                        Text("races_empty_current_upcoming")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.raceItems) { summary in
                                Button {
                                    Task {
                                        await viewModel.selectRace(summary)
                                        onSelectRace(summary)
                                    }
                                } label: {
                                    RaceRowView(
                                        summary: summary,
                                        isSelected: viewModel.selectedRace?.id == summary.id
                                    )
                                }
                                .buttonStyle(.plain)
                            }

                            Text(markdownAttributedString(from: footerMarkdown))
                                .font(AppFont.textStyle(.footnote))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .multilineTextAlignment(.center)
                                .padding(.top, 4)
                        }
                    }
                }
                .padding()
            }
        }
        .task {
            await viewModel.loadRacesIfNeeded()
        }
    }

    private func markdownAttributedString(from markdown: String) -> AttributedString {
        (try? AttributedString(markdown: markdown)) ?? AttributedString(markdown)
    }
}
