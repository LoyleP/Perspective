import SwiftUI
import WebKit

struct ArticleBrowserView: View {

    let articles: [Article]
    let initialArticle: Article
    @Environment(\.dismiss) private var dismiss

    @State private var currentIndex: Int
    @State private var webView = WKWebView()
    @State private var isLoading = true
    @State private var barsVisible = true

    init(articles: [Article], initialArticle: Article) {
        self.articles = articles
        self.initialArticle = initialArticle
        _currentIndex = State(initialValue: articles.firstIndex(where: { $0.id == initialArticle.id }) ?? 0)
    }

    private var currentArticle: Article {
        articles[currentIndex]
    }

    private var canGoBack: Bool {
        currentIndex > 0
    }

    private var canGoForward: Bool {
        currentIndex < articles.count - 1
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if let url = URL(string: currentArticle.url) {
                    WebViewRepresentable(
                        webView: webView,
                        url: url,
                        isLoading: $isLoading,
                        barsVisible: $barsVisible
                    )
                    .background(AppColors.Adaptive.background)
                    .id(currentArticle.id)
                }

                if isLoading {
                    ProgressView()
                        .tint(AppColors.Adaptive.textPrimary)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(barsVisible ? .visible : .hidden, for: .navigationBar, .bottomBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    if let source = currentArticle.source,
                       let logoURL = source.logoURL,
                       let url = URL(string: logoURL) {
                        AsyncImage(url: url) { phase in
                            if let img = phase.image {
                                img.resizable()
                                    .scaledToFill()
                                    .frame(width: 48, height: 48)
                                    .clipShape(Circle())
                            } else {
                                sourceLogoPlaceholder(source)
                            }
                        }
                    } else if let source = currentArticle.source {
                        sourceLogoPlaceholder(source)
                    }
                }

                ToolbarItemGroup(placement: .bottomBar) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.appBody)
                            .foregroundStyle(AppColors.Adaptive.textPrimary)
                    }

                    Spacer()

                    Button {
                        if canGoBack {
                            currentIndex -= 1
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.appBody)
                            .foregroundStyle(canGoBack ? AppColors.Adaptive.textPrimary : AppColors.Adaptive.textTertiary)
                    }
                    .disabled(!canGoBack)

                    Button {
                        if canGoForward {
                            currentIndex += 1
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.appBody)
                            .foregroundStyle(canGoForward ? AppColors.Adaptive.textPrimary : AppColors.Adaptive.textTertiary)
                    }
                    .disabled(!canGoForward)
                }
            }
            .toolbarBackground(.visible, for: .bottomBar)
            .toolbarBackground(AppColors.Adaptive.background, for: .bottomBar)
        }
    }

    private func sourceAvatar(_ source: Source) -> some View {
        Group {
            if let logoURL = source.logoURL, let url = URL(string: logoURL) {
                AsyncImage(url: url) { phase in
                    if let img = phase.image {
                        Color.clear.overlay(img.resizable().scaledToFill()).clipped()
                    } else {
                        sourceInitial(source)
                    }
                }
            } else {
                sourceInitial(source)
            }
        }
        .frame(width: 28, height: 28)
        .clipShape(Circle())
        .overlay(Circle().stroke(AppColors.stroke, lineWidth: 1))
    }

    private func sourceInitial(_ source: Source) -> some View {
        let lean = source.lean
        return ZStack {
            Circle().fill(lean?.spectrumColor ?? AppColors.Adaptive.placeholder)
            Text(String(source.name.prefix(1)).uppercased())
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(lean?.tagTextColor ?? AppColors.Adaptive.textSecondary)
        }
    }

    private func sourceLogoPlaceholder(_ source: Source) -> some View {
        let lean = source.lean
        return ZStack {
            Circle()
                .fill(lean?.spectrumColor ?? AppColors.Adaptive.placeholder)
            Text(String(source.name.prefix(1)).uppercased())
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(lean?.tagTextColor ?? AppColors.Adaptive.textSecondary)
        }
        .frame(width: 48, height: 48)
    }
}

struct WebViewRepresentable: UIViewRepresentable {

    let webView: WKWebView
    let url: URL
    @Binding var isLoading: Bool
    @Binding var barsVisible: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading, barsVisible: $barsVisible)
    }

    func makeUIView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        webView.scrollView.delegate = context.coordinator

        // Enforce HTTPS for security (App Store compliance)
        guard url.scheme == "https" else {
            print("⚠️ Blocked non-HTTPS URL: \(url)")
            return webView
        }

        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // No updates needed
    }

    class Coordinator: NSObject, WKNavigationDelegate, UIScrollViewDelegate {
        @Binding var isLoading: Bool
        @Binding var barsVisible: Bool
        private var lastContentOffset: CGFloat = 0

        init(isLoading: Binding<Bool>, barsVisible: Binding<Bool>) {
            _isLoading = isLoading
            _barsVisible = barsVisible
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading = false
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            isLoading = false
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let currentOffset = scrollView.contentOffset.y
            let threshold: CGFloat = 50

            if currentOffset > lastContentOffset && currentOffset > threshold {
                if barsVisible {
                    withAnimation(.easeOut(duration: 0.2)) {
                        barsVisible = false
                    }
                }
            } else if currentOffset < lastContentOffset {
                if !barsVisible {
                    withAnimation(.easeOut(duration: 0.2)) {
                        barsVisible = true
                    }
                }
            }

            lastContentOffset = currentOffset
        }
    }
}
