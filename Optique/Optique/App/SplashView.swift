import SwiftUI

struct SplashView: View {

    @State private var scale: CGFloat = 0.82
    @State private var opacity: Double = 1
    @State private var splashOpacity: Double = 1

    var onFinished: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image("AppLogo")
                .resizable()
                .foregroundStyle(.white)
                .scaledToFit()
                .frame(width: 80, height: 80)
                .scaleEffect(scale)
                .opacity(opacity)
        }
        .opacity(splashOpacity)
        .onAppear {
            // Appear
            withAnimation(.app) {
                scale = 1.0
            }
            // Dismiss
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                splashOpacity = 0
                onFinished()
            }
        }
    }
}
