import SwiftUI

struct ErrorBannerView: View {
    let message: String

    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.orange)

            Text(message)
                .font(.system(size: 12, weight: .medium))

            Spacer()
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.orange.opacity(0.1))
        )
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
        .opacity(isAnimating ? 1 : 0.9)
        .offset(y: isAnimating ? 0 : -2)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                isAnimating = true
            }
        }
    }
}
