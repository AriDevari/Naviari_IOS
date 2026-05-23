import Foundation
import OSLog

/// Owns race-level course state loading, template loading, and shared copy.
///
/// This ViewModel exists separately from `RaceBrowserViewModel` because the
/// race-detail course logic has a distinct lifetime (one race at a time) and
/// must enforce the race-level access-token scope rule (start-scoped tokens
/// are explicitly rejected here even when otherwise valid).
///
/// All `@Published` mutations happen on the main actor so SwiftUI updates stay
/// on the main thread.
@MainActor
final class RaceDetailViewModel: ObservableObject {
    // MARK: - Published state

    /// Aggregated course state across the race's starts. Defaults to `.loading`
    /// so the section view can render a loading branch before the first fetch.
    @Published var courseState: RaceCourseState = .loading

    /// Course templates available for the race's series. Populated by
    /// `loadTemplates(seriesId:)` and consumed by the State A template picker.
    @Published var courseTemplates: [RaceCourse] = []

    /// True while template loading is in flight.
    @Published var isLoadingTemplates: Bool = false

    /// True while a race-level shared copy is in flight.
    @Published var isCopying: Bool = false

    /// Number of successful links in the last race-level copy attempt.
    @Published var copySuccessCount: Int = 0

    /// Number of failed links in the last race-level copy attempt.
    @Published var copyFailureCount: Int = 0

    /// True when a `.race` or `.series` scoped manage-access token is cached
    /// for this race. `.start` scoped tokens never satisfy this.
    @Published var hasValidRaceLevelToken: Bool = false

    // MARK: - Stored properties

    let raceId: String
    let seriesId: String?
    let raceService: RaceService

    private let manageAccessStorage: ManageAccessStorage
    private let logger = Logger(subsystem: "fi.mobiari.naviari-ios", category: "RaceDetailViewModel")

    /// Scope of the most recently loaded cached token. Updated by
    /// `reloadToken()`.
    private(set) var storedScope: ManageAccessScope?

    /// Scope id of the most recently loaded cached token. Updated by
    /// `reloadToken()`.
    private(set) var storedScopeId: String?

    /// Token value of the most recently loaded cached token. Updated by
    /// `reloadToken()`.
    private(set) var storedToken: String?

    // MARK: - Init

    init(
        raceId: String,
        seriesId: String?,
        raceService: RaceService = RaceService(),
        manageAccessStorage: ManageAccessStorage = .shared
    ) {
        self.raceId = raceId
        self.seriesId = seriesId
        self.raceService = raceService
        self.manageAccessStorage = manageAccessStorage
    }

    // MARK: - Test helpers

    /// Test-only seam for seeding the stored token state without touching
    /// `ManageAccessStorage`. Used by `RaceDetailViewModelTests` to exercise
    /// the `storedTokenIsValidAtRaceLevel` predicate for each scope value.
    /// Not intended for production callers.
    func _seedStoredTokenForTesting(scope: ManageAccessScope?, scopeId: String?, token: String?) {
        storedScope = scope
        storedScopeId = scopeId
        storedToken = token
        hasValidRaceLevelToken = storedTokenIsValidAtRaceLevel
    }

    // MARK: - Token scope

    /// Re-reads the cached manage-access token using race-level lookup
    /// (`startId: nil`) and refreshes `hasValidRaceLevelToken`.
    func reloadToken() {
        let record = manageAccessStorage.loadToken(for: nil, raceId: raceId, seriesId: seriesId)
        storedScope = record?.scope
        storedScopeId = record?.scopeId
        storedToken = record?.token
        hasValidRaceLevelToken = storedTokenIsValidAtRaceLevel
    }

    /// Predicate enforcing the race-level token scope rule.
    ///
    /// - `.race`   accepted when `scopeId == raceId`
    /// - `.series` accepted when `scopeId == seriesId` (and `seriesId` is known)
    /// - `.start`  always rejected, even if `scopeId` happens to match a start
    ///   in this race. Race-level course copy applies to all starts; a
    ///   start-scoped token only authorizes one start.
    var storedTokenIsValidAtRaceLevel: Bool {
        guard let scope = storedScope, let scopeId = storedScopeId else {
            return false
        }
        switch scope {
        case .race:
            return scopeId == raceId
        case .series:
            guard let seriesId else { return false }
            return scopeId == seriesId
        case .start:
            return false
        }
    }

    // MARK: - Course state

    /// Fetches `StartDetailResponse` for every start in parallel and derives
    /// the aggregated `RaceCourseState`.
    ///
    /// Derivation rules:
    /// - 0 starts → `.noStarts`
    /// - all `course == nil` → `.noneSet`
    /// - all `course?.id` equal → `.allSameId(course)`
    /// - otherwise → `.mixedSet`
    /// - any throw from a per-start fetch → `.error(localizedDescription)`
    func loadCourseState(starts: [RaceStart]) async {
        guard !starts.isEmpty else {
            courseState = .noStarts
            return
        }

        courseState = .loading

        // Resolve start ids first; skip starts that have no usable identifier
        // (they cannot be queried). If everything is skipped, surface noStarts.
        let identifiedStarts: [(start: RaceStart, id: String)] = starts.compactMap { start in
            guard let id = start.rawId ?? start.slug else { return nil }
            return (start, id)
        }

        guard !identifiedStarts.isEmpty else {
            courseState = .noStarts
            return
        }

        do {
            let details = try await withThrowingTaskGroup(of: StartDetailResponse.self) { group -> [StartDetailResponse] in
                for entry in identifiedStarts {
                    group.addTask { [raceService] in
                        try await raceService.fetchStartDetail(startId: entry.id)
                    }
                }
                var collected: [StartDetailResponse] = []
                collected.reserveCapacity(identifiedStarts.count)
                for try await detail in group {
                    collected.append(detail)
                }
                return collected
            }

            courseState = Self.deriveCourseState(from: details)
        } catch {
            logger.error("loadCourseState failed: \(error.localizedDescription, privacy: .public)")
            courseState = .error(error.localizedDescription)
        }
    }

    /// Pure derivation of `RaceCourseState` from a collection of detail
    /// responses. Exposed via `internal` so tests can exercise it directly
    /// without needing the network layer.
    static func deriveCourseState(from details: [StartDetailResponse]) -> RaceCourseState {
        guard !details.isEmpty else { return .noStarts }

        let courses = details.map { $0.course }

        let allNil = courses.allSatisfy { $0 == nil }
        if allNil {
            return .noneSet
        }

        let allSet = courses.allSatisfy { $0 != nil }
        if allSet, let firstCourse = courses.compactMap({ $0 }).first {
            let firstId = firstCourse.id
            let allSameId = courses.allSatisfy { $0?.id == firstId }
            if allSameId {
                return .allSameId(firstCourse)
            }
        }

        return .mixedSet
    }

    // MARK: - Templates

    /// Loads available course templates for the race's series.
    ///
    /// Mirrors `StartDetailScreen.loadCourseTemplatesIfNeeded` but lives here
    /// so the race-level section can decide when to fetch.
    func loadTemplates(seriesId: String) async {
        isLoadingTemplates = true
        defer { isLoadingTemplates = false }

        do {
            let templates = try await raceService.fetchCourseTemplates(seriesId: seriesId)
            courseTemplates = templates.sorted { lhs, rhs in
                courseTemplateDisplayName(lhs).localizedCaseInsensitiveCompare(courseTemplateDisplayName(rhs)) == .orderedAscending
            }
        } catch {
            logger.error("loadTemplates failed: \(error.localizedDescription, privacy: .public)")
            // Templates failure does not mutate courseState — the picker UI
            // surfaces its own empty / error branch.
            courseTemplates = []
        }
    }

    // MARK: - Shared race copy

    /// Copies one template once for the race and links that shared course to
    /// all starts in the race.
    func copyTemplateToRace(
        templateId: String,
        starts: [RaceStart],
        accessToken: String
    ) async {
        guard !starts.isEmpty else {
            copySuccessCount = 0
            copyFailureCount = 0
            return
        }

        // Resolve the template once so per-start name/description parity
        // matches `StartDetailScreen.copyTemplateToStart`.
        let template = courseTemplates.first(where: { $0.id == templateId })
        let templateName = Self.normalizedOptionalText(template?.name)
        let templateDescription = Self.normalizedOptionalText(template?.description)

        let identifiedStarts: [(start: RaceStart, id: String)] = starts.compactMap { start in
            guard let id = start.rawId ?? start.slug else { return nil }
            return (start, id)
        }

        guard !identifiedStarts.isEmpty else {
            copySuccessCount = 0
            copyFailureCount = 0
            return
        }

        isCopying = true
        copySuccessCount = 0
        copyFailureCount = 0
        defer { isCopying = false }

        do {
            let result = try await raceService.copyCourseTemplateToRace(
                raceId: raceId,
                templateCourseId: templateId,
                accessToken: accessToken,
                name: templateName,
                description: templateDescription,
                updatedBy: "ios-race-detail"
            )
            copySuccessCount = result.linkedStartCount
            copyFailureCount = max(0, result.totalStartCount - result.linkedStartCount)
        } catch {
            logger.error("copyTemplateToRace failed: \(error.localizedDescription, privacy: .public)")
            copySuccessCount = 0
            copyFailureCount = identifiedStarts.count
        }

        await loadCourseState(starts: starts)
    }

    // MARK: - Helpers

    /// Trims whitespace and returns nil when the resulting string is empty.
    /// Mirrors `StartDetailScreen.normalizedOptionalText` so race-level copy
    /// behaves the same as start-level copy.
    private static func normalizedOptionalText(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
