import SwiftUI
import ImageIO

/// Memory-cached, downsampled image loading. Decoding happens off the main thread at the size
/// the view needs, so scrolling and pushes never wait on full-resolution decodes, and images
/// already seen render synchronously (no placeholder flash when a screen is rebuilt).
nonisolated final class ImagePipeline: @unchecked Sendable {
    static let shared = ImagePipeline()

    private let cache = NSCache<NSString, UIImage>()
    /// The largest decode seen per URL, shown while a page needs that image at another size
    /// (e.g. a row's thumbnail standing in for the story page's header until it is decoded).
    private let anySize = NSCache<NSString, UIImage>()
    private let session: URLSession
    private let lock = NSLock()
    private var inflight: [String: Task<UIImage?, Never>] = [:]
    /// The original pixel size of every image downloaded, which the downsampled copies no longer carry.
    private var originalSizes: [String: CGSize] = [:]

    /// Sharp enough for a cover: judged on the real pixel size of the file. (The DPI tag is not used: publishers
    /// write anything in it, from 1 to 300, whatever the size.)
    static let minimumCover = CGSize(width: 700, height: 400)

    /// Whether this downloaded image is big enough to be a cover. Unknown (not downloaded yet) counts as not sharp.
    func isSharp(_ url: URL) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard let size = originalSizes[url.absoluteString] else { return false }
        return size.width >= Self.minimumCover.width && size.height >= Self.minimumCover.height
    }

    private func record(_ size: CGSize, for url: URL) {
        lock.lock(); originalSizes[url.absoluteString] = size; lock.unlock()
    }

    /// The first of `urls` that is already decoded and sharp, without waiting.
    func cachedSharp(_ urls: [URL], maxPixel: Int) -> UIImage? {
        for url in urls {
            guard let image = cached(url, maxPixel: maxPixel) else { return nil }
            if isSharp(url) { return image }
        }
        return nil
    }

    /// The first of `urls`, in order, whose real size is sharp; nil when none is.
    func firstSharp(_ urls: [URL], maxPixel: Int) async -> UIImage? {
        for url in urls {
            if let image = await image(url, maxPixel: maxPixel), isSharp(url) { return image }
        }
        return nil
    }

    private init() {
        cache.totalCostLimit = 96 * 1024 * 1024
        anySize.totalCostLimit = 48 * 1024 * 1024
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(memoryCapacity: 32 * 1024 * 1024, diskCapacity: 256 * 1024 * 1024)
        config.requestCachePolicy = .returnCacheDataElseLoad
        session = URLSession(configuration: config)
    }

    private func key(_ url: URL, _ maxPixel: Int) -> String { "\(maxPixel)|\(url.absoluteString)" }

    func cached(_ url: URL, maxPixel: Int) -> UIImage? {
        cache.object(forKey: key(url, maxPixel) as NSString)
    }

    /// Any decoded size of this image, for an instant stand-in.
    func cachedAnySize(_ url: URL) -> UIImage? {
        anySize.object(forKey: url.absoluteString as NSString)
    }

    func image(_ url: URL, maxPixel: Int) async -> UIImage? {
        let k = key(url, maxPixel)
        if let hit = cache.object(forKey: k as NSString) { return hit }

        lock.lock()
        if let task = inflight[k] { lock.unlock(); return await task.value }
        let task = Task.detached(priority: .userInitiated) { [session, cache, anySize, self] () -> UIImage? in
            guard let (data, _) = try? await session.data(from: url),
                  let image = Self.downsample(data, maxPixel: maxPixel) else { return nil }
            if let size = Self.pixelSize(data) { self.record(size, for: url) }
            let cost = Int(image.size.width * image.size.height * 4 * image.scale * image.scale)
            cache.setObject(image, forKey: k as NSString, cost: cost)
            let urlKey = url.absoluteString as NSString
            if (anySize.object(forKey: urlKey)?.size.width ?? 0) < image.size.width {
                anySize.setObject(image, forKey: urlKey, cost: cost)
            }
            return image
        }
        inflight[k] = task
        lock.unlock()

        let result = await task.value
        lock.lock(); inflight[k] = nil; lock.unlock()
        return result
    }

    private static func pixelSize(_ data: Data) -> CGSize? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? CGFloat,
              let h = props[kCGImagePropertyPixelHeight] as? CGFloat else { return nil }
        return CGSize(width: w, height: h)
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
    /// Other photos to try, in order, when judging by real size (see `sharpOnly`).
    var alternates: [URL] = []
    /// Only accept a photo whose real pixel size is sharp enough for a cover; otherwise show nothing.
    var sharpOnly = false
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
                    if sharpOnly {
                        let urls = [url] + alternates
                        if ImagePipeline.shared.cachedSharp(urls, maxPixel: maxPixel) != nil { return }
                        loaded = await ImagePipeline.shared.firstSharp(urls, maxPixel: maxPixel)
                        return
                    }
                    if ImagePipeline.shared.cached(url, maxPixel: maxPixel) != nil { return }
                    let image = await ImagePipeline.shared.image(url, maxPixel: maxPixel)
                    loaded = image
                }
            content(shown)
        }
    }

    /// What to draw now: the loaded photo, else (synchronously) a cached one, else a stand-in.
    private var shown: UIImage? {
        if sharpOnly {
            guard let url else { return nil }
            return loaded ?? ImagePipeline.shared.cachedSharp([url] + alternates, maxPixel: maxPixel)
        }
        return loaded ?? url.flatMap {
            ImagePipeline.shared.cached($0, maxPixel: maxPixel) ?? ImagePipeline.shared.cachedAnySize($0)
        }
    }
}
