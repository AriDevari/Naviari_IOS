import Foundation
#if canImport(BackgroundTasks)
import BackgroundTasks
#endif
import OSLog

/// Coordinates BGProcessingTasks so buffered telemetry can flush even during long background sessions.
@MainActor
final class BoatMetricsBackgroundScheduler {
    static let shared = BoatMetricsBackgroundScheduler()
    private init() {}

    private weak var uploader: BoatMetricsUploader?
    private let taskIdentifier = "fi.mobiari.naviari-ios.boatmetrics.flush"
    private let logger = Logger(subsystem: "fi.mobiari.naviari-ios", category: "BoatMetricsBackgroundScheduler")

    /// Assigns the uploader whose backlog should be flushed during BG tasks.
    func configure(uploader: BoatMetricsUploader) {
        self.uploader = uploader
    }

    /// Registers the BG task identifier; call once during app launch.
    /// Registers the BGProcessing identifier; call once during app launch.
    func register() {
#if canImport(BackgroundTasks)
        if #available(iOS 13.0, *) {
            BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { [weak self] task in
                self?.handle(task: task)
            }
        }
#endif
    }

    /// Schedules (or cancels) the BGProcessing request depending on broadcast state.
    /// Schedules (or cancels) the BGProcessing request depending on broadcast state.
    func scheduleIfNeeded() {
#if canImport(BackgroundTasks)
        guard #available(iOS 13.0, *) else { return }
        guard let uploader, uploader.isBroadcasting else {
            cancelScheduledTasks()
            return
        }
        let request = BGProcessingTaskRequest(identifier: taskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 5 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
            logger.debug("Scheduled boat metrics background task")
        } catch {
            logger.error("Failed to schedule BG task: \(error.localizedDescription, privacy: .public)")
        }
#endif
    }

    /// Cancels any pending BGProcessing requests (e.g., when broadcasting stops).
    func cancelScheduledTasks() {
        #if canImport(BackgroundTasks)
        guard #available(iOS 13.0, *) else { return }
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskIdentifier)
        #endif
    }

    /// Invoked by BGTaskScheduler; flushes uploads and reschedules the next request.
    private func handle(task: BGTask) {
#if canImport(BackgroundTasks)
        guard #available(iOS 13.0, *) else {
            task.setTaskCompleted(success: false)
            return
        }
        guard let processingTask = task as? BGProcessingTask else {
            task.setTaskCompleted(success: false)
            return
        }
        processingTask.expirationHandler = { [weak self] in
            self?.logger.error("Boat metrics BG task expired before completion")
        }
        Task { @MainActor in
            if let uploader {
                uploader.flushPendingUploads()
            }
            processingTask.setTaskCompleted(success: true)
            scheduleIfNeeded()
        }
#else
        task.setTaskCompleted(success: false)
#endif
    }
}
