import Foundation

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
            from: start.scheduledUTC ?? start.actualUTC,
            includeTime: true
        )
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
                        seriesId: seriesItem.rawId ?? seriesItem.slug
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
                (lhs.scheduledUTC ?? lhs.actualUTC ?? "") < (rhs.scheduledUTC ?? rhs.actualUTC ?? "")
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
}
