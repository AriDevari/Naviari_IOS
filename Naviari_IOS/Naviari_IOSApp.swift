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
    static let primaryButtonHeight: CGFloat = 66
    static let buttonFont: Font = AppFont.fixed(21, weight: .semibold)
    static let brandPrimary = Color(red: 241 / 255, green: 133 / 255, blue: 16 / 255)
    static let brandPrimaryMuted = brandPrimary.opacity(0.15)
}

/// Main entry point that wires together shared environment objects + background schedulers.
@main
struct Naviari_IOSApp: App {
    @StateObject private var locationManager = LocationDataManager()
    @StateObject private var boatMetricsUploader = BoatMetricsUploader()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        BoatMetricsBackgroundScheduler.shared.register()
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
                    locationManager.start()
                    boatMetricsUploader.configure(with: locationManager)
                    BoatMetricsBackgroundScheduler.shared.configure(uploader: boatMetricsUploader)
                }
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { phase in
            if phase == .background {
                BoatMetricsBackgroundScheduler.shared.scheduleIfNeeded()
            }
        }
    }

    private func configureTypographyAppearance() {
        let titleFont = UIFont(name: "Nunito-Regular", size: 17) ?? UIFont.systemFont(ofSize: 17, weight: .semibold)
        let largeTitleFont = UIFont(name: "Nunito-Regular", size: 34) ?? UIFont.systemFont(ofSize: 34, weight: .bold)
        let barButtonFont = UIFont(name: "Nunito-Regular", size: 17) ?? UIFont.systemFont(ofSize: 17)

        UINavigationBar.appearance().titleTextAttributes = [.font: titleFont]
        UINavigationBar.appearance().largeTitleTextAttributes = [.font: largeTitleFont]
        UIBarButtonItem.appearance().setTitleTextAttributes([.font: barButtonFont], for: .normal)
    }
}
