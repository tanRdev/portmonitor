import SwiftUI

struct HeaderView: View {
    let portCount: Int
    let onQuit: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
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
            .frame(width: 14, height: 14)
            .foregroundStyle(.white)
            .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Port Monitor")
                        .font(.system(size: 13, weight: .medium))

                    Text(portCountLabel)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button(action: onQuit) {
                Image(systemName: "power")
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Quit Port Monitor")
        }
    }

    private var portCountLabel: String {
        portCount == 1 ? "1 port" : "\(portCount) ports"
    }
}
