import SwiftUI

/// Floating button that summarizes telemetry upload health and opens broadcast diagnostics.
struct BroadcastStatusButton: View {
    @ObservedObject var uploader: BoatMetricsUploader
    @State private var showDetail = false
    @State private var plink = false
    @State private var breathing = false
    @State private var lastAttemptCount = 0
    private let buttonSize: CGFloat = 62

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
            let state = BroadcastIndicatorState.evaluate(uploader: uploader, now: timeline.date)
            Button(action: { showDetail = true }) {
                ZStack {
                    Image(systemName: "antenna.radiowaves.left.and.right.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: buttonSize, height: buttonSize)
                        .foregroundStyle(state.color)
                        .brightness(plink ? 0.25 : 0)
                        .scaleEffect(plink ? 1.12 : 1.0)
                        .animation(.easeOut(duration: 0.22), value: plink)

                    if state == .green {
                        Circle()
                            .stroke(state.color.opacity(0.55), lineWidth: 2)
                            .frame(width: buttonSize, height: buttonSize)
                            .scaleEffect(breathing ? 1.25 : 1.02)
                            .opacity(breathing ? 0.0 : 0.85)
                            .animation(.easeOut(duration: 1.1).repeatForever(autoreverses: false), value: breathing)
                    }
                }
                .frame(width: buttonSize, height: buttonSize)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(state.accessibilityDescription))
        }
        .sheet(isPresented: $showDetail) {
            BroadcastStatusDetailView(uploader: uploader)
        }
        .onAppear {
            lastAttemptCount = uploader.sendAttemptCount
            breathing = true
        }
        .onChange(of: uploader.sendAttemptCount) { newCount in
            if newCount > lastAttemptCount {
                lastAttemptCount = newCount
                triggerPlink()
            }
        }
    }

    private func triggerPlink() {
        plink = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            plink = false
        }
    }
}

/// Sheet containing the same broadcast diagnostics currently shown in the participate screen card.
private struct BroadcastStatusDetailView: View {
    @ObservedObject var uploader: BoatMetricsUploader
    @Environment(\.dismiss) private var dismiss
    @State private var showStopConfirmation = false
    @State private var plink = false
    @State private var breathing = false
    @State private var lastAttemptCount = 0

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
            let state = BroadcastIndicatorState.evaluate(uploader: uploader, now: timeline.date)
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if uploader.isBroadcasting {
                            BroadcastDiagnosticsCard(
                                state: state,
                                plink: plink,
                                breathing: breathing,
                                lastSample: uploader.lastAcceptedSample,
                                lastSendAt: uploader.lastSendAt,
                                backlogSeconds: uploader.backlogSeconds,
                                retryCount: uploader.retryCount,
                                lastErrorAt: uploader.lastErrorAt,
                                errorMessage: uploader.lastErrorMessage
                            )

                            Button {
                                showStopConfirmation = true
                            } label: {
                                Text("broadcast_stop_button")
                                    .font(AppUI.buttonFont)
                                    .frame(maxWidth: .infinity, minHeight: AppUI.primaryButtonHeight)
                            }
                            .padding(.top, 8)
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                        } else {
                            BroadcastDiagnosticsPlaceholder()
                        }
                    }
                    .padding()
                }
                .navigationTitle("broadcast_status_sheet_title")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("close_button") {
                            dismiss()
                        }
                        .font(AppUI.buttonFont)
                    }
                }
            }
            .presentationDetents([.fraction(0.6), .large])
        }
        .alert(
            Text("broadcast_stop_confirm_title"),
            isPresented: $showStopConfirmation
        ) {
            Button("broadcast_stop_confirm_yes", role: .destructive) {
                uploader.stopBroadcast()
            }
            Button("broadcast_stop_confirm_no", role: .cancel) {}
        } message: {
            Text("broadcast_stop_confirm_message")
        }
        .onAppear {
            lastAttemptCount = uploader.sendAttemptCount
            breathing = true
        }
        .onChange(of: uploader.sendAttemptCount) { newCount in
            if newCount > lastAttemptCount {
                lastAttemptCount = newCount
                triggerPlink()
            }
        }
    }

    private func triggerPlink() {
        plink = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            plink = false
        }
    }
}

private enum BroadcastIndicatorState: Equatable {
    case inactive
    case green
    case yellow
    case red

    var color: Color {
        switch self {
        case .inactive:
            return .gray
        case .green:
            return .green
        case .yellow:
            return .orange
        case .red:
            return .red
        }
    }

    var accessibilityDescription: String {
        String(format: NSLocalizedString("broadcast_button_accessibility", comment: ""), NSLocalizedString(accessibilityStateKey, comment: ""))
    }

    private var accessibilityStateKey: String {
        switch self {
        case .inactive:
            return "broadcast_indicator_state_inactive"
        case .green:
            return "broadcast_indicator_state_green"
        case .yellow:
            return "broadcast_indicator_state_yellow"
        case .red:
            return "broadcast_indicator_state_red"
        }
    }

    @MainActor
    static func evaluate(uploader: BoatMetricsUploader, now: Date) -> BroadcastIndicatorState {
        guard uploader.isBroadcasting else {
            return .inactive
        }

        // Treat initial startup as healthy until the first batch has been sent.
        if uploader.lastSendAt == nil {
            return .green
        }

        let locationAge = uploader.lastAcceptedSample.map { now.timeIntervalSince($0.timestamp) }
        let hasRecentLocationUnder5 = locationAge.map { $0 < 5 } ?? false
        let hasRecentLocationUnder20 = locationAge.map { $0 < 20 } ?? false

        if let locationAge, locationAge >= 20 {
            return .red
        }
        if uploader.retryCount > 2 {
            return .red
        }

        if uploader.retryCount == 1 || uploader.retryCount == 2 {
            return hasRecentLocationUnder20 ? .yellow : .red
        }

        let lastBatchSucceeded = didLastBatchSucceed(uploader: uploader)
        if lastBatchSucceeded && hasRecentLocationUnder5 {
            return .green
        }

        if hasRecentLocationUnder20 {
            return .yellow
        }

        return .red
    }

    @MainActor
    private static func didLastBatchSucceed(uploader: BoatMetricsUploader) -> Bool {
        guard let lastSendAt = uploader.lastSendAt else {
            return false
        }
        guard let lastErrorAt = uploader.lastErrorAt else {
            return uploader.lastErrorMessage == nil
        }
        return lastSendAt >= lastErrorAt
    }
}

private struct BroadcastDiagnosticsPlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("broadcast_status_inactive")
                .font(AppFont.textStyle(.headline))
            Text("broadcast_status_placeholder")
                .font(AppFont.textStyle(.subheadline))
                .foregroundStyle(.secondary)
        }
    }
}

private struct BroadcastDiagnosticsCard: View {
    let state: BroadcastIndicatorState
    let plink: Bool
    let breathing: Bool
    let lastSample: BoatSample?
    let lastSendAt: Date?
    let backlogSeconds: Int
    let retryCount: Int
    let lastErrorAt: Date?
    let errorMessage: String?
    private let iconSize: CGFloat = 28

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Image(systemName: "antenna.radiowaves.left.and.right.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: iconSize, height: iconSize)
                        .foregroundStyle(state.color)
                        .brightness(plink ? 0.25 : 0)
                        .scaleEffect(plink ? 1.12 : 1.0)
                        .animation(.easeOut(duration: 0.22), value: plink)

                    if state == .green {
                        Circle()
                            .stroke(state.color.opacity(0.55), lineWidth: 2)
                            .frame(width: iconSize, height: iconSize)
                            .scaleEffect(breathing ? 1.25 : 1.02)
                            .opacity(breathing ? 0.0 : 0.85)
                            .animation(.easeOut(duration: 1.1).repeatForever(autoreverses: false), value: breathing)
                    }
                }
                .frame(width: iconSize, height: iconSize)

                VStack(alignment: .leading, spacing: 2) {
                    Text("broadcast_status_active")
                        .font(AppFont.textStyle(.headline))
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                BroadcastDiagnosticsRow(
                    titleKey: "broadcast_status_last_sample",
                    value: sampleDescription
                )
                BroadcastDiagnosticsRow(
                    titleKey: "broadcast_status_last_upload",
                    value: uploadDescription
                )
                BroadcastDiagnosticsRow(
                    titleKey: "broadcast_status_backlog_label",
                    value: backlogDescription
                )
                if retryCount > 0 {
                    BroadcastDiagnosticsRow(
                        titleKey: "broadcast_status_retry_label",
                        value: retryDescription
                    )
                }
            }

            if let errorMessage {
                VStack(alignment: .leading, spacing: 4) {
                    Text("broadcast_status_error_prefix")
                        .font(AppFont.textStyle(.subheadline, weight: .semibold))
                        .foregroundStyle(.red)
                    Text(errorMessage)
                        .font(AppFont.textStyle(.footnote))
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var sampleDescription: String {
        guard let lastSample else {
            return NSLocalizedString("broadcast_status_waiting_sample", comment: "")
        }
        return DateFormattingHelper.localizedTime(from: lastSample.timestamp)
    }

    private var uploadDescription: String {
        guard let lastSendAt else {
            return NSLocalizedString("broadcast_status_waiting_upload", comment: "")
        }
        return DateFormattingHelper.relativeTimeString(from: lastSendAt)
    }

    private var backlogDescription: String {
        if backlogSeconds <= 0 {
            return NSLocalizedString("broadcast_status_backlog_clear", comment: "")
        }
        let duration = TimeInterval(backlogSeconds)
        let formatted = BroadcastDiagnosticsCard.durationFormatter.string(from: duration) ?? "\(backlogSeconds)s"
        return String(
            format: NSLocalizedString("broadcast_status_backlog_value", comment: ""),
            formatted
        )
    }

    private var retryDescription: String {
        let countString = String(
            format: NSLocalizedString("broadcast_status_retry_count_value", comment: ""),
            retryCount
        )
        if let lastErrorAt {
            let relative = DateFormattingHelper.relativeTimeString(from: lastErrorAt)
            return "\(countString) • \(relative)"
        }
        return countString
    }

    private static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .short
        formatter.collapsesLargestUnit = false
        return formatter
    }()
}

private struct BroadcastDiagnosticsRow: View {
    let titleKey: LocalizedStringKey
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(titleKey)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .multilineTextAlignment(.trailing)
        }
    }
}
