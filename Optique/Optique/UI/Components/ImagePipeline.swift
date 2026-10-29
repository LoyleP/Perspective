import SwiftUI
import ImageIO

/// Memory-cached, downsampled image loading. Decoding happens off the main thread at the size
/// the view needs, so scrolling and pushes never wait on full-resolution decodes, and images
/// already seen render synchronously (no placeholder flash when a screen is rebuilt).
final class ImagePipeline: @unchecked Sendable {
    static let shared = ImagePipeline()

    private let cache = NSCache<NSString, UIImage>()
    private let session: URLSession
    private let lock = NSLock()
    private var inflight: [String: Task<UIImage?, Never>] = [:]

    private init() {
        cache.totalCostLimit = 96 * 1024 * 1024
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(memoryCapacity: 32 * 1024 * 1024, diskCapacity: 256 * 1024 * 1024)
        config.requestCachePolicy = .returnCacheDataElseLoad
        session = URLSession(configuration: config)
    }

    private func key(_ url: URL, _ maxPixel: Int) -> String { "\(maxPixel)|\(url.absoluteString)" }

    func cached(_ url: URL, maxPixel: Int) -> UIImage? {
        cache.object(forKey: key(url, maxPixel) as NSString)
    }

    func image(_ url: URL, maxPixel: Int) async -> UIImage? {
        let k = key(url, maxPixel)
        if let hit = cache.object(forKey: k as NSString) { return hit }

        lock.lock()
        if let task = inflight[k] { lock.unlock(); return await task.value }
        let task = Task.detached(priority: .userInitiated) { [session, cache] () -> UIImage? in
            guard let (data, _) = try? await session.data(from: url),
                  let image = Self.downsample(data, maxPixel: maxPixel) else { return nil }
            cache.setObject(image, forKey: k as NSString, cost: Int(image.size.width * image.size.height * 4 * image.scale * image.scale))
            return image
        }
        inflight[k] = task
        lock.unlock()

        let result = await task.value
        lock.lock(); inflight[k] = nil; lock.unlock()
        return result
    }

    private static func downsample(_ data: Data, maxPixel: Int) -> UIImage? {
        let opts = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, opts) else { return nil }
        let thumbOpts = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,   // decode now, on this background thread
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ] as CFDictionary
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOpts) else { return nil }
        return UIImage(cgImage: cg)
    }
}

/// Loads `url` through `ImagePipeline` and hands the result to `content`.
struct PipelineImage<Content: View>: View {
    let url: URL?
    let maxPixel: Int
    @ViewBuilder var content: (UIImage?) -> Content

    @State private var loaded: UIImage?

    var body: some View {
        // The loader hangs off a real (zero-size) view: `.task` never fires on an EmptyView,
        // which is what `content` is while there is no image (e.g. source logos).
        ZStack {
            Color.clear
                .frame(width: 0, height: 0)
                .task(id: url) {
                    guard let url else { loaded = nil; return }
                    if ImagePipeline.shared.cached(url, maxPixel: maxPixel) != nil { return }
                    let image = await ImagePipeline.shared.image(url, maxPixel: maxPixel)
                    withAnimation(.easeOut(duration: 0.2)) { loaded = image }
                }
            content(loaded ?? url.flatMap { ImagePipeline.shared.cached($0, maxPixel: maxPixel) })
        }
    }
}
