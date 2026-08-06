import SwiftUI

struct PortListView: View {
    @StateObject private var viewModel: PortListViewModel
    @State private var isAppeared = false
    @FocusState private var isFilterFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(viewModel: PortListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        GlassEffectContainer {
            VStack(spacing: 0) {
                HeaderView()

                Divider()
                    .opacity(0.3)

                filterField
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)

                if let errorMessage = viewModel.errorMessage {
                    ErrorBannerView(
                        message: errorMessage,
                        canForceKill: viewModel.failedKillPort != nil,
                        onRetry: { Task { await viewModel.refreshNow() } },
                        onForceKill: { Task { await viewModel.forceKillFailedPort() } },
                        onDismiss: { viewModel.dismissError() }
                    )
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                content
                    .padding(.bottom, 12)

                Divider()
                    .opacity(0.3)

                FooterView(viewModel: viewModel)
            }
            .frame(width: 340)
            .glassEffect(.regular, in: .rect(cornerRadius: 20))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .scaleEffect(isAppeared ? 1 : 0.95)
        .opacity(isAppeared ? 1 : 0)
        .onAppear {
            appear()
        }
        .onReceive(NotificationCenter.default.publisher(for: .portMonitorPanelWillShow)) { _ in
            isFilterFocused = true
            if isAppeared { return }
            appear()
        }
        .onExitCommand {
            if viewModel.filterText.isEmpty {
                viewModel.closePanel()
            } else {
                viewModel.filterText = ""
            }
        }
    }

    private var filterField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)

            TextField("Filter by port or process", text: $viewModel.filterText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .focused($isFilterFocused)

            if !viewModel.filterText.isEmpty {
                Button {
                    viewModel.filterText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear filter")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            LoadingStateView()
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        } else if viewModel.visiblePorts.isEmpty {
            if viewModel.filterText.isEmpty {
                EmptyStateView()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                noMatchesState
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        } else {
            listView
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        }
    }

    private var noMatchesState: some View {
        Text("No ports match \"\(viewModel.filterText)\"")
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .accessibilityLabel("No ports match the current filter")
    }

    private var listView: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(viewModel.visiblePorts) { port in
                    PortRowView(
                        port: port,
                        isKilling: viewModel.killingPortId == port.id,
                        onKill: { Task { await viewModel.killPort(port) } }
                    )
                }
            }
            .padding(.horizontal, 12)
        }
        .frame(maxHeight: 240)
        .opacity(viewModel.isStale ? 0.5 : 1)
        .animation(.easeOut(duration: 0.2), value: viewModel.isStale)
    }

    private func appear() {
        withAnimation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.85)) {
            isAppeared = true
        }
    }
}
