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
    @EnvironmentObject private var metricsUploader: BoatMetricsUploader
    @State private var metadataHeight: CGFloat = 0
    @State private var showStopConfirmation = false

    var body: some View {
        ScreenContainer(showBack: true, title: Text("start_title")) {
            GeometryReader { proxy in
                let scrollHeight = metadataSectionHeight(for: proxy.size.height)
                let spacerHeight = metricsUploader.isBroadcasting
                    ? 0
                    : buttonSpacerHeight(for: proxy.size.height, scrollHeight: scrollHeight)

                VStack(spacing: 24) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(start.name ?? raceSummary.race.nameOrFallback)
                                .font(AppFont.textStyle(.title2, weight: .semibold))

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
                            }
                        }
                        .padding()
                        .background(
                            GeometryReader { contentProxy in
                                Color.clear
                                    .preference(
                                        key: StartDetailContentHeightKey.self,
                                        value: contentProxy.size.height
                                    )
                            }
                        )
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: scrollHeight, alignment: .top)
                    .onPreferenceChange(StartDetailContentHeightKey.self) { metadataHeight = $0 }

                    Spacer()
                        .frame(height: spacerHeight)

                    if metricsUploader.isBroadcasting {
                        activeBroadcastSection
                    } else {
                        Button(action: onParticipate) {
                            Text("participate_button")
                                .font(AppUI.buttonFont)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: AppUI.primaryButtonHeight)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.horizontal)
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .alert(
            Text("broadcast_stop_confirm_title"),
            isPresented: $showStopConfirmation
        ) {
            Button("broadcast_stop_confirm_yes", role: .destructive) {
                metricsUploader.stopBroadcast()
            }
            Button("broadcast_stop_confirm_no", role: .cancel) {}
        } message: {
            Text("broadcast_stop_confirm_message")
        }
    }

    @ViewBuilder
    private var activeBroadcastSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("start_detail_broadcasting_header")
                .font(.headline)

            if let summary = metricsUploader.activeSession?.summary {
                ParticipationSummaryView(summary: summary)
            } else {
                Text("broadcast_status_active_subtitle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                showStopConfirmation = true
            } label: {
                Text("broadcast_stop_button")
                    .font(AppUI.buttonFont)
                    .frame(maxWidth: .infinity, minHeight: AppUI.primaryButtonHeight)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .padding(.horizontal)
    }

    private func metadataSectionHeight(for containerHeight: CGFloat) -> CGFloat {
        let defaultHeight = containerHeight * 0.4
        guard metadataHeight > 0 else { return defaultHeight }
        return min(metadataHeight, defaultHeight)
    }

    private func buttonSpacerHeight(for containerHeight: CGFloat, scrollHeight: CGFloat) -> CGFloat {
        let targetCenter = containerHeight / 2
        let offset = targetCenter - scrollHeight - (AppUI.primaryButtonHeight / 2)
        return max(0, offset)
    }
}

private struct StartDetailContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
