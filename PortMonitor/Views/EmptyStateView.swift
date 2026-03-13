import SwiftUI

struct EmptyStateView: View {
    let lastUpdatedAt: Date?

    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 12) {
            // Animated illustration
            ZStack {
                Circle()
                    .fill(.white.opacity(0.08))
                    .frame(width: 56, height: 56)

                Image(systemName: "circle.grid.2x2")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.secondary)
                    .symbolRenderingMode(.hierarchical)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
            }

            VStack(spacing: 6) {
                Text("No listening ports")
                    .font(.system(size: 13, weight: .semibold))

                Text("Start a local server and it will appear here automatically.")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 220)
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
        // Keep the empty state compact for menu bar utility use
        .frame(maxWidth: .infinity, minHeight: 84)
        .padding(.vertical, 8)
        .onAppear {
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
    }
}
