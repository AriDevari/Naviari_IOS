//
//  StartCountdownTimerScreen.swift
//  Naviari_IOS
//
//  Counts down to the actual start time with optional voice and flag-mode speech.
//

import SwiftUI
import AVFoundation

// MARK: - Speech coordinator

/// Holds AVSpeechSynthesizer instances in a reference type so they survive
/// view re-renders. Voice nil means iOS automatically picks the system language
/// voice. Flag mode uses a raised pitch (1.3×) so it sounds distinct from
/// normal voice mode without requiring manual voice selection.
private final class SpeechCoordinator: ObservableObject {
    let voiceSynthesizer = AVSpeechSynthesizer()
    let flagSynthesizer = AVSpeechSynthesizer()

    func stopVoice() { voiceSynthesizer.stopSpeaking(at: .immediate) }
    func stopFlag()  { flagSynthesizer.stopSpeaking(at: .immediate) }

    func speak(text: String, useFlagVoice: Bool) {
        let synthesizer = useFlagVoice ? flagSynthesizer : voiceSynthesizer
        let utterance = AVSpeechUtterance(string: text)

        // Leave utterance.voice nil so iOS automatically uses the system default
        // voice, which always matches the device language and avoids API failures
        // from manual voice lookup. A higher pitch distinguishes flag mode.
        if useFlagVoice {
            utterance.pitchMultiplier = 1.3
        }

        synthesizer.speak(utterance)
    }
}

// MARK: - Screen

struct StartCountdownTimerScreen: View {
    let raceSummary: RaceSummary
    let start: RaceStart

    @State private var voiceEnabled: Bool = false
    @State private var flagEnabled: Bool = false
    @State private var showInfo: Bool = false
    @State private var announcedKeys: Set<String> = []

    @StateObject private var speech = SpeechCoordinator()

    var body: some View {
        ScreenContainer(
            showBack: true,
            title: Text("start_timer_title"),
            trailing: AnyView(
                Button(action: { showInfo = true }) {
                    Image(systemName: "info.circle")
                        .font(Theme.Typography.iconLarge)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            )
        ) {
            VStack(spacing: 0) {
                Text(start.name ?? raceSummary.race.nameOrFallback)
                    .font(AppFont.textStyle(.title2, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 8)

                Spacer()

                TimelineView(.periodic(from: .now, by: 1)) { context in
                    countdownDisplay(at: context.date)
                        .onChange(of: context.date) { _, newDate in
                            processAnnouncements(at: newDate)
                        }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 16)

                Spacer()

                HStack(spacing: 48) {
                    voiceToggle
                    flagToggle
                }
                .padding(.bottom, 48)
            }
        }
        // Stop the respective synthesizer immediately when a mode is turned off.
        .onChange(of: voiceEnabled) { _, isOn in if !isOn { speech.stopVoice() } }
        .onChange(of: flagEnabled)  { _, isOn in if !isOn { speech.stopFlag()  } }
        .sheet(isPresented: $showInfo) {
            StartTimerInfoView()
        }
    }

    // MARK: - Countdown display

    @ViewBuilder
    private func countdownDisplay(at date: Date) -> some View {
        let remaining = timeRemaining(at: date)
        let text = displayText(remaining: remaining)
        let isElapsed = remaining < 0
        let isGo = remaining >= 0 && remaining < 1

        Text(text)
            .font(AppFont.fixed(120, weight: .semibold))
            .foregroundStyle(
                isElapsed
                    ? Color.green
                    : (isGo ? Theme.Colors.brandPrimary : Color.primary)
            )
            .minimumScaleFactor(0.2)
            .lineLimit(1)
    }

    private func displayText(remaining: TimeInterval) -> String {
        if remaining >= 1 {
            let total = Int(remaining.rounded(.up))
            let minutes = total / 60
            let seconds = total % 60
            if minutes >= 60 {
                let hours = minutes / 60
                let mins  = minutes % 60
                return String(format: "%d:%02d:%02d", hours, mins, seconds)
            }
            return String(format: "%02d:%02d", minutes, seconds)
        } else if remaining >= 0 {
            return NSLocalizedString("start_timer_go", comment: "")
        } else {
            let elapsed  = Int((-remaining).rounded(.down))
            let minutes  = elapsed / 60
            let seconds  = elapsed % 60
            if minutes >= 60 {
                let hours = minutes / 60
                let mins  = minutes % 60
                return String(format: "+%d:%02d:%02d", hours, mins, seconds)
            }
            return String(format: "+%02d:%02d", minutes, seconds)
        }
    }

    // MARK: - Toggle buttons

    @ViewBuilder
    private var voiceToggle: some View {
        Button(action: { voiceEnabled.toggle() }) {
            Image(systemName: voiceEnabled ? "speaker.wave.2.circle.fill" : "speaker.slash.circle")
                .font(.system(size: 56))
                .foregroundStyle(voiceEnabled ? Theme.Colors.brandPrimary : Color.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(NSLocalizedString("start_timer_voice_label", comment: ""))
        .accessibilityValue(voiceEnabled ? "on" : "off")
    }

    @ViewBuilder
    private var flagToggle: some View {
        Button(action: { flagEnabled.toggle() }) {
            Image(systemName: flagEnabled ? "flag.circle.fill" : "flag.slash.circle")
                .font(.system(size: 56))
                .foregroundStyle(flagEnabled ? Theme.RaceManager.primaryColor : Color.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(NSLocalizedString("start_timer_flag_label", comment: ""))
        .accessibilityValue(flagEnabled ? "on" : "off")
    }

    // MARK: - Announcements

    private func timeRemaining(at now: Date) -> TimeInterval {
        guard let actualStartDate = start.actualStartDate else { return 0 }
        return actualStartDate.timeIntervalSince(now)
    }

    /// When flag mode is active it owns all speech; voice mode is silenced.
    /// When only voice is active, the voice synthesizer speaks.
    private func processAnnouncements(at now: Date) {
        let secondsInt = Int(timeRemaining(at: now).rounded())
        if flagEnabled {
            checkFlagAnnouncement(secondsInt: secondsInt)
        } else if voiceEnabled {
            checkVoiceAnnouncement(secondsInt: secondsInt)
        }
    }

    private func checkVoiceAnnouncement(secondsInt: Int) {
        let key = "voice_\(secondsInt)"
        guard !announcedKeys.contains(key),
              let text = voiceAnnouncementText(for: secondsInt) else { return }
        announcedKeys.insert(key)
        speech.speak(text: text, useFlagVoice: false)
    }

    /// Flag mode handles its own pre-minute events AND the full start countdown,
    /// all through the flag synthesizer using the flag voice.
    private func checkFlagAnnouncement(secondsInt: Int) {
        // Pre-minute countdowns for the 5, 4, and 1 minute flag marks.
        let flagMarks: [(markSeconds: Int, label: String)] = [
            (300, "5"),
            (240, "4"),
            (60,  "1")
        ]
        var spokeFlagNow = false
        for (markSeconds, label) in flagMarks {
            let secondsBefore = secondsInt - markSeconds
            let key = "flag_\(markSeconds)_\(secondsBefore)"
            if !announcedKeys.contains(key),
               let text = flagMarkCountdownText(secondsBefore: secondsBefore, minuteLabel: label) {
                announcedKeys.insert(key)
                speech.speak(text: text, useFlagVoice: true)
                if secondsBefore == 0 { spokeFlagNow = true }
            }
        }

        // Standard start countdown through the flag voice.
        // Skip on exact minute-mark seconds: "Now" already marks those moments,
        // and queuing a second utterance right after would drift ~0.5s off the timer.
        guard !spokeFlagNow else { return }
        let key0 = "flag_start_\(secondsInt)"
        if !announcedKeys.contains(key0),
           let text = voiceAnnouncementText(for: secondsInt) {
            announcedKeys.insert(key0)
            speech.speak(text: text, useFlagVoice: true)
        }
    }

    private func voiceAnnouncementText(for secondsInt: Int) -> String? {
        switch secondsInt {
        case 300: return NSLocalizedString("start_timer_say_5min", comment: "")
        case 240: return NSLocalizedString("start_timer_say_4min", comment: "")
        case 180: return NSLocalizedString("start_timer_say_3min", comment: "")
        case 120: return NSLocalizedString("start_timer_say_2min", comment: "")
        case 90:  return NSLocalizedString("start_timer_say_1min30", comment: "")
        case 60:  return NSLocalizedString("start_timer_say_1min", comment: "")
        case 50:  return String(format: NSLocalizedString("start_timer_say_seconds", comment: ""), 50)
        case 40:  return String(format: NSLocalizedString("start_timer_say_seconds", comment: ""), 40)
        case 30:  return String(format: NSLocalizedString("start_timer_say_seconds", comment: ""), 30)
        case 20:  return String(format: NSLocalizedString("start_timer_say_seconds", comment: ""), 20)
        case 15:  return String(format: NSLocalizedString("start_timer_say_seconds", comment: ""), 15)
        case 10:  return String(format: NSLocalizedString("start_timer_say_seconds", comment: ""), 10)
        case 1...9: return "\(secondsInt)"
        case 0:   return NSLocalizedString("start_timer_say_go", comment: "")
        default:  return nil
        }
    }

    private func flagMarkCountdownText(secondsBefore: Int, minuteLabel: String) -> String? {
        switch secondsBefore {
        case 20: return String(format: NSLocalizedString("start_timer_flag_say_20sec_to", comment: ""), minuteLabel)
        case 10: return String(format: NSLocalizedString("start_timer_flag_say_10sec_to", comment: ""), minuteLabel)
        case 5:  return "5"
        case 4:  return "4"
        case 3:  return "3"
        case 2:  return "2"
        case 1:  return "1"
        case 0:  return NSLocalizedString("start_timer_flag_say_now", comment: "")
        default: return nil
        }
    }
}

// MARK: - Info sheet

private struct StartTimerInfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(LocalizedStringKey("start_timer_info_body"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .navigationTitle(Text("start_timer_info_title"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("close_button") { dismiss() }
                        .font(AppUI.buttonFont)
                }
            }
        }
        .presentationDetents([.fraction(0.4), .medium])
    }
}
