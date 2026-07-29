import SwiftUI

struct PortRowView: View {
    let port: PortInfo
    let isKilling: Bool
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "network")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tint)
                    .frame(width: 14)

                Text(verbatim: "\(port.port)")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.primary)
            }
            .frame(width: 68, alignment: .leading)

            Text(port.processName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(port.processName)

            Spacer()

            Text(verbatim: "\(port.pid)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 44, alignment: .trailing)
                .accessibilityLabel("PID \(port.pid)")

            Group {
                if isKilling {
                    StoppingBadge()
                } else {
                    KillButton(port: port)
                }
            }
            .opacity(isKilling || isHovered ? 1 : 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isHovered ? Color.primary.opacity(0.06) : .clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            Button("Copy Port") {
                PortCopyCommands.copyPort(port)
            }
            Button("Copy PID") {
                PortCopyCommands.copyPID(port)
            }
            Button("Copy Process Name") {
                PortCopyCommands.copyProcessName(port)
            }
            Divider()
            Button("Copy lsof Command") {
                PortCopyCommands.copyLsofCommand(port)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Port \(port.port), \(port.processName), PID \(port.pid)")
    }
}

private struct KillButton: View {
    let port: PortInfo

    var body: some View {
        Text("Kill")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.red.opacity(0.85))
            )
            .accessibilityLabel("Kill \(port.processName) on port \(port.port)")
    }
}

private struct StoppingBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            ProgressView()
                .scaleEffect(0.5)
                .frame(width: 10, height: 10)

            Text("Stopping")
                .font(.system(size: 10, weight: .semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(.orange.opacity(0.15))
        )
        .foregroundStyle(.orange)
        .accessibilityLabel("Stopping process")
    }
}
