import SwiftUI

struct SplashView: View {

    @State private var scale: CGFloat = 0.82
    @State private var opacity: Double = 0
    @State private var splashOpacity: Double = 1

    var onFinished: () -> Void

    var body: some View {
        ZStack {
            AppColors.Neutral.n950.ignoresSafeArea()

            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .scaleEffect(scale)
                .opacity(opacity)
        }
        .opacity(splashOpacity)
        .onAppear {
            // Appear
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }
            // Dismiss
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                withAnimation(.easeIn(duration: 0.3)) {
                    splashOpacity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onFinished()
                }
            }
        }
    }
}
