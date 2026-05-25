import Foundation
import SwiftUI

enum BuoySectionUITestScenario: Equatable {
    case empty
    case list

    static var current: BuoySectionUITestScenario? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let raw = value(for: "-UITestBuoySectionState", in: arguments) else {
            return nil
        }

        switch raw {
        case "empty":
            return .empty
        case "list":
            return .list
        default:
            return nil
        }
    }

    private static func value(for flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag),
              arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }
}

struct BuoySectionUITestHarnessView: View {
    let scenario: BuoySectionUITestScenario

    @State private var activeBuoyId: String?

    var body: some View {
        ScrollView {
            BuoySectionView(
                titleKey: "buoy_section_title",
                buoys: buoys,
                activeBuoyId: $activeBuoyId,
                sectionAccessibilityIdentifier: "buoy_section",
                addButtonAccessibilityIdentifier: "buoy_add_button",
                onAddTapped: {},
                onEditBuoy: { _ in },
                onSetCoordinates: { _ in }
            )
            .padding(.vertical, 24)
        }
        .accessibilityIdentifier("buoy_section_uitest_host")
    }

    private var buoys: [BuoyRecord] {
        switch scenario {
        case .empty:
            return []
        case .list:
            return BuoySectionUITestFixtures.buoys
        }
    }
}

enum BuoySectionUITestFixtures {
    static let buoys: [BuoyRecord] = [
        BuoyRecord(
            id: "buoy-alpha",
            raceId: "race-fixture",
            name: "Alpha Buoy",
            description: "Near the windward area",
            coordinate: CoordinatePoint(lat: 60.17514, lon: 24.94500),
            lastUpdated: Date(timeIntervalSince1970: 1_700_000_000)
        ),
        BuoyRecord(
            id: "buoy-beta",
            raceId: "race-fixture",
            name: "Beta Buoy",
            description: "Leeward gate side",
            coordinate: nil,
            lastUpdated: Date(timeIntervalSince1970: 1_700_000_100)
        )
    ]
}
