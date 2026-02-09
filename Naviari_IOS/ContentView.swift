//
//  ContentView.swift
//  Naviari
//
//  Created by Ari Peltoniemi on 4.2.2026.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = RaceBrowserViewModel()
    @State private var navigationPath: [AppRoute] = []

    var body: some View {
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
        .environmentObject(viewModel)
    }
}

private enum AppRoute: Hashable {
    case races
    case raceDetail(RaceSummary)
    case startDetail(RaceSummary, RaceStart)
    case participate(RaceSummary, RaceStart)
}
#Preview {
    ContentView()
}
