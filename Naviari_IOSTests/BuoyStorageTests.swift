import XCTest
@testable import Naviari_IOS

final class BuoyStorageTests: XCTestCase {

    func testBuoyStorage_createPersistsRaceScopedRecord() {
        let (storage, defaults, suiteName) = makeStorage()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let created = storage.createBuoy(
            raceId: "race-a",
            name: "Yellow One",
            description: "Near the harbor",
            coordinate: CoordinatePoint(lat: 60.12345, lon: 24.98765),
            now: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let loaded = storage.loadBuoys(for: "race-a")
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.id, created.id)
        XCTAssertEqual(loaded.first?.name, "Yellow One")
        XCTAssertEqual(loaded.first?.description, "Near the harbor")
        XCTAssertEqual(loaded.first?.coordinate, CoordinatePoint(lat: 60.12345, lon: 24.98765))
    }

    func testBuoyStorage_raceScopesDoNotLeakIntoEachOther() {
        let (storage, defaults, suiteName) = makeStorage()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        storage.createBuoy(raceId: "race-a", name: "Race A", description: nil, coordinate: nil)
        storage.createBuoy(raceId: "race-b", name: "Race B", description: nil, coordinate: nil)

        XCTAssertEqual(storage.loadBuoys(for: "race-a").map(\ .name), ["Race A"])
        XCTAssertEqual(storage.loadBuoys(for: "race-b").map(\ .name), ["Race B"])
    }

    func testBuoyStorage_updateChangesLastUpdated() {
        let (storage, defaults, suiteName) = makeStorage()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let original = storage.createBuoy(
            raceId: "race-a",
            name: "Alpha",
            description: nil,
            coordinate: nil,
            now: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let updated = storage.updateBuoy(
            id: original.id,
            raceId: "race-a",
            name: "Alpha updated",
            description: "Moved",
            coordinate: CoordinatePoint(lat: 60.5, lon: 24.5),
            lastUpdated: Date(timeIntervalSince1970: 1_700_000_100)
        )

        XCTAssertNotNil(updated)
        XCTAssertEqual(updated?.name, "Alpha updated")
        XCTAssertEqual(updated?.description, "Moved")
        XCTAssertEqual(updated?.coordinate, CoordinatePoint(lat: 60.5, lon: 24.5))
        XCTAssertEqual(updated?.lastUpdated, Date(timeIntervalSince1970: 1_700_000_100))
    }

    func testBuoyStorage_deleteRemovesOnlyTargetRecord() {
        let (storage, defaults, suiteName) = makeStorage()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let first = storage.createBuoy(raceId: "race-a", name: "First", description: nil, coordinate: nil)
        _ = storage.createBuoy(raceId: "race-a", name: "Second", description: nil, coordinate: nil)

        storage.deleteBuoy(id: first.id, raceId: "race-a")

        let loaded = storage.loadBuoys(for: "race-a")
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.name, "Second")
    }

    func testBuoyStorage_loadPreservesCreationOrder() {
        let (storage, defaults, suiteName) = makeStorage()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        _ = storage.createBuoy(
            raceId: "race-a",
            name: "Bravo",
            description: nil,
            coordinate: nil,
            now: Date(timeIntervalSince1970: 10)
        )
        _ = storage.createBuoy(
            raceId: "race-a",
            name: "Alpha",
            description: nil,
            coordinate: nil,
            now: Date(timeIntervalSince1970: 10)
        )
        _ = storage.createBuoy(
            raceId: "race-a",
            name: "Zulu",
            description: nil,
            coordinate: nil,
            now: Date(timeIntervalSince1970: 20)
        )

        XCTAssertEqual(storage.loadBuoys(for: "race-a").map(\ .name), ["Bravo", "Alpha", "Zulu"])
    }

    func testBuoyStorage_updatePreservesExistingListPosition() {
        let (storage, defaults, suiteName) = makeStorage()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let first = storage.createBuoy(
            raceId: "race-a",
            name: "First",
            description: nil,
            coordinate: nil,
            now: Date(timeIntervalSince1970: 10)
        )
        let second = storage.createBuoy(
            raceId: "race-a",
            name: "Second",
            description: nil,
            coordinate: nil,
            now: Date(timeIntervalSince1970: 20)
        )

        _ = storage.updateBuoy(
            id: second.id,
            raceId: "race-a",
            name: "Second updated",
            description: nil,
            coordinate: CoordinatePoint(lat: 60.1, lon: 24.9),
            lastUpdated: Date(timeIntervalSince1970: 30)
        )

        let loaded = storage.loadBuoys(for: "race-a")
        XCTAssertEqual(loaded.map(\ .id), [first.id, second.id])
        XCTAssertEqual(loaded.map(\ .name), ["First", "Second updated"])
    }

    func testBuoyRecord_coordinateSummaryWithoutCoordinatesUsesFallback() {
        let buoy = BuoyRecord(
            id: "buoy-1",
            raceId: "race-a",
            name: "No Coordinates",
            description: nil,
            coordinate: nil,
            lastUpdated: Date(timeIntervalSince1970: 1)
        )

        XCTAssertEqual(buoy.coordinateSummary(missingText: "Missing"), "Missing")
    }

    func testBuoyRecord_coordinateSummaryWithCoordinatesFormatsLatLon() {
        let buoy = BuoyRecord(
            id: "buoy-1",
            raceId: "race-a",
            name: "Has Coordinates",
            description: nil,
            coordinate: CoordinatePoint(lat: 60.175139, lon: 24.945),
            lastUpdated: Date(timeIntervalSince1970: 1)
        )

        XCTAssertEqual(buoy.coordinateSummary(missingText: "Missing"), "60.17514, 24.94500")
    }

    private func makeStorage() -> (BuoyStorage, UserDefaults, String) {
        let suiteName = "BuoyStorageTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let storage = BuoyStorage(userDefaults: defaults)
        return (storage, defaults, suiteName)
    }
}