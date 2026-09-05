//
//  Naviari_IOSApp.swift
//  Naviari_IOS
//
//  Created by Ari Peltoniemi on 4.2.2026.
//

import SwiftUI
import SwiftData
import UIKit

enum AppUI {
    static let primaryButtonHeight: CGFloat = Theme.Sizing.primaryButtonHeight
    static let buttonFont: Font = Theme.Typography.button
    static let brandPrimary = Theme.Colors.brandPrimary
    static let brandPrimaryMuted = Theme.Colors.brandPrimaryMuted
}

/// Main entry point that wires together shared environment objects + background schedulers.
@main
struct Naviari_IOSApp: App {
    @StateObject private var locationManager = LocationDataManager()
    @StateObject private var boatMetricsUploader = BoatMetricsUploader()
    @Environment(\.scenePhase) private var scenePhase
    private let uiTestScenario = CourseEditUITestScenario.current
    private let startDetailCourseReplacementScenario = StartDetailCourseReplacementUITestScenario.current
    private let startDetailCourseManagementScenario = StartDetailCourseManagementUITestScenario.current
    private let raceCourseSectionScenario = RaceCourseSectionUITestScenario.current
    private let raceDetailScreenScenario = RaceDetailScreenUITestScenario.current
    private let buoySectionScenario = BuoySectionUITestScenario.current
    private let manageAccessContinuationScenario = ManageAccessContinuationUITestScenario.current

    /// True when any UITest harness is active. Production launches always
    /// see `false` here, so all schedulers and managers boot normally.
    private var isUITestActive: Bool {
        uiTestScenario != nil
            || startDetailCourseReplacementScenario != nil
            || startDetailCourseManagementScenario != nil
            || raceCourseSectionScenario != nil
            || raceDetailScreenScenario != nil
            || buoySectionScenario != nil
            || manageAccessContinuationScenario != nil
    }

    init() {
        if CourseEditUITestScenario.current == nil
            && StartDetailCourseReplacementUITestScenario.current == nil
            && StartDetailCourseManagementUITestScenario.current == nil
            && RaceCourseSectionUITestScenario.current == nil
            && RaceDetailScreenUITestScenario.current == nil
            && BuoySectionUITestScenario.current == nil
            && ManageAccessContinuationUITestScenario.current == nil {
            BoatMetricsBackgroundScheduler.shared.register()
        }
        if StartDetailCourseReplacementUITestScenario.current != nil {
            StartDetailCourseReplacementUITestURLProtocol.reset()
            URLProtocol.registerClass(StartDetailCourseReplacementUITestURLProtocol.self)
            UserDefaults.standard.removeObject(forKey: "manage_access_tokens")
            UserDefaults.standard.removeObject(forKey: "participation_tokens")
            UserDefaults.standard.removeObject(forKey: "participation_records")
        }
        if let scenario = StartDetailCourseManagementUITestScenario.current {
            StartDetailCourseManagementUITestURLProtocol.reset(for: scenario)
            URLProtocol.registerClass(StartDetailCourseManagementUITestURLProtocol.self)
            UserDefaults.standard.removeObject(forKey: "manage_access_tokens")
            UserDefaults.standard.removeObject(forKey: "manage_access_tokens_v2")
            UserDefaults.standard.removeObject(forKey: "manage_access_tokens_schema_version")
            UserDefaults.standard.removeObject(forKey: "participation_tokens")
            UserDefaults.standard.removeObject(forKey: "participation_records")
        }
        // Register the RaceDetailScreen URLProtocol up front so the
        // intercept is active before any `URLSession.shared` request fires.
        if let scenario = RaceDetailScreenUITestScenario.current {
            RaceDetailScreenUITestURLProtocol.reset(for: scenario)
            URLProtocol.registerClass(RaceDetailScreenUITestURLProtocol.self)
            UserDefaults.standard.removeObject(forKey: "manage_access_tokens")
            UserDefaults.standard.removeObject(forKey: "participation_tokens")
        }
        if ManageAccessContinuationUITestScenario.current != nil {
            ManageAccessContinuationUITestURLProtocol.reset()
            URLProtocol.registerClass(ManageAccessContinuationUITestURLProtocol.self)
            UserDefaults.standard.removeObject(forKey: "manage_access_tokens")
            UserDefaults.standard.removeObject(forKey: "manage_access_tokens_v2")
            UserDefaults.standard.removeObject(forKey: "manage_access_tokens_schema_version")
            UserDefaults.standard.removeObject(forKey: "participation_tokens")
            UserDefaults.standard.removeObject(forKey: "participation_records")
        }
        configureTypographyAppearance()
    }
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.font, AppFont.textStyle(.body))
                .environmentObject(locationManager)
                .environmentObject(boatMetricsUploader)
                .onAppear {
                    guard !isUITestActive else { return }
                    locationManager.start()
                    boatMetricsUploader.configure(with: locationManager)
                    BoatMetricsBackgroundScheduler.shared.configure(uploader: boatMetricsUploader)
                }
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { _, phase in
            guard !isUITestActive else { return }
            if phase == .background {
                BoatMetricsBackgroundScheduler.shared.scheduleIfNeeded()
            }
        }
    }

    private func configureTypographyAppearance() {
        let titleFont = UIFont(name: "Nunito-SemiBold", size: 17) ?? UIFont.systemFont(ofSize: 17, weight: .semibold)
        let largeTitleFont = UIFont(name: "Nunito-Bold", size: 34) ?? UIFont.systemFont(ofSize: 34, weight: .bold)
        let barButtonFont = UIFont(name: "Nunito-Regular", size: 17) ?? UIFont.systemFont(ofSize: 17)

        UINavigationBar.appearance().titleTextAttributes = [.font: titleFont]
        UINavigationBar.appearance().largeTitleTextAttributes = [.font: largeTitleFont]
        UIBarButtonItem.appearance().setTitleTextAttributes([.font: barButtonFont], for: .normal)
    }
}
