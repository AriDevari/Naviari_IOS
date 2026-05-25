import Foundation

@MainActor
final class BuoySectionViewModel: ObservableObject {
    @Published private(set) var buoys: [BuoyRecord] = []
    @Published var activeBuoyId: String?
    @Published var editorMode: BuoyEditorMode?

    let raceId: String

    private let storage: BuoyStorage

    init(raceId: String, storage: BuoyStorage = .shared) {
        self.raceId = raceId
        self.storage = storage
        reload()
    }

    func reload() {
        buoys = storage.loadBuoys(for: raceId)
        pruneActiveBuoyIfNeeded()
    }

    func presentAdd() {
        editorMode = .add(raceId: raceId)
    }

    func presentEdit(_ buoy: BuoyRecord, focusPosition: Bool = false) {
        editorMode = .edit(buoy, focusPosition: focusPosition)
    }

    func delete(_ buoy: BuoyRecord) {
        storage.deleteBuoy(id: buoy.id, raceId: raceId)
        reload()
    }

    func handleEditorOutcome(_ outcome: BuoyEditorOutcome) {
        switch outcome {
        case let .saved(buoy):
            activeBuoyId = buoy.id
            reload()
        case .removed:
            reload()
        }
    }

    private func pruneActiveBuoyIfNeeded() {
        guard let activeBuoyId else { return }
        guard buoys.contains(where: { $0.id == activeBuoyId }) else {
            self.activeBuoyId = nil
            return
        }
    }
}
