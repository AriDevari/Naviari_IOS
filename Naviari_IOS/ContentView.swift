//
//  ContentView.swift
//  Naviari
//
//  Created by Ari Peltoniemi on 4.2.2026.
//

import SwiftUI

/// Root navigation stack for the iOS app (welcome → races → starts → participate).
struct ContentView: View {
    @StateObject private var viewModel = RaceBrowserViewModel()
    @State private var navigationPath: [AppRoute] = []
    @EnvironmentObject private var locationManager: LocationDataManager
    @EnvironmentObject private var metricsUploader: BoatMetricsUploader

    var body: some View {
        ZStack {
            NavigationStack(path: $navigationPath) {
                WelcomeScreen {
                    navigationPath.append(.races)
                }
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .races:
                        RaceListScreen { summary in
                            navigationPath.append(.raceDetail(summary))
                        }
                    case let .raceDetail(summary):
                        RaceDetailScreen(summary: summary) { start in
                            navigationPath.append(.startDetail(summary, start))
                        }
                    case let .startDetail(summary, start):
                        StartDetailScreen(raceSummary: summary, start: start) {
                            navigationPath.append(.participate(summary, start))
                        }
                    case let .participate(summary, start):
                        ParticipateView(raceSummary: summary, start: start)
                    }
                }
            }
            if metricsUploader.isBroadcasting {
                BroadcastStatusButton(uploader: metricsUploader)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(.leading, 24)
                    .padding(.bottom, 24)
            }

            GPSStatusButton(locationManager: locationManager)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 24)
                .padding(.bottom, 24)
        }
        .environmentObject(viewModel)
    }
}

/// Typed routes for the root NavigationStack.
private enum AppRoute: Hashable {
    case races
    case raceDetail(RaceSummary)
    case startDetail(RaceSummary, RaceStart)
    case participate(RaceSummary, RaceStart)
}
#Preview {
    ContentView()
        .environmentObject(LocationDataManager())
        .environmentObject(BoatMetricsUploader())
}
