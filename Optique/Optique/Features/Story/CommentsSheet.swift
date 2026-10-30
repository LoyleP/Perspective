import SwiftUI

/// Story discussion in a bottom sheet, laid out like Instagram's comments: grabber, centered
/// title, avatar rows with a heart on the right, collapsed replies, and a composer with a quick
/// emoji row.
struct CommentsSheet: View {
    let story: Story

    @Environment(\.commentStore) private var store
    @State private var text = ""
    @State private var replyingTo: Comment?
    @State private var expanded: Set<UUID> = []
    @FocusState private var focused: Bool

    private static let quickEmojis = ["❤️", "🙌", "🔥", "👏", "💚", "😍", "😮", "😢"]

    var body: some View {
        VStack(spacing: 0) {
            Text("Commentaires")
                .font(.appBodyStrong)
                .foregroundStyle(AppColors.Adaptive.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.top, AppSpacing.l)
                .padding(.bottom, AppSpacing.m)
                .accessibilityAddTraits(.isHeader)

            list
            composer
        }
        .background(AppColors.Adaptive.background)
        .presentationDetents([.fraction(0.8), .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - List

    private var list: some View {
        let comments = store.topLevel(for: story.id)
        return ScrollView {
            if comments.isEmpty {
                VStack(spacing: AppSpacing.s) {
                    Text("Aucun commentaire")
                        .font(.appBodyStrong)
                        .foregroundStyle(AppColors.Adaptive.textPrimary)
                    Text("Lancez la discussion.")
                        .font(.appBody)
                        .foregroundStyle(AppColors.Adaptive.textMeta)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, AppSpacing.xxl)
            } else {
                LazyVStack(alignment: .leading, spacing: AppSpacing.l) {
                    ForEach(comments) { comment in
                        VStack(alignment: .leading, spacing: AppSpacing.st) {
                            row(comment, avatar: 36)
                            replies(of: comment)
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.m)
                .padding(.bottom, AppSpacing.l)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func row(_ comment: Comment, avatar: CGFloat) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.st) {
            Image("ProfilePlaceholder")
                .resizable()
                .scaledToFill()
                .frame(width: avatar, height: avatar)
                .clipShape(Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: AppSpacing.s) {
                    Text(comment.author)
                        .font(.appCaption)
                        .foregroundStyle(AppColors.Adaptive.textPrimary)
                    Text(comment.createdAt.relativeToNowFrench())
                        .font(.appCaption)
                        .foregroundStyle(AppColors.Adaptive.textMeta)
                }
                Text(comment.text)
                    .font(.appBody)
                    .foregroundStyle(AppColors.Adaptive.textPrimary)
                    .multilineTextAlignment(.leading)
                Button("Répondre") {
                    replyingTo = comment.parentID.flatMap { id in store.comments.first { $0.id == id } } ?? comment
                    text = "@\(comment.author) "
                    focused = true
                }
                .font(.appCaption)
                .foregroundStyle(AppColors.Adaptive.textMeta)
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                store.toggleLike(comment.id)
            } label: {
                VStack(spacing: 2) {
                    HeroIcon("heart", solid: comment.likedByMe, size: 18)
                        .foregroundStyle(AppColors.Adaptive.textPrimary.opacity(comment.likedByMe ? 1 : 0.62))
                    if comment.likes > 0 {
                        Text("\(comment.likes)")
                            .font(.appCaption)
                            .monospacedDigit()
                            .foregroundStyle(AppColors.Adaptive.textMeta)
                    }
                }
                .frame(minWidth: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(comment.likedByMe ? "Retirer le j'aime" : "J'aime")
        }
    }

    @ViewBuilder
    private func replies(of comment: Comment) -> some View {
        let replies = store.replies(to: comment.id)
        if !replies.isEmpty {
            let isOpen = expanded.contains(comment.id)
            VStack(alignment: .leading, spacing: AppSpacing.st) {
                Button {
                    if isOpen { expanded.remove(comment.id) } else { expanded.insert(comment.id) }
                } label: {
                    HStack(spacing: AppSpacing.s) {
                        Capsule()
                            .fill(AppColors.Adaptive.divider)
                            .frame(width: 24, height: 1)
                        Text(isOpen ? "Masquer les réponses"
                             : replies.count == 1 ? "Voir 1 réponse" : "Voir \(replies.count) réponses")
                            .font(.appCaption)
                            .foregroundStyle(AppColors.Adaptive.textMeta)
                    }
                }
                .buttonStyle(.plain)

                if isOpen {
                    ForEach(replies) { reply in
                        row(reply, avatar: 24)
                    }
                }
            }
            .padding(.leading, 36 + AppSpacing.st)
        }
    }

    // MARK: - Composer

    private var composer: some View {
        VStack(spacing: 0) {
            if focused {
                HStack {
                    ForEach(Self.quickEmojis, id: \.self) { emoji in
                        Button { text += emoji } label: {
                            Text(emoji).font(.appHeading)
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, AppSpacing.s)
                .padding(.horizontal, AppSpacing.s)
            }
            HStack(spacing: AppSpacing.st) {
                Image("ProfilePlaceholder")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                    .accessibilityHidden(true)

                HStack(spacing: AppSpacing.s) {
                    TextField("Ajouter un commentaire…", text: $text, axis: .vertical)
                        .font(.appBody)
                        .foregroundStyle(AppColors.Adaptive.textPrimary)
                        .lineLimit(1...4)
                        .focused($focused)
                        .submitLabel(.send)
                        .onSubmit(send)
                    if !text.trimmingCharacters(in: .whitespaces).isEmpty {
                        Button(action: send) {
                            HeroIcon("arrow-up", size: 16)
                                .foregroundStyle(AppColors.Brand.onInk)
                                .frame(width: 32, height: 32)
                                .background(AppColors.Brand.accent, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Publier")
                    }
                }
                .padding(.leading, AppSpacing.m)
                .padding(.trailing, AppSpacing.xs)
                .padding(.vertical, AppSpacing.xs)
                .frame(minHeight: 44)
                .overlay(Capsule().stroke(AppColors.stroke, lineWidth: 1))
            }
            .padding(.horizontal, AppSpacing.m)
            .padding(.vertical, AppSpacing.s)
        }
        .background(AppColors.Adaptive.background)
        .overlay(alignment: .top) { Divider().overlay(AppColors.Adaptive.divider) }
    }

    private func send() {
        store.add(text, to: story.id, replyingTo: replyingTo?.id)
        if let parent = replyingTo { expanded.insert(parent.id) }
        text = ""
        replyingTo = nil
    }
}
