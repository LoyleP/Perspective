import SwiftUI

/// Story discussion in a bottom panel, laid out like Instagram's comments: grabber, centered
/// title, avatar rows with a heart on the right, collapsed replies, and a composer with a quick
/// emoji row. It is a custom panel rather than a system sheet so it can sit flush against the
/// left, right and bottom edges of the screen (iOS 26 sheets float with a margin).
struct CommentsSheet: View {
    let story: Story
    /// Opens with the keyboard up, ready to type (from "Ajouter un commentaire").
    var startsTyping = false
    let onClose: () -> Void

    @Environment(\.commentStore) private var store
    @Environment(\.tabBarState) private var tabBar
    @State private var text = ""
    @State private var replyingTo: Comment?
    @State private var expanded: Set<UUID> = []
    @State private var dragOffset: CGFloat = 0
    /// Full mode: the panel is on screen. It slides in and out by itself (app curve) while the
    /// parent only inserts and removes it, so the exit can finish before the view goes away.
    @State private var shown = false
    /// Compact mode with no software keyboard (hardware keyboard): shown after a timeout.
    @State private var shownWithoutKeyboard = false
    @State private var fallbackTask: Task<Void, Never>?
    /// Measured panel height; starts large so the panel is off screen until measured.
    @State private var panelHeight: CGFloat = 2000
    /// Height of the comment list's content: the full panel hugs it, up to the medium detent.
    @State private var listHeight: CGFloat = 0
    /// Full mode snapped to the large detent by pulling the grabber or the list up.
    @State private var fullHeight = false
    /// How far the grabber is being pulled up (the panel grows with the finger).
    @State private var lift: CGFloat = 0
    /// Panel height at rest, the base the pull-up grows from.
    @State private var restingHeight: CGFloat = 0
    /// How many quick emojis have popped in (they cascade in once the keyboard is up).
    @State private var emojisShown = 0
    @State private var emojiTask: Task<Void, Never>?
    @FocusState private var focused: Bool

    private static let quickEmojis = ["❤️", "🙌", "🔥", "👏", "💚", "😍", "😮", "😢"]
    /// Native-sheet geometry (measured from the system sheet this replaces): the medium detent
    /// starts about 27% down the screen, the large one (keyboard up) about 60pt from the top,
    /// and the top corners have a radius of about 44pt.
    private static let mediumTopFraction: CGFloat = 0.27
    private static let largeTopGap: CGFloat = 60
    private static let cornerRadius: CGFloat = 44

    /// Opened to type: the panel hugs the top comment and the composer, riding on the keyboard.
    private var compact: Bool { startsTyping }

    // Keyboard handling follows Instagram's comment sheet: the panel's content respects the
    // keyboard safe area, so the system moves it with the keyboard's own animation (no manual
    // height tracking), while its background ignores it and runs behind the keyboard to the
    // bottom of the screen.
    //
    // Compact mode goes one step further: whether the panel is on screen is read from the
    // keyboard inset itself. The keyboard's safe-area change and the panel's slide then happen in
    // the same layout pass, so they share the keyboard's curve and move as one, in and out. A
    // cold keyboard's first-launch stall happens before that pass, while the panel is still off
    // screen, so it can't swallow the slide.
    var body: some View {
        GeometryReader { geo in
            let bottomInset = geo.safeAreaInsets.bottom
            let screenHeight = geo.size.height + geo.safeAreaInsets.top + bottomInset
            let keyboardUp = bottomInset > 120
            let visible = compact ? keyboardUp || shownWithoutKeyboard : shown
            // Just below the screen: the panel's own height plus whatever sits under it.
            let hiddenOffset = panelHeight + bottomInset
            ZStack(alignment: .bottom) {
                // Backdrop: shown and hidden instantly (no fade); a tap closes the panel.
                Color.black.opacity(visible ? 0.45 : 0)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture(perform: close)
                    .transaction { $0.animation = nil }
                    .accessibilityHidden(true)

                panel
                    .padding(.top, compact ? 0 : topGap(screenHeight: screenHeight) - geo.safeAreaInsets.top)
                    .animation(.app, value: focused)
                    .animation(.app, value: fullHeight)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { panelHeight = $0 }
                    .offset(y: visible ? dragOffset : hiddenOffset)
            }
        }
        .onAppear {
            tabBar.isHidden = true
            if compact {
                focused = true
                fallbackTask = Task {
                    try? await Task.sleep(for: .milliseconds(700))
                    guard !Task.isCancelled else { return }
                    withAnimation(.app) { shownWithoutKeyboard = true }
                }
            } else {
                withAnimation(.app) { shown = true }
            }
        }
        .onDisappear { tabBar.isHidden = false }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            fallbackTask?.cancel()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidHideNotification)) { _ in
            // Compact mode lives on the keyboard: once it's gone (closed, or dismissed), so is the panel.
            if compact && !shownWithoutKeyboard { onClose() }
        }
    }

    /// Full mode is at the large detent: typing, or pulled up.
    private var isLarge: Bool { focused || fullHeight }

    private func topGap(screenHeight: CGFloat) -> CGFloat {
        isLarge || lift > 0 ? Self.largeTopGap : screenHeight * Self.mediumTopFraction
    }

    /// Exit mirrors the entry. Compact: dropping the keyboard takes the panel down with it, on the
    /// keyboard's curve, and the parent removes the view once the keyboard is hidden. Full: the
    /// panel slides down on the app curve while the keyboard (if any) drops.
    private func close() {
        focused = false
        if compact && !shownWithoutKeyboard { return }
        if compact {
            withAnimation(.app) { shownWithoutKeyboard = false } completion: { onClose() }
        } else {
            withAnimation(.app) { shown = false } completion: { onClose() }
        }
    }

    private var panel: some View {
        VStack(spacing: 0) {
            header
            if compact { topComment } else { list }
            composer
        }
        .frame(minHeight: lift > 0 ? restingHeight + lift : nil)
        .frame(maxWidth: .infinity, maxHeight: compact || !isLarge ? nil : .infinity, alignment: .top)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
            if lift == 0 { restingHeight = height }
        }
        .background {
            UnevenRoundedRectangle(topLeadingRadius: Self.cornerRadius, topTrailingRadius: Self.cornerRadius)
                .fill(AppColors.Adaptive.cardSurface)
                .ignoresSafeArea(edges: .bottom)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)) { _ in
            playEmojis()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            resetEmojis()
        }
        .onChange(of: focused) { _, isFocused in
            if isFocused {
                // Fallback for when no keyboard event arrives (hardware keyboard).
                emojiTask?.cancel()
                emojiTask = Task {
                    try? await Task.sleep(for: .milliseconds(700))
                    guard !Task.isCancelled, emojisShown == 0 else { return }
                    playEmojis()
                }
            } else {
                resetEmojis()
            }
        }
    }

    /// Grabber; dragging it down closes the panel.
    private var header: some View {
        VStack(spacing: AppSpacing.st) {
            Capsule()
                .fill(AppColors.Adaptive.textPrimary.opacity(0.3))
                .frame(width: 36, height: 5)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, AppSpacing.s)
        .padding(.bottom, AppSpacing.m)
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { value in
                    let dy = value.translation.height
                    if dy < 0 && !compact && !isLarge {
                        lift = -dy   // pulling up: the panel grows with the finger
                        dragOffset = 0
                    } else {
                        lift = 0
                        dragOffset = max(dy, 0)
                    }
                }
                .onEnded { value in
                    let predicted = value.predictedEndTranslation.height
                    if lift > 0 {
                        // Snap to full height, or settle back.
                        let snaps = lift > 60 || predicted < -200
                        withAnimation(.app) {
                            if snaps { fullHeight = true }
                            lift = 0
                        }
                    } else if value.translation.height > 120 || predicted > 300 {
                        if fullHeight && !focused {
                            withAnimation(.app) { fullHeight = false; dragOffset = 0 }   // back to medium
                        } else {
                            close()
                        }
                    } else {
                        withAnimation(.app) { dragOffset = 0 }
                    }
                }
        )
    }

    // MARK: - List

    /// Compact mode: only the newest comment, sized to its content (no scroll view).
    @ViewBuilder
    private var topComment: some View {
        if let comment = store.topLevel(for: story.id).first {
            row(comment, avatar: 36)
                .padding(.horizontal, AppSpacing.m)
                .padding(.bottom, AppSpacing.m)
        } else {
            Text("Lancez la discussion.")
                .typeStyle(.body)
                .foregroundStyle(AppColors.Adaptive.textMeta)
                .frame(maxWidth: .infinity)
                .padding(.bottom, AppSpacing.m)
        }
    }

    private var list: some View {
        let comments = store.topLevel(for: story.id)
        return ScrollView {
            Group {
                if comments.isEmpty {
                    VStack(spacing: AppSpacing.s) {
                        Text("Aucun commentaire")
                            .typeStyle(.ui)
                            .foregroundStyle(AppColors.Adaptive.textPrimary)
                        Text("Lancez la discussion.")
                            .typeStyle(.body)
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
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { listHeight = $0 }
        }
        // Hugs a short list (the medium detent caps a long one); typing opens the large detent.
        .frame(maxHeight: isLarge ? .infinity : listHeight)
        .scrollDismissesKeyboard(.interactively)
        // Scrolling up through the list also snaps the panel to full height.
        .simultaneousGesture(
            DragGesture(minimumDistance: 10).onChanged { value in
                guard !isLarge, value.translation.height < -30 else { return }
                fullHeight = true
            }
        )
    }

    private func row(_ comment: Comment, avatar: CGFloat) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.st) {
            CommentAvatar(author: comment.author, size: avatar)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: AppSpacing.s) {
                    Text(comment.author)
                        .typeStyle(.meta)
                        .foregroundStyle(AppColors.Adaptive.textPrimary)
                    Text(comment.createdAt.relativeToNowFrench())
                        .typeStyle(.meta)
                        .foregroundStyle(AppColors.Adaptive.textMeta)
                }
                Text(comment.text)
                    .typeStyle(.body)
                    .foregroundStyle(AppColors.Adaptive.textPrimary)
                    .multilineTextAlignment(.leading)
                Button("Répondre") {
                    replyingTo = comment.parentID.flatMap { id in store.comments.first { $0.id == id } } ?? comment
                    text = "@\(comment.author) "
                    focused = true
                }
                .typeStyle(.meta)
                .foregroundStyle(AppColors.Adaptive.textMeta)
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                store.toggleLike(comment.id)
            } label: {
                VStack(spacing: 2) {
                    LucideIcon("heart", filled: comment.likedByMe, size: 18)
                        .foregroundStyle(AppColors.Adaptive.textPrimary.opacity(comment.likedByMe ? 1 : 0.62))
                    if comment.likes > 0 {
                        Text("\(comment.likes)")
                            .typeStyle(.meta)
                            .monospacedDigit()
                            .foregroundStyle(AppColors.Adaptive.textMeta)
                    }
                }
                .frame(minWidth: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(comment.likedByMe ? "Retirer le j'aime" : "J'aime")
            .sensoryFeedback(trigger: comment.likedByMe) { _, liked in
                liked ? .impact(weight: .light) : nil
            }
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
                            .typeStyle(.meta)
                            .foregroundStyle(AppColors.Adaptive.textMeta)
                    }
                }
                .buttonStyle(.plain)

                if isOpen {
                    ForEach(replies) { reply in
                        row(reply, avatar: 24)
                            .transition(.identity)
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
                    ForEach(Array(Self.quickEmojis.enumerated()), id: \.offset) { index, emoji in
                        Button { text += emoji } label: {
                            Text(emoji).typeStyle(.section)
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                        .scaleEffect(index < emojisShown ? 1 : 0)
                    }
                }
                .padding(.vertical, AppSpacing.s)
                .padding(.horizontal, AppSpacing.s)
                .transition(.identity)
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
                        .typeStyle(.body)
                        .foregroundStyle(AppColors.Adaptive.textPrimary)
                        .lineLimit(1...4)
                        .focused($focused)
                        .submitLabel(.send)
                        .onSubmit(send)
                    if !text.trimmingCharacters(in: .whitespaces).isEmpty {
                        Button(action: send) {
                            NavIcon("arrow-up", size: 15)
                                .foregroundStyle(AppColors.Brand.onInk)
                                .frame(width: 32, height: 32)
                                .background(AppColors.Brand.accent, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Publier")
                        .transition(.identity)
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
        .overlay(alignment: .top) { Divider().overlay(AppColors.Adaptive.divider) }
    }

    /// Pops the emojis in one by one, 25ms apart, each with the app's easing curve.
    private func playEmojis() {
        guard focused else { return }
        emojiTask?.cancel()
        emojisShown = 0
        emojiTask = Task {
            for count in 1...Self.quickEmojis.count {
                guard !Task.isCancelled else { return }
                withAnimation(.app) { emojisShown = count }
                try? await Task.sleep(for: .milliseconds(25))
            }
        }
    }

    /// Hides them instantly (no animation).
    private func resetEmojis() {
        emojiTask?.cancel()
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) { emojisShown = 0 }
    }

    private func send() {
        store.add(text, to: story.id, replyingTo: replyingTo?.id)
        if let parent = replyingTo { expanded.insert(parent.id) }
        text = ""
        replyingTo = nil
        Haptics.success()
    }
}
