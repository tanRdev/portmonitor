import SwiftUI

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(.primary.opacity(0.06))
                    .frame(width: 48, height: 48)

                Image(systemName: "checkmark.circle")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(.secondary)
            }

            Text("All quiet")
                .font(.system(size: 13, weight: .medium))

            Text("No listening TCP ports detected")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No listening TCP ports detected")
    }
}
