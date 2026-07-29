import SwiftUI

struct FooterView: View {
    @ObservedObject var viewModel: PortListViewModel

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(viewModel.isStale ? Color.orange : Color.green)
                .frame(width: 6, height: 6)
                .accessibilityHidden(true)

            if let lastUpdatedAt = viewModel.lastUpdatedAt {
                Text("Updated \(Self.timeFormatter.string(from: lastUpdatedAt))")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            } else {
                Text("Not updated yet")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Text(verbatim: "\(viewModel.visiblePorts.count) \(viewModel.visiblePorts.count == 1 ? "port" : "ports")")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)

            if viewModel.isRefreshing {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 12, height: 12)
            }

            Menu {
                ForEach(PortSortOrder.allCases, id: \.self) { order in
                    Button {
                        viewModel.setSortOrder(order)
                    } label: {
                        if order == viewModel.sortOrder {
                            Label(order.label, systemImage: "checkmark")
                        } else {
                            Text(order.label)
                        }
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Sort order")

            Button {
                Task { await viewModel.refreshNow() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Refresh now")
            .accessibilityLabel("Refresh now")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
