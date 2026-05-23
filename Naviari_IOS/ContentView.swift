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
    @StateObject private var userNotifications = UserNotifications()
    @State private var navigationPath: [AppRoute] = []
    @EnvironmentObject private var locationManager: LocationDataManager
    @EnvironmentObject private var metricsUploader: BoatMetricsUploader

    var body: some View {
        let uiTestScenario = CourseEditUITestScenario.current
        let raceCourseSectionScenario = RaceCourseSectionUITestScenario.current
        let raceDetailScreenScenario = RaceDetailScreenUITestScenario.current
        let isUITestActive = uiTestScenario != nil
            || raceCourseSectionScenario != nil
            || raceDetailScreenScenario != nil

        ZStack {
            Group {
                if let raceDetailScreenScenario {
                    RaceDetailScreenUITestHarnessView(scenario: raceDetailScreenScenario)
                } else if let raceCourseSectionScenario {
                    RaceCourseSectionUITestHarnessView(scenario: raceCourseSectionScenario)
                } else if let uiTestScenario {
                    CourseEditUITestHarnessView(scenario: uiTestScenario)
                } else {
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
                                StartDetailScreen(
                                    raceSummary: summary,
                                    start: start,
                                    onParticipate: {
                                        let latest = latestStart(for: start, in: summary)
                                        navigationPath.append(.participate(summary, latest))
                                    },
                                    onSetStartTime: {
                                        let latest = latestStart(for: start, in: summary)
                                        navigationPath.append(.setStartTime(summary, latest))
                                    },
                                    onSetPositionTarget: { target in
                                        let latest = latestStart(for: start, in: summary)
                                        navigationPath.append(.setPosition(summary, latest, target))
                                    }
                                )
                            case let .participate(summary, start):
                                ParticipateView(raceSummary: summary, start: start)
                            case let .setStartTime(summary, start):
                                SetStartTimeScreen(raceSummary: summary, start: start)
                            case let .setPosition(summary, start, target):
                                SetPositionScreen(
                                    raceSummary: summary,
                                    start: start,
                                    target: target
                                )
                            }
                        }
                    }
                }
            }

            if !isUITestActive {
                UserNotificationsOverlay()
            }

            if !isUITestActive, metricsUploader.isBroadcasting {
                BroadcastStatusButton(uploader: metricsUploader)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(.leading, Theme.Spacing.floatingInset)
                    .padding(.bottom, Theme.Spacing.floatingInset)
            }

            if !isUITestActive {
                GPSStatusButton(locationManager: locationManager)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, Theme.Spacing.floatingInset)
                    .padding(.bottom, Theme.Spacing.floatingInset)
            }
        }
        .environmentObject(viewModel)
        .environmentObject(userNotifications)
    }

    private func latestStart(for routeStart: RaceStart, in summary: RaceSummary) -> RaceStart {
        let routeId = routeStart.rawId ?? routeStart.slug
        guard let routeId else { return routeStart }
        let starts = viewModel.starts(for: summary)
        if let updated = starts.first(where: { ($0.rawId ?? $0.slug) == routeId }) {
            return updated
        }
        return routeStart
    }
}

/// Typed routes for the root NavigationStack.
private enum AppRoute: Hashable {
    case races
    case raceDetail(RaceSummary)
    case startDetail(RaceSummary, RaceStart)
    case participate(RaceSummary, RaceStart)
    case setStartTime(RaceSummary, RaceStart)
    case setPosition(RaceSummary, RaceStart, SetPositionTarget)
}
#Preview {
    ContentView()
        .environmentObject(LocationDataManager())
        .environmentObject(BoatMetricsUploader())
}
