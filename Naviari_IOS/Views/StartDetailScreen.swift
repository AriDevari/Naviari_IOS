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

    private var currentStartIdentifier: String? {
        start.rawId ?? start.slug
    }

    private var activeSessionMatchesCurrentStart: Bool {
        metricsUploader.activeSession?.matches(startId: currentStartIdentifier) == true
    }

    private var shouldShowActiveBroadcastSection: Bool {
        metricsUploader.isBroadcasting && activeSessionMatchesCurrentStart
    }

    private var shouldHideParticipateCTAForOtherActiveBroadcast: Bool {
        metricsUploader.isBroadcasting
            && metricsUploader.activeSession?.blocksStartBroadcastCTA(for: currentStartIdentifier) == true
    }

    private var isRehearsalWindow: Bool {
        start.isRehearsalWindow()
    }

    private var isMissingEstimatedStart: Bool {
        !start.hasEstimatedStartDate
    }

    private var primaryActionKey: LocalizedStringKey {
        isRehearsalWindow ? "participate_rehearsal_button" : "participate_button"
    }

    private var shouldShowParticipateCTA: Bool {
        !shouldShowActiveBroadcastSection
            && !start.isCompletedStatus
            && !isMissingEstimatedStart
            && !shouldHideParticipateCTAForOtherActiveBroadcast
    }

    private var shouldShowRehearsalAutoStopMessage: Bool {
        metricsUploader.lastStopReason == .rehearsalTimeLimitReached
            && metricsUploader.lastStoppedSession?.startId == currentStartIdentifier
    }

    var body: some View {
        ScreenContainer(showBack: true, title: Text("start_title")) {
            GeometryReader { proxy in
                let scrollHeight = metadataSectionHeight(for: proxy.size.height)
                let spacerHeight = (shouldShowActiveBroadcastSection || shouldShowParticipateCTA)
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
                                Text(LocalizedStringKey(start.localizedStatusKey))
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

                    if shouldShowActiveBroadcastSection {
                        activeBroadcastSection
                    } else if start.isCompletedStatus {
                        unavailableState(messageKey: "start_detail_completed_message")
                    } else if isMissingEstimatedStart {
                        unavailableState(messageKey: "participate_estimated_start_required_hint")
                    } else if shouldHideParticipateCTAForOtherActiveBroadcast {
                        EmptyView()
                    } else {
                        Button(action: onParticipate) {
                            Text(primaryActionKey)
                                .font(AppUI.buttonFont)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: AppUI.primaryButtonHeight)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.horizontal)

                        if isRehearsalWindow {
                            rehearsalInactiveGuidance
                        } else if shouldShowRehearsalAutoStopMessage {
                            unavailableState(messageKey: "start_detail_rehearsal_autostop_message")
                        }
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
        .task(id: start.id + (start.status ?? "")) {
            stopBroadcastIfCompletedForCurrentStart()
        }
    }

    @ViewBuilder
    private var activeBroadcastSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(activeBroadcastHeaderKey)
                .font(.headline)

            if let summary = metricsUploader.activeSession?.summary {
                ParticipationSummaryView(summary: summary)
            } else {
                Text("broadcast_status_active_subtitle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if metricsUploader.activeSession?.isRehearsal == true {
                rehearsalActiveGuidance
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

    private var activeBroadcastHeaderKey: LocalizedStringKey {
        metricsUploader.activeSession?.isRehearsal == true
            ? "start_detail_rehearsal_active_header"
            : "start_detail_broadcasting_header"
    }

    private var rehearsalInactiveGuidance: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("start_detail_rehearsal_message")
                .font(AppFont.textStyle(.subheadline))
                .foregroundStyle(.secondary)

            Text("participate_rehearsal_delay_reminder")
                .font(AppFont.textStyle(.footnote))
                .foregroundStyle(.secondary)

            Text("participate_rehearsal_autostop")
                .font(AppFont.textStyle(.footnote))
                .foregroundStyle(.secondary)

            Link(destination: URL(string: "https://naviari.org")!) {
                Text("participate_rehearsal_verify_link")
                    .font(AppFont.textStyle(.subheadline, weight: .semibold))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }

    private var rehearsalActiveGuidance: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("start_detail_rehearsal_active_message")
                .font(AppFont.textStyle(.subheadline))
                .foregroundStyle(.secondary)
            Text("participate_rehearsal_delay_reminder")
                .font(AppFont.textStyle(.footnote))
                .foregroundStyle(.secondary)
            Text("participate_rehearsal_autostop")
                .font(AppFont.textStyle(.footnote))
                .foregroundStyle(.secondary)
        }
    }

    private func unavailableState(messageKey: LocalizedStringKey) -> some View {
        Text(messageKey)
            .font(AppFont.textStyle(.subheadline))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal)
    }

    private func stopBroadcastIfCompletedForCurrentStart() {
        guard start.isCompletedStatus, activeSessionMatchesCurrentStart, metricsUploader.isBroadcasting else {
            return
        }
        metricsUploader.stopBroadcast(reason: .completedStart)
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
