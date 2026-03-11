import SwiftUI

struct PortListView: View {
    @StateObject private var viewModel = PortListViewModel()

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            VStack(spacing: 10) {
                HeaderView(
                    portCount: viewModel.ports.count,
                    onQuit: viewModel.quitApp
                )

                if let errorMessage = viewModel.errorMessage {
                    ErrorBannerView(message: errorMessage)
                }

                if viewModel.isLoading && viewModel.ports.isEmpty {
                    LoadingStateView()
                } else if viewModel.ports.isEmpty {
                    EmptyStateView(lastUpdatedAt: viewModel.lastUpdatedAt)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 4) {
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
                        .padding(.vertical, 1)
                    }
                    .frame(maxHeight: 300)
                }
            }
            .padding(12)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .frame(width: 332)
        .onAppear {
            viewModel.startScanning()
        }
        .onDisappear {
            viewModel.stopScanning()
        }
    }
}
