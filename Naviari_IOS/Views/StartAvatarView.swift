import SwiftUI
import UIKit

struct StartAvatarView: View {
    let start: RaceStart
    let size: CGFloat

    @State private var image: UIImage?

    init(start: RaceStart, size: CGFloat = 48) {
        self.start = start
        self.size = size
    }

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                Image(systemName: "sailboat.fill")
                    .font(.system(size: size * 0.45))
                    .foregroundStyle(.blue)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color(.systemBackground).opacity(0.4), lineWidth: 1)
        )
        .task(id: start.imageId) {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let imageId = normalizedIdentifier(start.imageId) else {
            await MainActor.run { image = nil }
            return
        }
        let loaded = await ImageRepository.shared.image(for: imageId)
        await MainActor.run {
            image = loaded
        }
    }
}

private func normalizedIdentifier(_ value: String?) -> String? {
    guard let value else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}
