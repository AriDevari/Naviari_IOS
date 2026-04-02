//
//  StartDetailScreen.swift
//  Naviari_IOS
//
//  Displays the selected race start metadata and placeholder content.
//

import SwiftUI

/// Shows start-specific metadata and the entry point into the participation flow.
struct StartDetailScreen: View {
    private static let rehearsalVisibilityDelay: TimeInterval = 30
    private static let rehearsalUploadCadence: TimeInterval = 10
    private static let uploadBoundaryTolerance: TimeInterval = 0.001
    private static let rehearsalVerificationBaseURL = URL(string: "https://naviari.org")!
    private static let rehearsalVerificationMarkdownTargets = [
        "https://naviari.org/",
        "https://naviari.org"
    ]

    let raceSummary: RaceSummary
    let start: RaceStart
    var onParticipate: () -> Void
    var onSetStartTime: () -> Void
    @EnvironmentObject private var viewModel: RaceBrowserViewModel
    @EnvironmentObject private var metricsUploader: BoatMetricsUploader
    @State private var metadataHeight: CGFloat = 0
    @State private var showStopConfirmation = false

    private var resolvedStart: RaceStart {
        guard let startId = start.rawId ?? start.slug else {
            return start
        }
        if let updated = viewModel.selectedRaceStarts.first(where: { ($0.rawId ?? $0.slug) == startId }) {
            return updated
        }
        return start
    }

    private var currentStartIdentifier: String? {
        resolvedStart.rawId ?? resolvedStart.slug
    }

    private var rehearsalVerificationURL: URL {
        guard let rawStartId = currentStartIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawStartId.isEmpty else {
            return Self.rehearsalVerificationBaseURL
        }

        var components = URLComponents(
            url: Self.rehearsalVerificationBaseURL,
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "start_id", value: rawStartId)]
        return components?.url ?? Self.rehearsalVerificationBaseURL
    }

    private var activeSessionMatchesCurrentStart: Bool {
        metricsUploader.activeSession?.matches(startId: currentStartIdentifier) == true
    }

    private var shouldShowActiveBroadcastSection: Bool {
        metricsUploader.isBroadcasting && activeSessionMatchesCurrentStart
    }

    private var activeRehearsalSession: BroadcastSession? {
        guard activeSessionMatchesCurrentStart,
              let session = metricsUploader.activeSession,
              session.isRehearsal else {
            return nil
        }
        return session
    }

    private var shouldHideParticipateCTAForOtherActiveBroadcast: Bool {
        metricsUploader.isBroadcasting
            && metricsUploader.activeSession?.blocksStartBroadcastCTA(for: currentStartIdentifier) == true
    }

    private var isRehearsalWindow: Bool {
        resolvedStart.isRehearsalWindow()
    }

    private var isMissingEstimatedStart: Bool {
        !resolvedStart.hasEstimatedStartDate
    }

    private var primaryActionKey: LocalizedStringKey {
        isRehearsalWindow ? "participate_rehearsal_button" : "participate_button"
    }

    private var shouldShowParticipateCTA: Bool {
        !shouldShowActiveBroadcastSection
            && !resolvedStart.isCompletedStatus
            && !isMissingEstimatedStart
            && !shouldHideParticipateCTAForOtherActiveBroadcast
    }

    private var shouldShowRehearsalAutoStopMessage: Bool {
        metricsUploader.lastStopReason == .rehearsalTimeLimitReached
            && metricsUploader.lastStoppedSession?.startId == currentStartIdentifier
    }

    private var shouldShowSetStartTimeCTA: Bool {
        !resolvedStart.isCompletedStatus
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
                            Text(resolvedStart.name ?? raceSummary.race.nameOrFallback)
                                .font(AppFont.textStyle(.title2, weight: .semibold))

                            startTimingMetadataRow

                            LabeledContent {
                                Text(LocalizedStringKey(resolvedStart.localizedStatusKey))
                            } label: {
                                Text("race_status_label")
                                    .foregroundStyle(.secondary)
                            }

                            if let description = resolvedStart.description, !description.isEmpty {
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
                    } else if resolvedStart.isCompletedStatus {
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
                        .tint(AppUI.brandPrimary)
                        .padding(.horizontal)

                        if isRehearsalWindow {
                            rehearsalInactiveGuidance
                        } else if shouldShowRehearsalAutoStopMessage {
                            unavailableState(messageKey: "start_detail_rehearsal_autostop_message")
                        }
                    }

                    if shouldShowSetStartTimeCTA {
                        Button(action: onSetStartTime) {
                            Text("set_start_time_title")
                                .font(AppUI.buttonFont)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: AppUI.primaryButtonHeight)
                        }
                        .buttonStyle(.bordered)
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
        .task(id: resolvedStart.id + (resolvedStart.status ?? "")) {
            stopBroadcastIfCompletedForCurrentStart()
        }
    }

    @ViewBuilder
    private var activeBroadcastSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(activeBroadcastHeaderKey)
                .font(Theme.Typography.headline)

            if let summary = metricsUploader.activeSession?.summary {
                ParticipationSummaryView(summary: summary)
            } else {
                Text("broadcast_status_active_subtitle")
                    .font(Theme.Typography.subheadline)
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
            .tint(Theme.Colors.destructive)
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }

    private var rehearsalActiveGuidance: some View {
        VStack(alignment: .leading, spacing: 8) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(.init(rehearsalActiveMessage(at: context.date)))
                    .font(AppFont.textStyle(.subheadline))
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            Text("participate_rehearsal_delay_reminder")
                .font(AppFont.textStyle(.subheadline))
                .foregroundStyle(.secondary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
            Text("participate_rehearsal_autostop")
                .font(AppFont.textStyle(.subheadline))
                .foregroundStyle(.secondary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: Theme.CornerRadius.materialCard, style: .continuous))
    }

    private func rehearsalActiveMessage(at referenceDate: Date) -> String {
        let baseText = rehearsalDeepLinkedMarkdown(
            NSLocalizedString("start_detail_rehearsal_active_message", comment: "")
        )
        guard let secondsRemaining = rehearsalDelaySecondsRemaining(at: referenceDate) else {
            return baseText
        }

        let countdownFormat = rehearsalDeepLinkedMarkdown(
            NSLocalizedString("start_detail_rehearsal_active_message_countdown", comment: "")
        )
        return String.localizedStringWithFormat(countdownFormat, secondsRemaining)
    }

    private func rehearsalDeepLinkedMarkdown(_ localizedMarkdown: String) -> String {
        let deepLink = rehearsalVerificationURL.absoluteString
        return Self.rehearsalVerificationMarkdownTargets.reduce(localizedMarkdown) { partial, target in
            partial.replacingOccurrences(of: target, with: deepLink)
        }
    }

    private func rehearsalDelaySecondsRemaining(at referenceDate: Date) -> Int? {
        guard let startedAt = activeRehearsalSession?.startedAt else {
            return nil
        }

        let uploadBoundaryDelay = uploadBoundaryDelaySeconds(from: startedAt)
        let visibleAt = startedAt.addingTimeInterval(Self.rehearsalVisibilityDelay + uploadBoundaryDelay)
        let remaining = Int(ceil(visibleAt.timeIntervalSince(referenceDate)))
        return remaining > 0 ? remaining : nil
    }

    private func uploadBoundaryDelaySeconds(from startedAt: Date) -> TimeInterval {
        let cadence = Self.rehearsalUploadCadence
        let remainder = startedAt.timeIntervalSince1970.truncatingRemainder(dividingBy: cadence)
        let normalizedRemainder = remainder >= 0 ? remainder : remainder + cadence
        let delay = cadence - normalizedRemainder
        return delay >= cadence - Self.uploadBoundaryTolerance ? 0 : delay
    }

    private func unavailableState(messageKey: LocalizedStringKey) -> some View {
        Text(messageKey)
            .font(AppFont.textStyle(.subheadline))
            .foregroundStyle(.secondary)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal)
    }

    @ViewBuilder
    private var startTimingMetadataRow: some View {
        if resolvedStart.actualStartDate != nil {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                actualStartMetadataRow(for: viewModel.actualStartHeaderState(for: resolvedStart, now: context.date))
            }
        } else {
            LabeledContent {
                Text(viewModel.formattedStartTime(for: resolvedStart) ?? "—")
            } label: {
                Text("race_date_label")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func actualStartMetadataRow(for state: ActualStartHeaderState) -> some View {
        switch state {
        case let .scheduled(timeText):
            LabeledContent {
                Text(timeText ?? "—")
            } label: {
                Text("race_date_label")
                    .foregroundStyle(.secondary)
            }
        case let .countdown(timeToStartText):
            LabeledContent {
                Text(timeToStartText)
                    .monospacedDigit()
            } label: {
                Text("start_detail_time_to_start_label")
                    .foregroundStyle(.secondary)
            }
        case let .started(actualLocalTimeText):
            LabeledContent {
                Text(actualLocalTimeText)
            } label: {
                Text("start_detail_started_label")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func stopBroadcastIfCompletedForCurrentStart() {
        guard resolvedStart.isCompletedStatus, activeSessionMatchesCurrentStart, metricsUploader.isBroadcasting else {
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
