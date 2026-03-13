import SwiftUI

struct LoadingStateView: View {
    @State private var isPulsing = false
    @State private var rotationAngle: Double = 0

    var body: some View {
        VStack(spacing: 12) {
            // Animated radar/scanning effect
            ZStack {
                // Outer ring
                Circle()
                    .stroke(.secondary.opacity(0.2), lineWidth: 2)
                    .frame(width: 48, height: 48)

                // Pulsing inner circle
                Circle()
                    .fill(.secondary.opacity(0.1))
                    .frame(width: 34, height: 34)
                    .scaleEffect(isPulsing ? 1.08 : 0.94)
                    .opacity(isPulsing ? 0.6 : 1)

                // Scanning line
                RoundedRectangle(cornerRadius: 1)
                    .fill(.secondary.opacity(0.5))
                    .frame(width: 2, height: 18)
                    .offset(y: -9)
                    .rotationEffect(.degrees(rotationAngle))

                // Center dot
                Circle()
                    .fill(.secondary)
                    .frame(width: 8, height: 8)
            }

            VStack(spacing: 6) {
                Text("Scanning ports…")
                    .font(.system(size: 13, weight: .semibold))

                Text("Listening ports will appear automatically")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 220)
            }
        }
        // Keep the loading state compact for menu bar utility use
        .frame(maxWidth: .infinity, minHeight: 76)
        .padding(.vertical, 8)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
        }
    }
}
