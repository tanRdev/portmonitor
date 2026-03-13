import SwiftUI

struct LoadingStateView: View {
    @State private var isPulsing = false
    @State private var rotationAngle: Double = 0

    var body: some View {
        VStack(spacing: 16) {
            // Animated radar/scanning effect
            ZStack {
                // Outer ring
                Circle()
                    .stroke(.secondary.opacity(0.2), lineWidth: 2)
                    .frame(width: 56, height: 56)

                // Pulsing inner circle
                Circle()
                    .fill(.secondary.opacity(0.1))
                    .frame(width: 40, height: 40)
                    .scaleEffect(isPulsing ? 1.1 : 0.9)
                    .opacity(isPulsing ? 0.6 : 1)

                // Scanning line
                RoundedRectangle(cornerRadius: 1)
                    .fill(.secondary.opacity(0.5))
                    .frame(width: 2, height: 20)
                    .offset(y: -10)
                    .rotationEffect(.degrees(rotationAngle))

                // Center dot
                Circle()
                    .fill(.secondary)
                    .frame(width: 8, height: 8)
            }

            VStack(spacing: 6) {
                Text("Scanning ports…")
                    .font(.system(size: 14, weight: .semibold))

                Text("Listening ports will appear automatically")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 240)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding(.vertical, 16)
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
