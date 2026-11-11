import SwiftUI

/// Shared state between a row of pills and the pages under it: the pills' height (so pages leave room
/// for them) and how far the current page has scrolled (so the pills leave with the content).
@MainActor @Observable
final class PillsScroll {
    var y: CGFloat = 0
    var height: CGFloat = 0
}

/// Pills pinned to the top of paging content that scroll away with it instead of staying stuck.
struct ScrollAwayPills<Pills: View, Pages: View>: View {
    let model: PillsScroll
    @ViewBuilder let pills: Pills
    @ViewBuilder let pages: Pages

    init(model: PillsScroll, @ViewBuilder pills: () -> Pills, @ViewBuilder pages: () -> Pages) {
        self.model = model
        self.pills = pills()
        self.pages = pages()
    }

    var body: some View {
        ZStack(alignment: .top) {
            pages
            PillsLayer { pills }
        }
        .environment(model)
    }
}

private struct PillsLayer<Content: View>: View {
    @Environment(PillsScroll.self) private var model
    @ViewBuilder let content: Content

    private var scrolled: CGFloat { min(max(model.y, 0), model.height) }

    var body: some View {
        content
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { model.height = $0 }
            .offset(y: -scrolled)
            // Gone by the time they reach the header, which is translucent and would show them through.
            .opacity(model.height > 0 ? 1 - Double(min(scrolled / (model.height * 0.6), 1)) : 1)
            .allowsHitTesting(scrolled < model.height * 0.5)
    }
}

/// Where the horizontal pages are, in pages. A reference the pills read on their own, so a swipe redraws the pills
/// each frame and not the whole feed.
@Observable
final class PageProgress {
    var value: CGFloat?
}

extension View {
    /// Put on each page's vertical ScrollView: leaves room for the pills and reports the scroll while current.
    func scrollsAwayPills(isCurrent: Bool) -> some View {
        modifier(ScrollAwayPillsPage(isCurrent: isCurrent))
    }

    /// Reports the horizontal scroll position in pages (iOS 18+; before that nothing is reported and the pill
    /// follows the selection).
    @ViewBuilder
    func trackingPageProgress(_ update: @escaping (CGFloat) -> Void) -> some View {
        if #available(iOS 18.0, *) {
            onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.x / max($0.containerSize.width, 1) } action: { _, progress in
                update(progress)
            }
        } else {
            self
        }
    }
}

private struct ScrollAwayPillsPage: ViewModifier {
    @Environment(PillsScroll.self) private var model
    let isCurrent: Bool
    @State private var y: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .contentMargins(.top, model.height, for: .scrollContent)
            .trackingScrollY { value in
                y = value
                if isCurrent { model.y = value }
            }
            .onChange(of: isCurrent) { _, now in
                if now { model.y = y }
            }
    }
}

extension View {
    /// Reports how far this vertical scroll view has scrolled (iOS 18+), e.g. to fade the header logo.
    func reportsScroll(to model: PillsScroll) -> some View {
        trackingScrollY { model.y = $0 }
    }

    @ViewBuilder
    func trackingScrollY(_ update: @escaping (CGFloat) -> Void) -> some View {
        if #available(iOS 18.0, *) {
            onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y + $0.contentInsets.top } action: { _, value in
                update(value)
            }
        } else {
            self
        }
    }
}
