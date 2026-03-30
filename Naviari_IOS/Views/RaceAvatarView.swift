import SwiftUI
import UIKit

struct RaceAvatarView: View {
    let summary: RaceSummary
    let size: CGFloat

    @State private var image: UIImage?

    init(summary: RaceSummary, size: CGFloat = 56) {
        self.summary = summary
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
                    .fill(Theme.Colors.brandPrimaryMuted)
                Text(initials)
                    .font(AppFont.textStyle(.headline))
                    .foregroundStyle(Theme.Colors.brandPrimary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Theme.Colors.surfacePrimary.opacity(Theme.Effects.avatarBorderOpacity), lineWidth: Theme.Effects.avatarBorderLineWidth)
        )
        .task(id: summary.preferredImageId) {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let imageId = summary.preferredImageId else {
            await MainActor.run { image = nil }
            return
        }
        let fetched = await ImageRepository.shared.image(for: imageId)
        await MainActor.run {
            image = fetched
        }
    }

    private var initials: String {
        let source = (summary.seriesName ?? summary.race.nameOrFallback).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = source.first else { return "#" }
        return String(first).uppercased()
    }
}
