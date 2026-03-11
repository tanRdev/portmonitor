import SwiftUI

struct EmptyStateView: View {
    let lastUpdatedAt: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("No listening ports right now", systemImage: "circle.grid.2x2")
                .font(.system(size: 12, weight: .medium))

            Text("Start a local server and it will appear here automatically.")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.secondary)

            if let lastUpdatedAt {
                Text("Last scan \(lastUpdatedAt, style: .time)")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .padding(.vertical, 10)
    }
}
