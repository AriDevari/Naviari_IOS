import Foundation

final class BuoyStorage {
    static let shared = BuoyStorage()

    private let userDefaults: UserDefaults
    private let storageKey = "local_buoys_by_race"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func loadBuoys(for raceId: String) -> [BuoyRecord] {
        sorted(loadAllBuoys()[raceId] ?? [])
    }

    func loadBuoy(id: String, raceId: String) -> BuoyRecord? {
        loadBuoys(for: raceId).first(where: { $0.id == id })
    }

    @discardableResult
    func createBuoy(
        raceId: String,
        name: String,
        description: String?,
        coordinate: CoordinatePoint?,
        now: Date = Date(),
        id: String = UUID().uuidString
    ) -> BuoyRecord {
        let buoy = BuoyRecord(
            id: id,
            raceId: raceId,
            name: name,
            description: description,
            coordinate: coordinate,
            lastUpdated: now
        )
        save(buoy)
        return buoy
    }

    @discardableResult
    func updateBuoy(
        id: String,
        raceId: String,
        name: String,
        description: String?,
        coordinate: CoordinatePoint?,
        lastUpdated: Date = Date()
    ) -> BuoyRecord? {
        guard loadBuoy(id: id, raceId: raceId) != nil else {
            return nil
        }

        let updated = BuoyRecord(
            id: id,
            raceId: raceId,
            name: name,
            description: description,
            coordinate: coordinate,
            lastUpdated: lastUpdated
        )
        save(updated)
        return updated
    }

    func deleteBuoy(id: String, raceId: String) {
        var allBuoys = loadAllBuoys()
        let remaining = (allBuoys[raceId] ?? []).filter { $0.id != id }
        if remaining.isEmpty {
            allBuoys.removeValue(forKey: raceId)
        } else {
            allBuoys[raceId] = remaining
        }
        persist(allBuoys)
    }

    func save(_ buoy: BuoyRecord) {
        var allBuoys = loadAllBuoys()
        var raceBuoys = allBuoys[buoy.raceId] ?? []

        if let index = raceBuoys.firstIndex(where: { $0.id == buoy.id }) {
            raceBuoys[index] = buoy
        } else {
            raceBuoys.append(buoy)
        }

        allBuoys[buoy.raceId] = raceBuoys
        persist(allBuoys)
    }

    private func loadAllBuoys() -> [String: [BuoyRecord]] {
        guard let data = userDefaults.data(forKey: storageKey) else {
            return [:]
        }

        return (try? JSONDecoder().decode([String: [BuoyRecord]].self, from: data)) ?? [:]
    }

    private func persist(_ buoysByRace: [String: [BuoyRecord]]) {
        if let data = try? JSONEncoder().encode(buoysByRace) {
            userDefaults.set(data, forKey: storageKey)
        }
    }

    private func sorted(_ buoys: [BuoyRecord]) -> [BuoyRecord] {
        buoys.sorted { lhs, rhs in
            if lhs.lastUpdated != rhs.lastUpdated {
                return lhs.lastUpdated > rhs.lastUpdated
            }

            let nameOrder = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
            if nameOrder != .orderedSame {
                return nameOrder == .orderedAscending
            }

            return lhs.id < rhs.id
        }
    }
}