import Combine
import Foundation
import Testing
@testable import PortMonitor

@MainActor
struct ProcessKillerAndViewModelTests {
    @Test
    func viewModelStartsScanningAndClearsLoadingWhenPortsArrive() {
        let scanner = StubScanner()
        let killer = SpyKiller()
        let viewModel = PortListViewModel(scanner: scanner, killer: killer, terminateApp: {})

        viewModel.startScanning()

        #expect(viewModel.isLoading)
        #expect(scanner.startCount == 1)

        let port = PortInfo(port: 3000, processName: "node", pid: 101, protocolType: "TCP")
        scanner.emitPorts([port])

        #expect(viewModel.isLoading == false)
        #expect(viewModel.ports == [port])
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.lastUpdatedAt != nil)
    }

    @Test
    func viewModelShowsScannerErrors() {
        let scanner = StubScanner()
        let killer = SpyKiller()
        let viewModel = PortListViewModel(scanner: scanner, killer: killer, terminateApp: {})

        viewModel.startScanning()
        scanner.emitError(.commandFailed(status: 1, message: "permission denied"))

        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == "Unable to scan ports: permission denied")
    }

    @Test
    func viewModelTracksKillStateAndRefreshesScannerAfterSuccess() async {
        let scanner = StubScanner()
        let killer = SuspendedKiller()
        let viewModel = PortListViewModel(scanner: scanner, killer: killer, terminateApp: {})
        let port = PortInfo(port: 5173, processName: "vite", pid: 202, protocolType: "TCP")

        let task = Task {
            await viewModel.killPort(port)
        }
        await Task.yield()

        #expect(viewModel.killingPortId == port.id)

        await killer.resumeSuccessfully()
        await task.value

        #expect(viewModel.killingPortId == nil)
        #expect(scanner.refreshCount == 1)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func viewModelShowsRefreshErrorAfterSuccessfulKill() async {
        let scanner = StubScanner(refreshError: .commandFailed(status: 2, message: "refresh failed"))
        let killer = SpyKiller()
        let viewModel = PortListViewModel(scanner: scanner, killer: killer, terminateApp: {})
        let port = PortInfo(port: 5173, processName: "vite", pid: 202, protocolType: "TCP")

        await viewModel.killPort(port)

        #expect(viewModel.killingPortId == nil)
        #expect(scanner.refreshCount == 1)
        #expect(viewModel.errorMessage == "Unable to scan ports: refresh failed")
    }

    @Test
    func viewModelNeverMasksSuccessfulKillAsFailureWhenRefreshThrowsUnexpectedError() async {
        struct UnexpectedRefreshError: Error {}

        let scanner = StubScanner(untypedRefreshError: UnexpectedRefreshError())
        let killer = SpyKiller()
        let viewModel = PortListViewModel(scanner: scanner, killer: killer, terminateApp: {})
        let port = PortInfo(port: 5173, processName: "vite", pid: 202, protocolType: "TCP")

        await viewModel.killPort(port)

        #expect(viewModel.killingPortId == nil)
        #expect(viewModel.failedKillPort == nil)
        #expect(viewModel.errorMessage?.hasPrefix("Failed to kill process") == false)
    }

    @Test
    func viewModelClearsFailedKillWhenForceKillSucceedsButRefreshThrowsUnexpectedError() async {
        struct UnexpectedRefreshError: Error {}

        let scanner = StubScanner(untypedRefreshError: UnexpectedRefreshError())
        let killer = RecordingKiller(killError: KillError.killFailed("boom"))
        let viewModel = PortListViewModel(scanner: scanner, killer: killer, terminateApp: {})
        let port = PortInfo(port: 5173, processName: "vite", pid: 202, protocolType: "TCP")

        await viewModel.killPort(port)
        #expect(viewModel.failedKillPort == port)

        await viewModel.forceKillFailedPort()

        #expect(viewModel.failedKillPort == nil)
        #expect(viewModel.errorMessage?.hasPrefix("Failed to kill process") == false)
    }

    @Test(arguments: [
        (KillError.processNotFound, "Process already terminated"),
        (KillError.permissionDenied, "Permission denied to terminate this process"),
        (KillError.processIdentityChanged(expected: "node", found: "Code"),
         "PID now belongs to Code, not node. Refresh and try again."),
        (KillError.policyRefused("owned by another user"), "owned by another user"),
        (KillError.killFailed("boom"), "Failed to kill process: boom")
    ])
    func viewModelMapsKillFailuresToMessages(error: KillError, message: String) async {
        let scanner = StubScanner()
        let killer = SpyKiller(error: error)
        let viewModel = PortListViewModel(scanner: scanner, killer: killer, terminateApp: {})
        let port = PortInfo(port: 8080, processName: "server", pid: 303, protocolType: "TCP")

        await viewModel.killPort(port)

        #expect(viewModel.killingPortId == nil)
        #expect(viewModel.errorMessage == message)
    }

    @Test(arguments: [
        KillError.processNotFound,
        KillError.permissionDenied,
        KillError.processIdentityChanged(expected: "node", found: "Code"),
        KillError.policyRefused("owned by another user")
    ])
    func viewModelNeverOffersForceKillForPolicyOrIdentityFailures(error: KillError) async {
        let scanner = StubScanner()
        let killer = SpyKiller(error: error)
        let viewModel = PortListViewModel(scanner: scanner, killer: killer, terminateApp: {})
        let port = PortInfo(port: 8080, processName: "server", pid: 303, protocolType: "TCP")

        await viewModel.killPort(port)

        #expect(viewModel.failedKillPort == nil)
    }

    @Test
    func viewModelOffersExplicitForceKillAfterGenericKillFailure() async {
        let scanner = StubScanner()
        let killer = SpyKiller(error: KillError.killFailed("Input/output error"))
        let viewModel = PortListViewModel(scanner: scanner, killer: killer, terminateApp: {})
        let port = PortInfo(port: 8080, processName: "server", pid: 303, protocolType: "TCP")

        await viewModel.killPort(port)

        #expect(viewModel.failedKillPort == port)
    }

    @Test
    func viewModelQuitAppInvokesInjectedTerminator() {
        let scanner = StubScanner()
        let killer = SpyKiller()
        var quitCount = 0
        let viewModel = PortListViewModel(scanner: scanner, killer: killer) {
            quitCount += 1
        }

        viewModel.quitApp()

        #expect(quitCount == 1)
    }
}

private actor SpyKiller: ProcessKilling {
    private let error: Error?

    init(error: Error? = nil) {
        self.error = error
    }

    func kill(port: PortInfo) async throws {
        if let error {
            throw error
        }
    }

    func forceKill(port: PortInfo) async throws {
        if let error {
            throw error
        }
    }
}

private actor SuspendedKiller: ProcessKilling {
    private var continuation: CheckedContinuation<Void, Never>?

    func kill(port: PortInfo) async throws {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func forceKill(port: PortInfo) async throws {}

    func resumeSuccessfully() {
        continuation?.resume()
        continuation = nil
    }
}
