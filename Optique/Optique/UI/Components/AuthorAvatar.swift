import SwiftUI

/// A round author photo loaded through `ImagePipeline`: decoded at its own size off the main thread and
/// kept in memory, so rows that scroll back (or screens that are rebuilt) show it at once.
struct AuthorAvatar: View {
    let url: String?
    var size: CGFloat = 24

    var body: some View {
        PipelineImage(url: url.flatMap(URL.init(string:)), maxPixel: Int(size * 3)) { image in
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Circle().fill(AppColors.Adaptive.surfaceElevated)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}
