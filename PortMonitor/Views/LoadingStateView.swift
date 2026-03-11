import SwiftUI

struct LoadingStateView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)

                Text("Scanning local ports…")
                    .font(.system(size: 12, weight: .medium))
            }

            Text("Listening ports will appear here automatically.")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
        .padding(.vertical, 10)
    }
}
