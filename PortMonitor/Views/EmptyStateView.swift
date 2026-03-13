import SwiftUI

struct EmptyStateView: View {
    let lastUpdatedAt: Date?

    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 16) {
            // Animated illustration
            ZStack {
                Circle()
                    .fill(.white.opacity(0.08))
                    .frame(width: 64, height: 64)

                Image(systemName: "circle.grid.2x2")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.secondary)
                    .symbolRenderingMode(.hierarchical)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
            }

            VStack(spacing: 6) {
                Text("No listening ports")
                    .font(.system(size: 14, weight: .semibold))

                Text("Start a local server and it will appear here automatically.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 240)
            }

            if let lastUpdatedAt {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 10, weight: .medium))

                    Text("Updated \(lastUpdatedAt, style: .time)")
                        .font(.system(size: 11, weight: .regular))
                }
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding(.vertical, 16)
        .onAppear {
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
    }
}
