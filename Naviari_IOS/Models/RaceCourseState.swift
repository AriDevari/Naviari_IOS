import Foundation

/// Aggregated course-assignment state across all starts in a race.
///
/// `RaceDetailViewModel.loadCourseState(starts:)` derives this enum by
/// fetching `StartDetailResponse` for every start in parallel and inspecting
/// each `course?.id`. The race-level course section in S2/S3 will switch on
/// this enum to render the correct branch (template picker, mixed label,
/// shared course display, or hidden when there are no starts).
enum RaceCourseState {
    /// Initial state while start details are being fetched.
    case loading
    /// A blocking error reached the ViewModel during the load. The associated
    /// message is presented in the section's error branch.
    case error(String)
    /// State A — all starts have `course == nil`. Template picker is available.
    case noneSet
    /// State B — some starts have a course assigned, others do not.
    /// Informational only; no race-level action is offered.
    case mixedSet
    /// State C — every start points to the same course. The associated course
    /// is rendered through the existing `CourseTimelineView` component.
    case allSameId(RaceCourse)
    /// Race has zero starts. The course section is hidden entirely.
    case noStarts
}
