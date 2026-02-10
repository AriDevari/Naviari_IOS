//
//  Naviari_IOSApp.swift
//  Naviari_IOS
//
//  Created by Ari Peltoniemi on 4.2.2026.
//

import SwiftUI
import SwiftData

@main
struct Naviari_IOSApp: App {
    @StateObject private var locationManager = LocationDataManager()
    @StateObject private var boatMetricsUploader = BoatMetricsUploader()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        BoatMetricsBackgroundScheduler.shared.register()
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
}
