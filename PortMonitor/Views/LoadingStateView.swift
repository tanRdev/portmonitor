import SwiftUI

struct LoadingStateView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 8) {
            if reduceMotion {
                Image(systemName: "circle.grid.2x2")
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "circle.grid.2x2")
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(.secondary)
                    .symbolEffect(.pulse, options: .repeat(.continuous))
            }

            Text("Scanning ports…")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Scanning ports")
    }
}
