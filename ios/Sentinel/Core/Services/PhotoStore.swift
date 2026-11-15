import Observation
import UIKit

/// Lädt und speichert Bilder (Profil-, Fahrzeug- und Zielpersonenfotos) über den Server.
/// Bilder liegen nur im Arbeitsspeicher, nie unverschlüsselt auf der Platte.
@MainActor
@Observable
final class PhotoStore {
    @ObservationIgnored private let cache = NSCache<NSString, UIImage>()
    @ObservationIgnored private var inFlight: [String: Task<UIImage?, Never>] = [:]
    @ObservationIgnored var client: APIClient?

    init() {
        cache.countLimit = 120
    }

    func cached(_ id: String) -> UIImage? {
        cache.object(forKey: id as NSString)
    }

    func image(id: String) async -> UIImage? {
        if let hit = cached(id) { return hit }
        if let running = inFlight[id] { return await running.value }
        guard let client else { return nil }
        let task = Task<UIImage?, Never> {
            guard let data = try? await client.image(id: id) else { return nil }
            return UIImage(data: data)
        }
        inFlight[id] = task
        let image = await task.value
        inFlight[id] = nil
        if let image { cache.setObject(image, forKey: id as NSString) }
        return image
    }

    /// Verkleinert das Bild, entfernt dabei sämtliche Metadaten (auch Aufnahmeort) und lädt es hoch.
    func upload(_ image: UIImage) async throws -> String {
        guard let client else { throw APIError.unauthorized }
        guard let jpeg = Self.prepare(image) else { throw APIError.transport("Bild konnte nicht verarbeitet werden") }
        let id = try await client.uploadImage(jpeg)
        if let stored = UIImage(data: jpeg) { cache.setObject(stored, forKey: id as NSString) }
        return id
    }

    func reset() {
        cache.removeAllObjects()
        inFlight.values.forEach { $0.cancel() }
        inFlight = [:]
        client = nil
    }

    /// Neu gezeichnetes JPEG mit höchstens 1280 Punkten Kantenlänge. Durch das Neuzeichnen gehen EXIF-Daten verloren.
    static func prepare(_ image: UIImage, maxDimension: CGFloat = 1280) -> Data? {
        let longest = max(image.size.width, image.size.height)
        guard longest > 0 else { return nil }
        let scale = min(1, maxDimension / longest)
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return rendered.jpegData(compressionQuality: 0.8)
    }
}
