import SwiftUI

struct HeaderView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Group {
                    if let glyph = BrandAssets.glyphImage() {
                        Image(nsImage: glyph)
                            .resizable()
                            .renderingMode(.template)
                    } else {
                        Image(systemName: "square.grid.3x3.fill")
                            .resizable()
                    }
                }
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(.primary)
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text("Port Monitor")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
