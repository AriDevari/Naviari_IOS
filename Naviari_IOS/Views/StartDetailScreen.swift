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
    @State private var metadataHeight: CGFloat = 0

    private let participateButtonHeight: CGFloat = 88

    var body: some View {
        ScreenContainer(showBack: true, title: Text(start.name ?? raceSummary.race.nameOrFallback)) {
            GeometryReader { proxy in
                let scrollHeight = metadataSectionHeight(for: proxy.size.height)
                let spacerHeight = buttonSpacerHeight(for: proxy.size.height, scrollHeight: scrollHeight)

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

                    Button(action: onParticipate) {
                        Text("participate_button")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: participateButtonHeight)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
    }

    private func metadataSectionHeight(for containerHeight: CGFloat) -> CGFloat {
        let defaultHeight = containerHeight * 0.4
        guard metadataHeight > 0 else { return defaultHeight }
        return min(metadataHeight, defaultHeight)
    }

    private func buttonSpacerHeight(for containerHeight: CGFloat, scrollHeight: CGFloat) -> CGFloat {
        let targetCenter = containerHeight / 2
        let offset = targetCenter - scrollHeight - (participateButtonHeight / 2)
        return max(0, offset)
    }
}

private struct StartDetailContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
