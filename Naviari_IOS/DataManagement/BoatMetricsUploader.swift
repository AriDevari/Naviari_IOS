import Foundation
import CoreLocation
import Combine
#if canImport(UIKit)
import UIKit
#endif

struct BroadcastSession {
    let token: String
    let boatToken: String?
    let startEntryId: String
    let startId: String?
    let boatId: String?
    let raceId: String?
    let seriesId: String?
    let summary: ParticipationSummary
}

struct BoatMetricRow: Codable, Hashable {
    let timestampMs: Int64
    let latitude: Double
    let longitude: Double
    let sog: Double
    let sogAvg: Double?
    let cog: Double
    let cogAvg: Double?
    let accuracy: Double
}

@MainActor
final class BoatMetricsUploader: ObservableObject {
    @Published private(set) var isBroadcasting = false
    @Published private(set) var lastAcceptedSample: BoatSample?
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var lastSendAt: Date?
    @Published private(set) var activeSession: BroadcastSession?
    @Published private(set) var backlogSeconds: Int = 0
    @Published private(set) var retryCount: Int = 0
    @Published private(set) var lastErrorAt: Date?

    private let metricsService = BoatMetricsService()

    private var locationCancellable: AnyCancellable?
    private weak var locationManager: LocationDataManager?

    private var lastDeliveredSecond: Int?
    private var lastSuccessfulSecond: Int?
    private var isSending = false
    private var pendingRetryRows: [BoatMetricRow] = []
    private var pendingRetryRange: (start: Int, end: Int)?
#if canImport(UIKit)
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
#endif

    private(set) var sampleBuffer: [BoatSample] = []

    func configure(with manager: LocationDataManager) {
        guard locationManager !== manager else { return }
        locationManager = manager
        locationCancellable = manager.$acceptedSamples
            .compactMap { $0.last }
            .sink { [weak self] in self?.handle(sample: $0) }
    }

    func startBroadcast(session: BroadcastSession) {
        activeSession = session
        isBroadcasting = true
        sampleBuffer.removeAll(keepingCapacity: true)
        lastAcceptedSample = nil
        lastDeliveredSecond = nil
        lastSuccessfulSecond = nil
        pendingRetryRows = []
        pendingRetryRange = nil
        lastErrorMessage = nil
        lastErrorAt = nil
        backlogSeconds = 0
        retryCount = 0
        activeSession = session
        BoatMetricsBackgroundScheduler.shared.scheduleIfNeeded()
    }

    func stopBroadcast() {
        isBroadcasting = false
        sampleBuffer.removeAll()
        lastAcceptedSample = nil
        lastDeliveredSecond = nil
        lastSuccessfulSecond = nil
        pendingRetryRows = []
        pendingRetryRange = nil
        lastErrorMessage = nil
        lastErrorAt = nil
        backlogSeconds = 0
        retryCount = 0
        activeSession = nil
        endBackgroundTaskIfNeeded()
        BoatMetricsBackgroundScheduler.shared.cancelScheduledTasks()
    }

    private func handle(sample: BoatSample) {
        guard isBroadcasting, activeSession != nil else { return }
        sampleBuffer.append(sample)
        if sampleBuffer.count > 600 {
            sampleBuffer.removeFirst(sampleBuffer.count - 600)
        }
        lastAcceptedSample = sample
        let latestSecond = Int(sample.timestamp.timeIntervalSince1970)
        updateBacklog(latestSecond: latestSecond)
        processUploadQueue(latestSecond: latestSecond)
    }

    private func processUploadQueue(latestSecond: Int) {
        guard !isSending, let session = activeSession else { return }
        if !pendingRetryRows.isEmpty, let range = pendingRetryRange {
            send(rows: pendingRetryRows, range: range, session: session)
            return
        }
        guard let earliestSample = sampleBuffer.first else { return }
        let startCandidate = max(
            (lastDeliveredSecond ?? Int(earliestSample.timestamp.timeIntervalSince1970)) + 1,
            Int(earliestSample.timestamp.timeIntervalSince1970)
        )
        let availableSeconds = latestSecond - startCandidate + 1
        guard availableSeconds >= 10 else { return }
        let catchUp = if let lastSuccess = lastSuccessfulSecond {
            latestSecond - lastSuccess > 60
        } else {
            false
        }
        let chunkLength = catchUp ? min(60, availableSeconds) : min(10, availableSeconds)
        let chunkStart = startCandidate
        let chunkEnd = chunkStart + chunkLength - 1
        let rows = resampleSeconds(from: chunkStart, to: chunkEnd)
        guard !rows.isEmpty else {
            lastDeliveredSecond = chunkEnd
            processUploadQueue(latestSecond: latestSecond)
            return
        }
        send(rows: rows, range: (chunkStart, chunkEnd), session: session)
    }

    private func send(rows: [BoatMetricRow], range: (start: Int, end: Int), session: BroadcastSession) {
        guard !rows.isEmpty else { return }
        isSending = true
        beginBackgroundTaskIfNeeded()
        Task {
            do {
                try await metricsService.submit(
                    token: session.token,
                    boatToken: session.boatToken,
                    startEntryId: session.startEntryId,
                    startId: session.startId,
                    boatId: session.boatId,
                    samples: rows
                )
                await MainActor.run {
                    lastSuccessfulSecond = range.end
                    lastDeliveredSecond = range.end
                    lastSendAt = Date()
                    lastErrorMessage = nil
                    lastErrorAt = nil
                    pendingRetryRows = []
                    pendingRetryRange = nil
                    pruneBuffer(olderThan: range.end - 60)
                    updateBacklog(latestSecond: latestBufferedSecond())
                    isSending = false
                    BoatMetricsBackgroundScheduler.shared.scheduleIfNeeded()
                    endBackgroundTaskIfNeeded()
                    if let latest = sampleBuffer.last {
                        processUploadQueue(latestSecond: Int(latest.timestamp.timeIntervalSince1970))
                    }
                }
            } catch {
                await MainActor.run {
                    lastErrorMessage = error.localizedDescription
                    lastErrorAt = Date()
                    retryCount += 1
                    pendingRetryRows = rows
                    pendingRetryRange = range
                    updateBacklog(latestSecond: latestBufferedSecond())
                    isSending = false
                    BoatMetricsBackgroundScheduler.shared.scheduleIfNeeded()
                    endBackgroundTaskIfNeeded()
                }
            }
        }
    }

    private func pruneBuffer(olderThan second: Int) {
        sampleBuffer.removeAll(where: { Int($0.timestamp.timeIntervalSince1970) < second })
    }

    private func resampleSeconds(from start: Int, to end: Int) -> [BoatMetricRow] {
        guard start <= end else { return [] }
        var rows: [BoatMetricRow] = []
        for second in start...end {
            guard let interpolated = interpolatedSample(at: second) else { continue }
            let avg = rollingAverage(endingAt: second, target: interpolated)
            let timestampMs = Int64(interpolated.timestamp.timeIntervalSince1970 * 1000)
            rows.append(
                BoatMetricRow(
                    timestampMs: timestampMs,
                    latitude: interpolated.coordinate.latitude,
                    longitude: interpolated.coordinate.longitude,
                    sog: metersPerSecondToKnots(interpolated.speed),
                    sogAvg: avg?.speed,
                    cog: interpolated.course,
                    cogAvg: avg?.course,
                    accuracy: interpolated.accuracy
                )
            )
        }
        return rows
    }

    private func interpolatedSample(at second: Int) -> BoatSample? {
        guard let first = sampleBuffer.first, let last = sampleBuffer.last else { return nil }
        let targetTime = Date(timeIntervalSince1970: TimeInterval(second))
        if targetTime < first.timestamp || targetTime > last.timestamp {
            return nil
        }
        var before: BoatSample = first
        var after: BoatSample = last
        for sample in sampleBuffer {
            if sample.timestamp <= targetTime {
                before = sample
            }
            if sample.timestamp >= targetTime {
                after = sample
                break
            }
        }
        if after.timestamp == before.timestamp {
            return before
        }
        let total = after.timestamp.timeIntervalSince(before.timestamp)
        let elapsed = targetTime.timeIntervalSince(before.timestamp)
        let ratio = max(0, min(1, elapsed / total))
        let lat = lerp(from: before.coordinate.latitude, to: after.coordinate.latitude, ratio: ratio)
        let lon = lerp(from: before.coordinate.longitude, to: after.coordinate.longitude, ratio: ratio)
        let speed = lerp(from: before.speed, to: after.speed, ratio: ratio)
        let course = lerpCourse(from: before.course, to: after.course, ratio: ratio)
        let accuracy = lerp(from: before.accuracy, to: after.accuracy, ratio: ratio)
        return BoatSample(
            timestamp: targetTime,
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            speed: speed,
            course: course,
            accuracy: accuracy
        )
    }

    private func rollingAverage(endingAt second: Int, target: BoatSample) -> (speed: Double, course: Double)? {
        let windowStart = second - 10
        let window = sampleBuffer.filter { Int($0.timestamp.timeIntervalSince1970) >= windowStart && Int($0.timestamp.timeIntervalSince1970) <= second }
        guard !window.isEmpty else { return nil }
        let avgSpeed = window.map(\.speed).reduce(0, +) / Double(window.count)
        let avgCourse = averageCourse(window.map(\.course))
        return (metersPerSecondToKnots(avgSpeed), avgCourse)
    }

    private func latestBufferedSecond() -> Int? {
        guard let latest = sampleBuffer.last else { return nil }
        return Int(latest.timestamp.timeIntervalSince1970)
    }

    private func updateBacklog(latestSecond: Int?) {
        guard let latestSecond else {
            backlogSeconds = 0
            return
        }
        if let success = lastSuccessfulSecond {
            backlogSeconds = max(0, latestSecond - success)
        } else if let earliest = sampleBuffer.first {
            let earliestSecond = Int(earliest.timestamp.timeIntervalSince1970)
            backlogSeconds = max(0, latestSecond - earliestSecond)
        } else {
            backlogSeconds = 0
        }
    }

    func flushPendingUploads() {
        guard let latest = sampleBuffer.last else { return }
        processUploadQueue(latestSecond: Int(latest.timestamp.timeIntervalSince1970))
    }

    private func beginBackgroundTaskIfNeeded() {
#if canImport(UIKit)
        guard backgroundTaskIdentifier == .invalid else { return }
        backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(withName: "BoatMetricsUpload") { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.endBackgroundTaskIfNeeded()
            }
        }
#endif
    }

    private func endBackgroundTaskIfNeeded() {
#if canImport(UIKit)
        guard backgroundTaskIdentifier != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
        backgroundTaskIdentifier = .invalid
#endif
    }

    private func metersPerSecondToKnots(_ value: Double) -> Double {
        value * 1.943844
    }

    private func lerp(from: Double, to: Double, ratio: Double) -> Double {
        from + (to - from) * ratio
    }

    private func lerpCourse(from: Double, to: Double, ratio: Double) -> Double {
        let diff = shortestCourseDelta(from: from, to: to)
        var course = from + diff * ratio
        if course < 0 { course += 360 }
        if course >= 360 { course -= 360 }
        return course
    }

    private func shortestCourseDelta(from: Double, to: Double) -> Double {
        var difference = to - from
        while difference < -180 { difference += 360 }
        while difference > 180 { difference -= 360 }
        return difference
    }

    private func averageCourse(_ courses: [Double]) -> Double {
        guard !courses.isEmpty else { return 0 }
        let radians = courses.map { $0 * .pi / 180 }
        let x = radians.reduce(0) { $0 + cos($1) }
        let y = radians.reduce(0) { $0 + sin($1) }
        let avg = atan2(y / Double(courses.count), x / Double(courses.count)) * 180 / .pi
        return avg >= 0 ? avg : avg + 360
    }

}
