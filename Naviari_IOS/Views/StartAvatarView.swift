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
                    .fill(iconBackgroundColor)
                StartIconGlyphView(icon: resolvedIcon)
                    .frame(width: size * 0.72, height: size * 0.72)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Theme.Colors.surfacePrimary.opacity(Theme.Effects.avatarBorderOpacity), lineWidth: Theme.Effects.avatarBorderLineWidth)
        )
        .task(id: start.imageId) {
            await loadImage()
        }
    }

    private var resolvedIcon: StartVisualIcon {
        normalizedStartVisualIcon(start.iconKey)
    }

    private var iconBackgroundColor: Color {
        Color(hex: start.iconColor) ?? Theme.Colors.brandPrimary
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

private let characterIconPrefix = "character:"
private let characterIconAllowedCharacters: Set<Character> = Set(
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~€$"
)

private enum StartIconKey: String {
    case defaultSailboat = "default"
    case kite
    case laser
    case sailboat1 = "sailboat-1"
    case sailboat2 = "sailboat-2"
    case sportBoat = "sport-boat"
    case submarine
    case sub
    case foil
    case windsurfing
}

private enum StartVisualIcon {
    case preset(StartIconKey)
    case character(String)
    case defaultSailboat
}

private func normalizedStartVisualIcon(_ value: String?) -> StartVisualIcon {
    guard let value else { return .defaultSailboat }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return .defaultSailboat }

    let lowered = trimmed.lowercased()
    if let semanticKey = StartIconKey(rawValue: lowered) {
        if semanticKey == .defaultSailboat {
            return .defaultSailboat
        }
        return .preset(semanticKey)
    }

    guard lowered.hasPrefix(characterIconPrefix) else {
        return .defaultSailboat
    }

    let glyph = String(trimmed.dropFirst(characterIconPrefix.count))
    let glyphChars = Array(glyph)
    guard glyphChars.count == 1 else {
        return .defaultSailboat
    }
    guard characterIconAllowedCharacters.contains(glyphChars[0]) else {
        return .defaultSailboat
    }
    return .character(String(glyphChars[0]))
}

private struct StartIconGlyphView: View {
    let icon: StartVisualIcon

    var body: some View {
        switch icon {
        case .character(let glyph):
            GeometryReader { proxy in
                Text(glyph)
                    .font(AppFont.fixed(min(proxy.size.width, proxy.size.height) * 0.86, weight: .semibold))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.2)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .accessibilityHidden(true)
        case .defaultSailboat:
            Image(systemName: "sailboat.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.white)
                .accessibilityHidden(true)
        case .preset(let iconKey):
            let assetName = startIconAssetName(for: iconKey)
            if UIImage(named: assetName) != nil {
                Image(assetName)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)
            } else {
                Canvas { context, size in
                    let asset = StartIconAssetLibrary.asset(for: iconKey)
                    let scale = min(size.width / asset.viewBox.width, size.height / asset.viewBox.height)
                    let offsetX = (size.width - asset.viewBox.width * scale) * 0.5 - asset.viewBox.minX * scale
                    let offsetY = (size.height - asset.viewBox.height * scale) * 0.5 - asset.viewBox.minY * scale

                    for item in asset.paths {
                        var transform = CGAffineTransform(scaleX: scale, y: scale)
                            .translatedBy(x: offsetX / scale, y: offsetY / scale)
                        guard let transformed = item.cgPath.copy(using: &transform) else {
                            continue
                        }
                        let path = Path(transformed)
                        if item.fill {
                            context.fill(path, with: .color(.white))
                        }
                        if let strokeWidth = item.strokeWidth {
                            context.stroke(
                                path,
                                with: .color(.white),
                                style: StrokeStyle(
                                    lineWidth: max(CGFloat(0.8), strokeWidth * scale),
                                    lineCap: .round,
                                    lineJoin: .round
                                )
                            )
                        }
                    }
                }
                .accessibilityHidden(true)
            }
        }
    }
}

private func startIconAssetName(for iconKey: StartIconKey) -> String {
    switch iconKey {
    case .defaultSailboat:
        return "StartIconSailboat1"
    case .sailboat1:
        return "StartIconSailboat1"
    case .kite:
        return "StartIconKite"
    case .laser:
        return "StartIconLaser"
    case .sailboat2:
        return "StartIconSailboat2"
    case .sportBoat:
        return "StartIconSportBoat"
    case .submarine:
        return "StartIconSubmarine"
    case .sub:
        return "StartIconSUB"
    case .foil:
        return "StartIconFoil"
    case .windsurfing:
        return "StartIconWindsurfing"
    }
}

private struct StartIconRenderablePath {
    let cgPath: CGPath
    let fill: Bool
    let strokeWidth: CGFloat?

    static func filled(_ d: String) -> StartIconRenderablePath {
        var parser = SVGPathParser(pathData: d)
        return StartIconRenderablePath(cgPath: parser.parse() ?? CGMutablePath(), fill: true, strokeWidth: nil)
    }

    static func stroked(_ d: String, strokeWidth: CGFloat) -> StartIconRenderablePath {
        var parser = SVGPathParser(pathData: d)
        return StartIconRenderablePath(cgPath: parser.parse() ?? CGMutablePath(), fill: false, strokeWidth: strokeWidth)
    }
}

private struct StartIconAsset {
    let viewBox: CGRect
    let paths: [StartIconRenderablePath]
}

private enum StartIconAssetLibrary {
    static func asset(for key: StartIconKey) -> StartIconAsset {
        switch key {
        case .defaultSailboat:
            return sailboat1
        case .kite:
            return kite
        case .laser:
            return laser
        case .sailboat1:
            return sailboat1
        case .sailboat2:
            return sailboat2
        case .sportBoat:
            return sportBoat
        case .submarine:
            return submarine
        case .sub:
            return sailboat1
        case .foil:
            return sailboat1
        case .windsurfing:
            return windsurfing
        }
    }

    private static let kite = StartIconAsset(
        viewBox: CGRect(x: 0, y: 0, width: 837.33331, height: 960),
        paths: [
            .filled("m 144.93636,713.63903 c 0,0 81.44043,-57.97454 168.40225,-100.76528 86.96181,-42.79073 149.0774,-78.67974 242.94095,-103.52597 93.86354,-24.84623 146.3167,-38.64969 171.16294,-30.36762 24.84623,8.28208 51.07281,16.56416 42.79073,59.35489 -8.28208,42.79074 -16.56416,62.11559 -62.11558,92.48321 -45.55143,30.36761 -198.76987,96.62424 -198.76987,96.62424 l -223.6161,30.36761 z"),
            .filled("m 221.21645,298.11467 a 79.369911,70.397659 0 0 1 -112.23588,0.26094 79.369911,70.397659 0 0 1 -0.31368,-99.5483 79.369911,70.397659 0 0 1 112.23577,-0.2955 79.369911,70.397659 0 0 1 0.35265,99.54819 l -56.30392,-49.61767 z"),
            .stroked("M 343.70623,52.453159 282.97099,149.0774 519.01021,306.43688 632.1986,149.0774 v 0", strokeWidth: 15),
            .filled("m 215.33402,644.62172 c 0,0 -37.26935,-4.14104 -75.91904,-67.63697 -38.6497,-63.49593 -60.735241,-74.5387 -48.312125,-164.26121 12.423115,-89.72251 -4.141039,-86.96182 19.324845,-96.62424 23.46589,-9.66242 74.5387,-23.46589 100.76528,-15.18381 26.22658,8.28208 40.03004,23.46589 38.6497,57.97455 -1.38035,34.50865 -12.42312,91.10285 -12.42312,91.10285 0,0 27.60693,-9.66242 45.55143,-9.66242 17.9445,0 33.12831,-2.7607 46.93177,0 13.80347,2.76069 71.77801,35.889 71.77801,35.889 0,0 -28.98727,-19.32485 0,0 28.98727,19.32485 46.93177,42.79074 46.93177,42.79074 l -63.49592,35.889 -16.56416,-17.9445 c 0,0 -6.90173,-5.52139 -19.32485,-13.80347 -12.42311,-8.28207 -12.42311,-19.32484 -41.41039,-19.32484 -28.98727,0 -69.01731,11.04277 -77.29939,15.18381 -8.28208,4.14103 -13.80346,15.1838 -12.42312,24.84623 1.38035,9.66242 9.66243,13.80346 24.84624,24.84623 15.18381,11.04277 41.41039,35.88901 41.41039,35.88901 z"),
            .filled("m 245.70164,266.40683 84.20112,1.38035 30.36762,-57.97454 c 0,0 16.56416,-17.94451 12.42312,-33.12831 -4.14104,-15.18381 0,-22.08555 -22.08554,-23.46589 -22.08554,-1.38035 -46.93178,6.90173 -55.21385,22.08554 -8.28208,15.18381 -49.69247,91.10285 -49.69247,91.10285 z"),
            .filled("m 231.89818,360.27038 c 0,0 28.98727,11.04277 103.52597,-9.66242 74.5387,-20.7052 93.86355,-12.42312 120.09013,-52.45316 26.22658,-40.03004 33.12831,-42.79074 26.22658,-59.35489 -6.90174,-16.56416 -15.18381,-12.42312 -27.60693,-12.42312 -12.42312,0 -45.55143,38.6497 -84.20112,51.07281 -38.6497,12.42312 -133.89359,30.36762 -151.8381,30.36762 -17.9445,0 13.80347,52.45316 13.80347,52.45316 z"),
            .stroked("m 69.017315,720.54076 c 0,0 51.072815,51.07282 144.936365,70.39766 93.86354,19.32485 109.04735,12.42312 179.44501,-1.38034 70.39766,-13.80346 133.89359,-42.79074 179.44502,-70.39766 45.55143,-27.60693 73.15835,-34.50866 73.15835,-34.50866 0,0 5.52139,24.84623 33.12832,48.31212 27.60692,23.46589 27.60692,23.46589 27.60692,23.46589", strokeWidth: 20),
            .stroked("m 392.01835,219.47506 85.58147,-111.80805 v 0", strokeWidth: 15),
        ]
    )

    private static let laser = StartIconAsset(
        viewBox: CGRect(x: 0, y: 0, width: 664, height: 998.66669),
        paths: [
            .filled("m 195.68236,730.31452 c 0,0 -15.72448,-85.61103 -10.48298,-181.70505 5.24149,-96.09402 15.72447,-200.92385 29.70178,-269.06324 13.97731,-68.1394 55.90925,-235.867132 55.90925,-235.867132 0,0 61.15073,101.335512 101.3355,183.452212 40.18477,82.1167 69.88656,176.46356 106.577,265.56892 36.69045,89.10535 78.62238,234.11996 78.62238,234.11996 0,0 -47.17343,31.44895 -157.24475,26.20746 -110.07133,-5.24149 -204.41818,-22.71313 -204.41818,-22.71313 z"),
            .filled("m 365.59518,907.64484 c 0,0 -36.85045,2.90924 -43.63868,-3.87899 -6.78824,-6.78824 -24.24372,-75.64039 -24.24372,-75.64039 0,0 -93.09585,-0.96974 -117.33956,-3.87899 -24.24371,-2.90925 -87.277366,-1.9395 -87.277366,-1.9395 l -5.818491,-7.75798 -50.426921,-47.51768 c 0,0 120.248808,7.75799 178.433718,7.75799 58.18491,0 89.21686,3.87899 89.21686,3.87899 l 7.75799,4.84874 c 0,0 28.12271,1.9395 78.54963,1.9395 50.42692,0 218.19341,0 218.19341,0 l 28.1227,99.88409 c 0,0 -22.30421,-0.96974 -29.09245,-4.84874 -6.78824,-3.87899 -18.42522,-61.09415 -18.42522,-61.09415 0,0 -27.15296,-1.9395 -85.33787,3.87899 -58.18491,5.81849 -160.97825,6.78824 -160.97825,6.78824 z"),
            .filled("m 196.85894,740.88784 c -0.96975,72.73113 -2.90924,76.61013 -2.90924,76.61013 h 11.63698 l 9.69748,-92.12611 -19.39497,-6.78824 z"),
        ]
    )

    private static let sailboat1 = StartIconAsset(
        viewBox: CGRect(x: 0, y: 0, width: 64, height: 64),
        paths: [
            .filled("M58.92267,48.1701,5.99973,52.03958A2.11814,2.11814,0,0,0,4,54.15929v2.80962a2.1274,2.1274,0,0,0,2.14974,2.11971l38.23489-.99986.68985-.00006c7.99618.02386,12.40746-.32955,14.85806-8.56881A1.01,1.01,0,0,0,58.92267,48.1701Z"),
            .filled("M27.23689,27.80282a80.0625,80.0625,0,0,1-2.00974,18.69752A1.00233,1.00233,0,0,0,26.697,47.59016a37.801,37.801,0,0,1,14.0381-4.72935,29.62858,29.62858,0,0,1,8.3989.01,25.72568,25.72568,0,0,1,4.47939,1.18984,1.00177,1.00177,0,0,0,1.31983-1.13986C51.06782,25.14979,39.217,12.96062,25.4474,5.03565a1.01357,1.01357,0,0,0-1.45,1.16013A79.96,79.96,0,0,1,27.23689,27.80282Zm5.30935-13.78808c5.37264,4.67815,7.7865,6.9204,12.23854,14.19781a.99852.99852,0,0,1-1.74.9801c-4.26036-6.95275-6.6016-9.14966-11.7582-13.61836A1.00269,1.00269,0,0,1,32.54624,14.01474Z"),
        ]
    )

    private static let sailboat2 = StartIconAsset(
        viewBox: CGRect(x: 0, y: 0, width: 377.504, height: 377.504),
        paths: [
            .filled("M239.194,1.501c-4.568-2.219-8.381,0.35-8.381,5.422v267.381 c53.071-23.036,92.958-75.994,92.958-137.747C323.764,77.121,289.168,25.789,239.194,1.501z"),
            .filled("M206.533,62.059L74.517,274.312h136.966l-0.089-210.863 C211.394,58.361,209.224,57.743,206.533,62.059z"),
            .filled("M2.067,316.402l15.038,35.067c5.991,13.997,23.199,25.337,38.424,25.337h266.447 c15.225,0,32.425-11.348,38.424-25.337l15.038-35.067c5.991-14.006-1.479-25.337-16.712-25.337H18.788 C3.547,291.065-3.924,302.405,2.067,316.402z"),
        ]
    )

    private static let sportBoat = StartIconAsset(
        viewBox: CGRect(x: 0, y: 0, width: 949.33331, height: 992),
        paths: [
            .filled("m 93.529301,916.0861 c 0,0 32.568239,2.50525 135.283459,0 102.71521,-2.50525 131.10803,-6.68066 244.67933,-8.35083 113.57129,-1.67016 226.3075,-10.85608 249.68983,-10.85608 23.38232,0 38.41382,-2.50525 38.41382,-2.50525 l 2.50525,66.80665 c 0,0 1.67017,6.68066 -1.67017,9.18591 -3.34033,2.50525 4.17542,3.34033 -24.21741,6.68067 -28.39282,3.34033 -197.07959,10.85608 -305.64039,10.02099 C 324.01222,986.23308 188.72877,980.3875 157.8307,976.21208 126.93262,972.03667 89.353886,960.34551 89.353886,960.34551 Z"),
            .filled("m 622.13687,906.06511 c 0,0 -11.69116,-11.69117 -37.57874,-17.53675 -25.88757,-5.84558 -45.09448,-10.02099 -75.99255,-12.52624 -30.89808,-2.50525 -64.3014,-2.50525 -64.3014,-2.50525 0,0 -4.17541,-2.50525 -6.68066,1.67016 -2.50525,4.17542 -7.51575,40.08399 -7.51575,40.08399 z"),
            .filled("m 500.7382,798.16916 -281.11618,11.29485 c 0,0 10.03986,-122.98833 20.07973,-197.03233 10.03986,-74.04399 16.31477,-139.3031 28.8646,-204.56222 12.54983,-65.25911 23.84468,-129.26324 42.66942,-181.97253 18.82475,-52.70928 45.17939,-100.39863 62.74915,-128.008259 17.56976,-27.609625 42.66942,-65.259114 42.66942,-65.259114 l 33.88454,-6.274915 z"),
            .filled("m 739.18496,875.97811 -249.74161,-715.34029 -12.54983,3.76495 43.92441,686.47568 c 0,0 7.5299,0 36.3945,8.78488 28.86461,8.78488 58.9842,25.09966 58.9842,25.09966 z"),
            .filled("m 897.31282,893.54787 -145.57803,8.78488 v 5.01993 l -11.29484,5.01993 154.3629,-8.78488 z"),
            .stroked("m 461.83373,20.079727 c 166.5304,8.910313 307.7962,131.990773 361.43509,286.136113 83.78422,240.77581 79.6999,376.20873 72.78901,572.27223 v 0", strokeWidth: 20),
            .stroked("M 500.7382,817.46401 C 224.64195,831.26882 224.64195,831.26882 224.64195,831.26882", strokeWidth: 20),
        ]
    )

    private static let submarine = StartIconAsset(
        viewBox: CGRect(x: 0, y: 0, width: 64, height: 64),
        paths: [
            .filled("M60.89833,42.16093a1.95341,1.95341,0,0,0-1.4716-.50911A6.25114,6.25114,0,0,1,56.78,41.26863V39.711a1.71791,1.71791,0,0,0-1.24769-1.63459l-1.151-.38685V33.95609A1.14346,1.14346,0,0,0,53.24,32.81479H51.73117a1.15293,1.15293,0,0,0-.98658.55132l-1.56688,2.61148-8.37609-2.76621a.48468.48468,0,0,0-.11607-.01937H37.929l-3.3369-8.27934a1.15568,1.15568,0,0,0-1.08327-.73509h-.54164v-4.749a.96721.96721,0,0,0-1.93442,0v4.749h-1.5379V17.49416a.96721.96721,0,0,0-1.93442,0v6.68342h-2.3116a.36544.36544,0,0,0-.35786.36755V33.192H15.35424A7.5293,7.5293,0,0,0,7.81967,40.717c0,.09717.00856.19251.01216.28885a6.27568,6.27568,0,0,1-3.26044.646,1.9501,1.9501,0,0,0-1.46972.50911A1.86,1.86,0,0,0,2.5,43.54v2.01188a1.91429,1.91429,0,0,0,1.80219,1.89758A12.18348,12.18348,0,0,0,10.44078,46.197a12.1998,12.1998,0,0,0,10.77442,0A12.22214,12.22214,0,0,0,32,46.197a12.219,12.219,0,0,0,10.7848,0,12.19672,12.19672,0,0,0,10.77442,0,12.08189,12.08189,0,0,0,5.38768,1.27608c.25219,0,.50344-.0085.75091-.02362A1.91429,1.91429,0,0,0,61.5,45.55185V43.54A1.86,1.86,0,0,0,60.89833,42.16093ZM54.0296,44.25782a.96887.96887,0,0,0-.94076,0,10.24675,10.24675,0,0,1-9.83365,0,.96889.96889,0,0,0-.94077,0,10.262,10.262,0,0,1-9.844,0,.96887.96887,0,0,0-.94076,0,10.26706,10.26706,0,0,1-9.844,0,.96889.96889,0,0,0-.94077,0,10.24675,10.24675,0,0,1-9.83365,0,.96887.96887,0,0,0-.94076,0,10.13869,10.13869,0,0,1-4.9173,1.2808,6.02778,6.02778,0,0,0-.61867.01323L4.424,43.58058a8.25694,8.25694,0,0,0,6.01674-1.99865A8.18906,8.18906,0,0,0,21.218,41.581a8.19535,8.19535,0,0,0,10.782.001,8.19535,8.19535,0,0,0,10.782-.001,8.18906,8.18906,0,0,0,10.77725.001,8.2183,8.2183,0,0,0,6.00635,2.00149l.01134,1.93537A10.23809,10.23809,0,0,1,54.0296,44.25782Z"),
        ]
    )

    private static let windsurfing = StartIconAsset(
        viewBox: CGRect(x: 0, y: 0, width: 50, height: 50),
        paths: [
            .filled("M48 49c-.996 0-1.97-.227-2.83-.609-.883-.406-1.878-.643-2.92-.643-1.031 0-2.027.236-2.91.643-.869.382-1.833.609-2.84.609-1.006 0-1.97-.227-2.831-.609-.883-.406-1.879-.643-2.921-.643-1.03 0-2.026.236-2.915.643-.859.382-1.826.609-2.834.609-1.002 0-1.971-.227-2.829-.609-.889-.406-1.879-.643-2.92-.643-1.037 0-2.027.236-2.915.643-.865.382-1.828.609-2.835.609-1.009 0-1.971-.227-2.834-.609-.881-.406-1.879-.643-2.916-.643-1.042 0-2.034.236-2.915.643-.864.382-1.827.609-2.835.609v-4.18c1.008 0 1.971-.227 2.834-.609.881-.396 1.874-.633 2.915-.633 1.037 0 2.034.236 2.916.633.864.383 1.826.609 2.834.609s1.97-.227 2.834-.609c.888-.396 1.878-.633 2.915-.633 1.042 0 2.032.236 2.92.633.858.383 1.827.609 2.829.609 1.008 0 1.975-.227 2.834-.609.889-.396 1.885-.633 2.915-.633 1.042 0 2.038.236 2.921.633.861.383 1.825.609 2.831.609 1.007 0 1.971-.227 2.84-.609.883-.396 1.879-.633 2.91-.633 1.042 0 2.037.236 2.92.633.86.383 1.834.609 2.83.609v4.18zm-41.063-24.187c1.54 0 2.789-1.228 2.789-2.739 0-1.509-1.249-2.738-2.789-2.738-1.536 0-2.784 1.229-2.784 2.738 0 1.512 1.248 2.739 2.784 2.739zm12.249 12.187h-7.972c-1.173 0-2.192-.563-2.651-1.558l-2.949-6.554c-.057-.225-.086-.419-.086-.657 0-1.588 1.306-2.858 2.916-2.858l6.476-.004 4.444-1.98c.069-.044.251-.087.447-.087.761 0 1.386.621 1.386 1.365 0 .463-.241.88-.596 1.128l-4.833 2.032c-.321.247-.928.173-.928.173h-2.91l2.44 6h5.389c.532 0 .905-.045 1.23.236l5.282 4.826c.738.674.778 1.756.091 2.488-.692.721-1.85.615-2.589-.061l-4.587-4.489zm24.841-8.715c.102.17.352.236.584.236.443 0 .812-.361.812-.811 0-.215-.105-.406-.207-.588-4.982-9.353-18.432-6.57-20.081-5.961-.274.102-.435.406-.435.711 0 .438.366.8.812.8.138 0 .206-.012.326-.045 13.193-2.919 17.489 4.475 18.189 5.658zm2.291.846l-16.87 10.469-15.359-38.6c13.744 1.792 31.219 12.296 32.229 28.131z"),
        ]
    )
}

private enum SVGPathToken {
    case command(Character)
    case number(CGFloat)
}

private struct SVGPathTokenizer {
    private let scalars: [UnicodeScalar]
    private var index = 0
    private static let commandLetters = Set("MmLlHhVvCcSsQqTtAaZz")

    init(_ pathData: String) {
        self.scalars = Array(pathData.unicodeScalars)
    }

    mutating func tokenize() -> [SVGPathToken] {
        var tokens: [SVGPathToken] = []
        while let token = nextToken() {
            tokens.append(token)
        }
        return tokens
    }

    private mutating func nextToken() -> SVGPathToken? {
        skipSeparators()
        guard index < scalars.count else { return nil }
        let scalar = scalars[index]
        if Self.commandLetters.contains(Character(String(scalar))) {
            index += 1
            return .command(Character(String(scalar)))
        }

        let start = index
        var seenExponent = scalar == "e" || scalar == "E"
        var seenDecimalSeparator = scalar == "."
        index += 1
        while index < scalars.count {
            let current = scalars[index]
            if isSeparator(current) {
                break
            }
            if Self.commandLetters.contains(Character(String(current))) {
                break
            }
            if current == "+" || current == "-" {
                let previous = scalars[index - 1]
                if previous == "e" || previous == "E" {
                    index += 1
                    continue
                }
                break
            }
            if current == "." {
                if seenDecimalSeparator && !seenExponent {
                    break
                }
                seenDecimalSeparator = true
                index += 1
                continue
            }
            if current == "e" || current == "E" {
                if seenExponent {
                    break
                }
                seenExponent = true
                index += 1
                continue
            }
            index += 1
        }

        let valueString = String(String.UnicodeScalarView(scalars[start..<index]))
        guard let value = Double(valueString) else {
            return nil
        }
        return .number(CGFloat(value))
    }

    private mutating func skipSeparators() {
        while index < scalars.count, isSeparator(scalars[index]) {
            index += 1
        }
    }

    private func isSeparator(_ scalar: UnicodeScalar) -> Bool {
        scalar == "," || CharacterSet.whitespacesAndNewlines.contains(scalar)
    }
}

private struct SVGPathParser {
    private let tokens: [SVGPathToken]
    private var index = 0
    private var currentPoint = CGPoint.zero
    private var subpathStart = CGPoint.zero
    private var lastCubicControl: CGPoint?
    private var lastQuadControl: CGPoint?

    init(pathData: String) {
        var tokenizer = SVGPathTokenizer(pathData)
        self.tokens = tokenizer.tokenize()
    }

    mutating func parse() -> CGPath? {
        let path = CGMutablePath()
        var activeCommand: Character?

        while index < tokens.count {
            if case let .command(command) = tokens[index] {
                activeCommand = command
                index += 1
            } else if activeCommand == nil {
                return nil
            }

            guard let command = activeCommand else { break }
            if !append(command: command, to: path) {
                return nil
            }
        }

        return path
    }

    private mutating func append(command: Character, to path: CGMutablePath) -> Bool {
        switch command {
        case "M", "m":
            guard let first = readPoint(relative: command == "m") else { return false }
            path.move(to: first)
            currentPoint = first
            subpathStart = first
            lastCubicControl = nil
            lastQuadControl = nil
            while hasNumber {
                guard let next = readPoint(relative: command == "m") else { return false }
                path.addLine(to: next)
                currentPoint = next
            }
            return true

        case "L", "l":
            while hasNumber {
                guard let point = readPoint(relative: command == "l") else { return false }
                path.addLine(to: point)
                currentPoint = point
            }
            lastCubicControl = nil
            lastQuadControl = nil
            return true

        case "H", "h":
            while let x = readNumber() {
                let point = CGPoint(x: command == "h" ? currentPoint.x + x : x, y: currentPoint.y)
                path.addLine(to: point)
                currentPoint = point
            }
            lastCubicControl = nil
            lastQuadControl = nil
            return true

        case "V", "v":
            while let y = readNumber() {
                let point = CGPoint(x: currentPoint.x, y: command == "v" ? currentPoint.y + y : y)
                path.addLine(to: point)
                currentPoint = point
            }
            lastCubicControl = nil
            lastQuadControl = nil
            return true

        case "C", "c":
            while hasNumber {
                guard
                    let c1 = readPoint(relative: command == "c"),
                    let c2 = readPoint(relative: command == "c"),
                    let end = readPoint(relative: command == "c")
                else { return false }
                path.addCurve(to: end, control1: c1, control2: c2)
                currentPoint = end
                lastCubicControl = c2
                lastQuadControl = nil
            }
            return true

        case "S", "s":
            while hasNumber {
                let reflected = reflectedControlPoint(lastCubicControl, around: currentPoint)
                guard
                    let c2 = readPoint(relative: command == "s"),
                    let end = readPoint(relative: command == "s")
                else { return false }
                path.addCurve(to: end, control1: reflected, control2: c2)
                currentPoint = end
                lastCubicControl = c2
                lastQuadControl = nil
            }
            return true

        case "Q", "q":
            while hasNumber {
                guard
                    let control = readPoint(relative: command == "q"),
                    let end = readPoint(relative: command == "q")
                else { return false }
                path.addQuadCurve(to: end, control: control)
                currentPoint = end
                lastQuadControl = control
                lastCubicControl = nil
            }
            return true

        case "T", "t":
            while hasNumber {
                let reflected = reflectedControlPoint(lastQuadControl, around: currentPoint)
                guard let end = readPoint(relative: command == "t") else { return false }
                path.addQuadCurve(to: end, control: reflected)
                currentPoint = end
                lastQuadControl = reflected
                lastCubicControl = nil
            }
            return true

        case "A", "a":
            while hasNumber {
                guard
                    let rx = readNumber(),
                    let ry = readNumber(),
                    let rotation = readNumber(),
                    let largeArc = readFlag(),
                    let sweep = readFlag(),
                    let end = readPoint(relative: command == "a")
                else { return false }
                appendArc(
                    to: path,
                    from: currentPoint,
                    rx: rx,
                    ry: ry,
                    xAxisRotation: rotation,
                    largeArc: largeArc,
                    sweep: sweep,
                    end: end
                )
                currentPoint = end
                lastCubicControl = nil
                lastQuadControl = nil
            }
            return true

        case "Z", "z":
            path.closeSubpath()
            currentPoint = subpathStart
            lastCubicControl = nil
            lastQuadControl = nil
            return true

        default:
            return false
        }
    }

    private var hasNumber: Bool {
        guard index < tokens.count else { return false }
        if case .number = tokens[index] { return true }
        return false
    }

    private mutating func readNumber() -> CGFloat? {
        guard index < tokens.count else { return nil }
        if case let .number(value) = tokens[index] {
            index += 1
            return value
        }
        return nil
    }

    private mutating func readFlag() -> Bool? {
        guard let value = readNumber() else { return nil }
        return value != 0
    }

    private mutating func readPoint(relative: Bool) -> CGPoint? {
        guard let x = readNumber(), let y = readNumber() else { return nil }
        if relative {
            return CGPoint(x: currentPoint.x + x, y: currentPoint.y + y)
        }
        return CGPoint(x: x, y: y)
    }

    private func reflectedControlPoint(_ point: CGPoint?, around current: CGPoint) -> CGPoint {
        guard let point else {
            return current
        }
        return CGPoint(x: current.x * 2 - point.x, y: current.y * 2 - point.y)
    }

    private func appendArc(
        to path: CGMutablePath,
        from start: CGPoint,
        rx rawRx: CGFloat,
        ry rawRy: CGFloat,
        xAxisRotation: CGFloat,
        largeArc: Bool,
        sweep: Bool,
        end: CGPoint
    ) {
        if start == end {
            return
        }

        var rx = abs(rawRx)
        var ry = abs(rawRy)
        if rx == 0 || ry == 0 {
            path.addLine(to: end)
            return
        }

        let phi = xAxisRotation * .pi / 180
        let cosPhi = cos(phi)
        let sinPhi = sin(phi)
        let dx = (start.x - end.x) * 0.5
        let dy = (start.y - end.y) * 0.5
        let x1p = cosPhi * dx + sinPhi * dy
        let y1p = -sinPhi * dx + cosPhi * dy

        let lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
        if lambda > 1 {
            let scale = sqrt(lambda)
            rx *= scale
            ry *= scale
        }

        let rx2 = rx * rx
        let ry2 = ry * ry
        let x1p2 = x1p * x1p
        let y1p2 = y1p * y1p
        let sign: CGFloat = largeArc == sweep ? -1 : 1
        let numerator = max(CGFloat.zero, rx2 * ry2 - rx2 * y1p2 - ry2 * x1p2)
        let denominator = max(rx2 * y1p2 + ry2 * x1p2, CGFloat.leastNonzeroMagnitude)
        let coefficient = sign * sqrt(numerator / denominator)
        let cxp = coefficient * (rx * y1p / ry)
        let cyp = coefficient * (-ry * x1p / rx)
        let center = CGPoint(
            x: cosPhi * cxp - sinPhi * cyp + (start.x + end.x) * 0.5,
            y: sinPhi * cxp + cosPhi * cyp + (start.y + end.y) * 0.5
        )

        let startVector = CGPoint(x: (x1p - cxp) / rx, y: (y1p - cyp) / ry)
        let endVector = CGPoint(x: (-x1p - cxp) / rx, y: (-y1p - cyp) / ry)

        var startAngle = atan2(startVector.y, startVector.x)
        var deltaAngle = angleBetween(startVector, endVector)

        if !sweep && deltaAngle > 0 {
            deltaAngle -= 2 * .pi
        } else if sweep && deltaAngle < 0 {
            deltaAngle += 2 * .pi
        }

        let segments = Int(ceil(abs(deltaAngle) / (.pi / 2)))
        let step = deltaAngle / CGFloat(max(segments, 1))

        for _ in 0..<max(segments, 1) {
            let endAngle = startAngle + step
            addArcSegment(
                to: path,
                center: center,
                rx: rx,
                ry: ry,
                rotation: phi,
                startAngle: startAngle,
                endAngle: endAngle
            )
            startAngle = endAngle
        }
    }

    private func angleBetween(_ u: CGPoint, _ v: CGPoint) -> CGFloat {
        atan2(u.x * v.y - u.y * v.x, u.x * v.x + u.y * v.y)
    }

    private func addArcSegment(
        to path: CGMutablePath,
        center: CGPoint,
        rx: CGFloat,
        ry: CGFloat,
        rotation: CGFloat,
        startAngle: CGFloat,
        endAngle: CGFloat
    ) {
        let delta = endAngle - startAngle
        let alpha = (4.0 / 3.0) * tan(delta / 4.0)

        let p0 = ellipsePoint(center: center, rx: rx, ry: ry, rotation: rotation, angle: startAngle)
        let p3 = ellipsePoint(center: center, rx: rx, ry: ry, rotation: rotation, angle: endAngle)
        let d0 = ellipseDerivative(rx: rx, ry: ry, rotation: rotation, angle: startAngle)
        let d1 = ellipseDerivative(rx: rx, ry: ry, rotation: rotation, angle: endAngle)
        let p1 = CGPoint(x: p0.x + alpha * d0.x, y: p0.y + alpha * d0.y)
        let p2 = CGPoint(x: p3.x - alpha * d1.x, y: p3.y - alpha * d1.y)
        path.addCurve(to: p3, control1: p1, control2: p2)
    }

    private func ellipsePoint(
        center: CGPoint,
        rx: CGFloat,
        ry: CGFloat,
        rotation: CGFloat,
        angle: CGFloat
    ) -> CGPoint {
        let x = rx * cos(angle)
        let y = ry * sin(angle)
        let cosRotation = cos(rotation)
        let sinRotation = sin(rotation)
        return CGPoint(
            x: center.x + x * cosRotation - y * sinRotation,
            y: center.y + x * sinRotation + y * cosRotation
        )
    }

    private func ellipseDerivative(
        rx: CGFloat,
        ry: CGFloat,
        rotation: CGFloat,
        angle: CGFloat
    ) -> CGPoint {
        let dx = -rx * sin(angle)
        let dy = ry * cos(angle)
        let cosRotation = cos(rotation)
        let sinRotation = sin(rotation)
        return CGPoint(
            x: dx * cosRotation - dy * sinRotation,
            y: dx * sinRotation + dy * cosRotation
        )
    }
}

private extension Color {
    init?(hex: String?) {
        guard let hex else { return nil }
        var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitized = sanitized.replacingOccurrences(of: "#", with: "")
        guard sanitized.count == 6, let intValue = Int(sanitized, radix: 16) else {
            return nil
        }
        let red = Double((intValue >> 16) & 0xFF) / 255.0
        let green = Double((intValue >> 8) & 0xFF) / 255.0
        let blue = Double(intValue & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue)
    }
}

func debugStartIconAssetName(_ rawValue: String?) -> String {
    switch normalizedStartVisualIcon(rawValue) {
    case .defaultSailboat:
        return "system:sailboat.fill"
    case .character(let glyph):
        return "character:\(glyph)"
    case .preset(let iconKey):
        return startIconAssetName(for: iconKey)
    }
}
