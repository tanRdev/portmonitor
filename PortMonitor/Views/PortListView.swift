import SwiftUI

struct PortListView: View {
    @StateObject private var viewModel = PortListViewModel()
    @State private var isAppeared = false

    var body: some View {
        GlassEffectContainer(spacing: 0) {
            VStack(spacing: 0) {
                // Header
                HeaderView(
                    portCount: viewModel.ports.count,
                    onQuit: viewModel.quitApp
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider()
                    .opacity(0.3)

                // Content area
                contentView
                    .padding(12)
            }
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .frame(width: 340)
        .opacity(isAppeared ? 1 : 0)
        .scaleEffect(isAppeared ? 1 : 0.96)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isAppeared)
        .onAppear {
            viewModel.startScanning()
            isAppeared = true
        }
        .onDisappear {
            viewModel.stopScanning()
            isAppeared = false
        }
    }

    @ViewBuilder
    private var contentView: some View {
        VStack(spacing: 8) {
            if let errorMessage = viewModel.errorMessage {
                ErrorBannerView(message: errorMessage)
            }

            if viewModel.isLoading && viewModel.ports.isEmpty {
                LoadingStateView()
            } else if viewModel.ports.isEmpty {
                EmptyStateView(lastUpdatedAt: viewModel.lastUpdatedAt)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(viewModel.ports) { port in
                            PortRowView(
                                port: port,
                                isKilling: viewModel.killingPortId == port.id,
                                onKill: {
                                    Task {
                                        await viewModel.killPort(port)
                                    }
                                }
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 280)
            }
        }
    }
}
