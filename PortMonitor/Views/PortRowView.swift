import SwiftUI

struct PortRowView: View {
    let port: PortInfo
    let isKilling: Bool
    let onKill: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Text(verbatim: "\(port.port)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .leading)

            Text(port.processName)
                .font(.system(size: 12, weight: .regular))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isKilling {
                HStack(spacing: 4) {
                    ProgressView()
                        .controlSize(.small)

                    Text("Stopping")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.18))
                )
            } else {
                Button("Kill", action: onKill)
                    .buttonStyle(.borderless)
                    .controlSize(.mini)
                    .foregroundStyle(isHovered ? .red : .secondary)
                    .accessibilityLabel("Kill process on port \(port.port)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isHovered ? Color.primary.opacity(0.08) : Color.clear)
        )
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}
