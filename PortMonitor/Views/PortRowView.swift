import SwiftUI

struct PortRowView: View {
    let port: PortInfo
    let isKilling: Bool
    let onKill: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        HStack(spacing: 12) {
            // Port number with icon
            HStack(spacing: 6) {
                Image(systemName: "number")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.tertiary)

                Text(verbatim: "\(port.port)")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 56, alignment: .leading)

            // Process name with icon
            HStack(spacing: 6) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)

                Text(port.processName)
                    .font(.system(size: 13, weight: .regular))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Kill button or loading state
            if isKilling {
                StoppingBadge()
            } else {
                KillButton(isHovered: isHovered, onKill: onKill)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Slightly reduce vertical padding to meet compact menu bar row height
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isHovered ? Color.primary.opacity(0.06) : Color.clear)
        )
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isHovered ? Color.primary.opacity(0.1) : Color.clear, lineWidth: 0.5)
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .scaleEffect(isPressed ? 0.995 : 1.0)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Kill Button

private struct KillButton: View {
    let isHovered: Bool
    let onKill: () -> Void

    var body: some View {
        Button(action: onKill) {
            HStack(spacing: 4) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 10, weight: .semibold))
                Text("Kill")
                    .font(.system(size: 11, weight: .semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(isHovered ? Color.red.opacity(0.12) : Color.primary.opacity(0.06))
            )
            .foregroundStyle(isHovered ? .red : .secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Kill process")
    }
}

// MARK: - Stopping Badge

private struct StoppingBadge: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 6) {
            ProgressView()
                .controlSize(.small)
                .scaleEffect(0.7)

            Text("Stopping")
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(Color.orange.opacity(0.12))
        )
    }
}
