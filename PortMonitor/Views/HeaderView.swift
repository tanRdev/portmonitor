import SwiftUI

struct HeaderView: View {
    let portCount: Int
    let onQuit: () -> Void

    @State private var isQuitHovered = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // App icon
            ZStack {
                Group {
                    if let glyph = BrandAssets.glyphImage() {
                        Image(nsImage: glyph)
                            .resizable()
                            .renderingMode(.template)
                            .interpolation(.high)
                    } else {
                        Image(systemName: "square.grid.3x3.fill")
                            .resizable()
                            .scaledToFit()
                    }
                }
                .frame(width: 16, height: 16)
                .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Port Monitor")
                    .font(.system(size: 14, weight: .semibold))

                Text(portCountLabel)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Quit button with improved styling and hit target
            Button(action: onQuit) {
                Image(systemName: "power")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(isQuitHovered ? Color.red.opacity(0.15) : .clear)
                    )
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(isQuitHovered ? .red : .secondary)
            .accessibilityLabel("Quit Port Monitor")
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isQuitHovered = hovering
                }
            }
        }
        .frame(height: 44)
    }

    private var portCountLabel: String {
        portCount == 1 ? "1 port" : "\(portCount) ports"
    }
}
