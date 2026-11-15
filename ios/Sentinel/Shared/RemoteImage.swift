import SwiftUI

/// Zeigt ein auf dem Server abgelegtes Bild, ersatzweise einen Platzhalter.
struct RemoteImage<Placeholder: View>: View {
    let blobId: String?
    @ViewBuilder var placeholder: () -> Placeholder

    @Environment(PhotoStore.self) private var photos
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder()
            }
        }
        .task(id: blobId) {
            guard let blobId else {
                image = nil
                return
            }
            image = photos.cached(blobId)
            if image == nil { image = await photos.image(id: blobId) }
        }
    }
}

/// Rundes Profilbild mit Initialen als Ersatz.
struct Avatar: View {
    let blobId: String?
    let fallbackText: String
    var size: CGFloat = 44
    var tint: Color = .accentColor

    var body: some View {
        RemoteImage(blobId: blobId) {
            ZStack {
                tint.opacity(0.25)
                Text(fallbackText)
                    .font(.system(size: size * 0.32, weight: .semibold, design: .rounded))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, size * 0.12)
                    .frame(width: size, height: size, alignment: .center)
            }
        }
        .frame(width: size, height: size)
        .clipShape(.circle)
        .accessibilityHidden(true)
    }
}
