import Foundation
import XCTest
@testable import Naviari_IOS

final class ManageAccessStorageTests: XCTestCase {
    func testManageAccessStorage_upgradeToSchemaVersion2_clearsLegacyOpaqueRecordsOnce() throws {
        let (storage, defaults, suiteName) = makeStorage()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let legacyPayload = try JSONEncoder().encode([
            "start::start-1": ManageAccessTokenRecord(
                scope: .start,
                scopeId: "start-1",
                token: "legacy-token",
                savedAt: Date(timeIntervalSince1970: 1)
            ),
        ])
        defaults.set(legacyPayload, forKey: "manage_access_tokens")
        defaults.set(Data("stale-v2".utf8), forKey: "manage_access_tokens_v2")
        defaults.set(1, forKey: "manage_access_tokens_schema_version")

        XCTAssertNil(storage.loadToken(for: "start-1", raceId: nil, seriesId: nil))
        XCTAssertNil(defaults.data(forKey: "manage_access_tokens"))
        XCTAssertNil(defaults.data(forKey: "manage_access_tokens_v2"))
        XCTAssertEqual(defaults.integer(forKey: "manage_access_tokens_schema_version"), 2)

        storage.save(loginResult: makeLoginResult(scope: .race, scopeId: "race-1", token: "new-token"))

        XCTAssertNil(defaults.data(forKey: "manage_access_tokens"))
        XCTAssertEqual(defaults.integer(forKey: "manage_access_tokens_schema_version"), 2)
        XCTAssertEqual(storage.loadToken(for: nil, raceId: "race-1", seriesId: nil)?.token, "new-token")
    }

    func testManageAccessStorage_saveRecord_persistsOnlyServerDeclaredScope() throws {
        let (storage, defaults, suiteName) = makeStorage()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        storage.save(loginResult: makeLoginResult(scope: .race, scopeId: "race-1", token: "race-token"))

        let payload = try XCTUnwrap(defaults.data(forKey: "manage_access_tokens_v2"))
        let records = try JSONDecoder().decode([String: ManageAccessTokenRecord].self, from: payload)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records["race::race-1"]?.scope, .race)
        XCTAssertEqual(records["race::race-1"]?.scopeId, "race-1")
        XCTAssertEqual(records["race::race-1"]?.token, "race-token")
        XCTAssertNil(storage.loadToken(for: "start-1", raceId: nil, seriesId: "series-1"))
        XCTAssertEqual(storage.loadToken(for: "start-1", raceId: "race-1", seriesId: "series-1")?.scope, .race)
    }

    func testManageAccessStorage_loadToken_prefersStartThenRaceThenSeriesWithinSchemaV2() {
        let (storage, defaults, suiteName) = makeStorage()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        storage.save(loginResult: makeLoginResult(scope: .series, scopeId: "series-1", token: "series-token"))
        storage.save(loginResult: makeLoginResult(scope: .race, scopeId: "race-1", token: "race-token"))
        storage.save(loginResult: makeLoginResult(scope: .start, scopeId: "start-1", token: "start-token"))

        XCTAssertEqual(
            storage.loadToken(for: "start-1", raceId: "race-1", seriesId: "series-1")?.token,
            "start-token"
        )
        XCTAssertEqual(
            storage.loadToken(for: "missing-start", raceId: "race-1", seriesId: "series-1")?.token,
            "race-token"
        )
        XCTAssertEqual(
            storage.loadToken(for: "missing-start", raceId: "missing-race", seriesId: "series-1")?.token,
            "series-token"
        )
        XCTAssertEqual(defaults.integer(forKey: "manage_access_tokens_schema_version"), 2)
    }

    private func makeStorage() -> (ManageAccessStorage, UserDefaults, String) {
        let suiteName = "ManageAccessStorageTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (ManageAccessStorage(userDefaults: defaults), defaults, suiteName)
    }

    private func makeLoginResult(
        scope: ManageAccessScope,
        scopeId: String,
        token: String
    ) -> ManageAccessLoginResult {
        ManageAccessLoginResult(token: token, scope: scope, scopeId: scopeId, role: "manage")
    }
}
