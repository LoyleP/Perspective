import SwiftUI

/// Comment author's avatar: your own photo, or the author's initial on a neutral circle.
struct CommentAvatar: View {
    let author: String
    var size: CGFloat = 36

    var body: some View {
        Group {
            if author == CommentStore.selfName {
                Image("ProfilePlaceholder")
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle().fill(AppColors.Adaptive.surfaceElevated)
                    Text(String(author.prefix(1)).uppercased())
                        .font(.appCaption)
                        .foregroundStyle(AppColors.Adaptive.textSecondary)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}
