import Foundation

/// Presentation state for Start Detail timing metadata once actual start support is enabled.
enum ActualStartHeaderState: Equatable {
    case scheduled(timeText: String?)
    case countdown(timeToStartText: String)
    case started(actualLocalTimeText: String)
}

/// Drives the “Browse races / starts” flow (series list, selected race state, error/loading flags).
@MainActor
final class RaceBrowserViewModel: ObservableObject {
    @Published private(set) var raceItems: [RaceSummary] = []
    @Published private(set) var isLoadingRaces = false
    @Published private(set) var raceError: String?

    @Published var selectedRace: RaceSummary?
    @Published private(set) var isLoadingStarts = false
    @Published private(set) var startError: String?
    @Published private(set) var selectedRaceStarts: [RaceStart] = []
    @Published private(set) var isSubmittingActualStart = false
    @Published private(set) var actualStartSubmitError: String?

    private let service: RaceService

    init(service: RaceService = RaceService()) {
        self.service = service
    }

    /// Fetches races only when the current cache is empty.
    func loadRacesIfNeeded() async {
        guard raceItems.isEmpty else { return }
        await loadRaces(force: false)
    }

    /// Forces a full reload of series/races (used by pull-to-refresh).
    func reloadRaces() async {
        await loadRaces(force: true)
    }

    /// Marks a race as selected and loads its starts.
    func selectRace(_ summary: RaceSummary) async {
        selectedRace = summary
        await loadStarts(for: summary.race, force: true)
    }

    /// Ensures the selected race matches the given summary and loads starts if missing.
    func ensureRaceData(for summary: RaceSummary) async {
        if selectedRace?.id != summary.id {
            await selectRace(summary)
        } else if selectedRaceStarts.isEmpty && !isLoadingStarts {
            await loadStarts(for: summary.race, force: false)
        }
    }

    /// Retries loading starts for the currently selected race after an error.
    func retryStarts() async {
        guard let race = selectedRace?.race else { return }
        await loadStarts(for: race, force: true)
    }

    /// Helper for rendering localized race dates.
    func formattedDate(for race: Race) -> String? {
        DateFormattingHelper.localizedDateString(
            from: race.scheduledUTC ?? race.actualUTC ?? race.date,
            includeTime: false
        )
    }

    /// Helper for rendering localized start times (date + time).
    func formattedStartTime(for start: RaceStart) -> String? {
        DateFormattingHelper.localizedDateString(
            from: start.scheduledUTC,
            includeTime: true
        )
    }

    /// Submits `actual_utc` for a start and patches the updated start in local race state.
    func submitActualStartTime(
        for start: RaceStart,
        actualUtc: String,
        updatedBy: String = "ios-app",
        manageAccessToken: String? = nil
    ) async -> RaceStart? {
        guard !isSubmittingActualStart else { return nil }
        guard let startId = start.rawId ?? start.slug else {
            actualStartSubmitError = NSLocalizedString("set_start_time_error_start_identifier_missing", comment: "")
            return nil
        }

        isSubmittingActualStart = true
        actualStartSubmitError = nil
        defer { isSubmittingActualStart = false }

        do {
            let updatedStart = try await service.updateStartActualTime(
                startId: startId,
                actualUtc: actualUtc,
                updatedBy: updatedBy,
                accessToken: manageAccessToken
            )
            patchSelectedRaceStart(with: updatedStart)
            return updatedStart
        } catch {
            actualStartSubmitError = error.localizedDescription
            return nil
        }
    }

    func clearActualStartSubmitError() {
        actualStartSubmitError = nil
    }

    /// Resets (clears) `actual_utc` for a start, reverting it to scheduled-only state.
    func resetActualStartTime(
        for start: RaceStart,
        manageAccessToken: String? = nil
    ) async -> RaceStart? {
        guard !isSubmittingActualStart else { return nil }
        guard let startId = start.rawId ?? start.slug else {
            actualStartSubmitError = NSLocalizedString("set_start_time_error_start_identifier_missing", comment: "")
            return nil
        }

        isSubmittingActualStart = true
        actualStartSubmitError = nil
        defer { isSubmittingActualStart = false }

        do {
            let updatedStart = try await service.resetStartActualTime(
                startId: startId,
                accessToken: manageAccessToken
            )
            patchSelectedRaceStart(with: updatedStart)
            return updatedStart
        } catch {
            actualStartSubmitError = error.localizedDescription
            return nil
        }
    }

    /// Returns the UI-ready start-time state used by Start Detail metadata rendering.
    func actualStartHeaderState(for start: RaceStart, now: Date = Date()) -> ActualStartHeaderState {
        if let actualStartDate = start.actualStartDate {
            if actualStartDate > now {
                let countdown = DateFormattingHelper.actualStartCountdownString(to: actualStartDate, now: now)
                return .countdown(timeToStartText: countdown)
            }

            let startedTime = DateFormattingHelper.localizedHourMinute(from: actualStartDate)
            return .started(actualLocalTimeText: startedTime)
        }

        return .scheduled(timeText: formattedStartTime(for: start))
    }

    /// Core race fetch implementation (optionally clearing cached selections).
    private func loadRaces(force: Bool) async {
        if isLoadingRaces {
            return
        }
        if !force && !raceItems.isEmpty {
            return
        }
        isLoadingRaces = true
        raceError = nil
        if force {
            selectedRace = nil
            selectedRaceStarts = []
        }
        do {
            let series = try await service.fetchRaceSeries()
            let summaries = series.flatMap { seriesItem in
                seriesItem.races.map { race in
                    RaceSummary(
                        race: race,
                        seriesName: seriesItem.name,
                        seriesId: seriesItem.rawId ?? seriesItem.slug,
                        seriesImageId: seriesItem.imageId,
                        raceImageId: race.imageId
                    )
                }
            }
            let sorted = summaries.sorted(by: { lhs, rhs in
                lhs.race.nameOrFallback.localizedCaseInsensitiveCompare(rhs.race.nameOrFallback) == .orderedAscending
            })
            raceItems = sorted
            if let previousId = selectedRace?.id, let matched = sorted.first(where: { $0.id == previousId }) {
                selectedRace = matched
            } else if force {
                selectedRace = nil
                selectedRaceStarts = []
            }
            isLoadingRaces = false
        } catch {
            raceError = error.localizedDescription
            isLoadingRaces = false
        }
    }

    /// Fetches and sorts starts for a specific race (optionally bypassing in-flight requests).
    private func loadStarts(for race: Race, force: Bool) async {
        if isLoadingStarts && !force {
            return
        }
        isLoadingStarts = true
        startError = nil
        selectedRaceStarts = []
        do {
            let starts = try await service.fetchStarts(for: race)
            selectedRaceStarts = starts.sorted(by: { lhs, rhs in
                (lhs.scheduledUTC ?? "") < (rhs.scheduledUTC ?? "")
            })
            isLoadingStarts = false
        } catch {
            startError = error.localizedDescription
            isLoadingStarts = false
        }
    }

    func starts(for summary: RaceSummary) -> [RaceStart] {
        guard selectedRace?.id == summary.id else { return [] }
        return selectedRaceStarts
    }

    func startError(for summary: RaceSummary) -> String? {
        guard selectedRace?.id == summary.id else { return nil }
        return startError
    }

    func isLoadingStarts(for summary: RaceSummary) -> Bool {
        selectedRace?.id == summary.id && isLoadingStarts
    }

    private func patchSelectedRaceStart(with updatedStart: RaceStart) {
        guard let updatedId = updatedStart.rawId ?? updatedStart.slug else { return }
        guard let index = selectedRaceStarts.firstIndex(where: { ($0.rawId ?? $0.slug) == updatedId }) else { return }
        selectedRaceStarts[index] = updatedStart
    }
}
