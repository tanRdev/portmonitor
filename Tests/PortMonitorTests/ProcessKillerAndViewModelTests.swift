import Combine
import Foundation
import Testing
@testable import PortMonitor

@MainActor
struct ProcessKillerAndViewModelTests {
    @Test
    func processKillerFallsBackToSIGKILLAfterGenericSIGTERMFailure() async throws {
        let runner = SequencedCommandRunner(results: [
            .success(CommandResult(stdout: "", stderr: "temporary failure", terminationStatus: 1)),
            .success(CommandResult(stdout: "", stderr: "", terminationStatus: 0))
        ])
        let killer = ProcessKiller(commandRunner: runner)

        try await killer.kill(pid: 4321)

        #expect(await runner.calls == [
            CommandCall(launchPath: "/bin/kill", arguments: ["-TERM", "4321"]),
            CommandCall(launchPath: "/bin/kill", arguments: ["-KILL", "4321"])
        ])
    }

    @Test
    func processKillerMapsPermissionDeniedWithoutFallback() async {
        let runner = SequencedCommandRunner(results: [
            .success(CommandResult(stdout: "", stderr: "kill: 999: Operation not permitted", terminationStatus: 1))
        ])
        let killer = ProcessKiller(commandRunner: runner)

        await #expect(throws: KillError.permissionDenied) {
            try await killer.kill(pid: 999)
        }

        #expect(await runner.calls == [
            CommandCall(launchPath: "/bin/kill", arguments: ["-TERM", "999"])
        ])
    }

    @Test
    func processKillerMapsMissingProcessWithoutFallback() async {
        let runner = SequencedCommandRunner(results: [
            .success(CommandResult(stdout: "", stderr: "kill: 123: No such process", terminationStatus: 1))
        ])
        let killer = ProcessKiller(commandRunner: runner)

        await #expect(throws: KillError.processNotFound) {
            try await killer.kill(pid: 123)
        }
    }

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

    @Test(arguments: [
        (KillError.processNotFound, "Process already terminated"),
        (KillError.permissionDenied, "Permission denied to terminate this process"),
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

private struct CommandCall: Equatable, Sendable {
    let launchPath: String
    let arguments: [String]
}

private actor SequencedCommandRunner: CommandRunning {
    private var results: [Result<CommandResult, Error>]
    private(set) var calls: [CommandCall] = []

    init(results: [Result<CommandResult, Error>]) {
        self.results = results
    }

    func run(launchPath: String, arguments: [String]) async throws -> CommandResult {
        calls.append(CommandCall(launchPath: launchPath, arguments: arguments))
        return try results.removeFirst().get()
    }
}

@MainActor
private final class StubScanner: PortScanning {
    let portsSubject = PassthroughSubject<[PortInfo], Never>()
    let errorSubject = PassthroughSubject<PortScannerError, Never>()
    private let refreshError: PortScannerError?

    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var refreshCount = 0

    init(refreshError: PortScannerError? = nil) {
        self.refreshError = refreshError
    }

    var portsPublisher: AnyPublisher<[PortInfo], Never> {
        portsSubject.eraseToAnyPublisher()
    }

    var errorPublisher: AnyPublisher<PortScannerError, Never> {
        errorSubject.eraseToAnyPublisher()
    }

    func startScanning() {
        startCount += 1
    }

    func stopScanning() {
        stopCount += 1
    }

    func refresh() async throws {
        refreshCount += 1

        if let refreshError {
            throw refreshError
        }
    }

    func emitPorts(_ ports: [PortInfo]) {
        portsSubject.send(ports)
    }

    func emitError(_ error: PortScannerError) {
        errorSubject.send(error)
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
}

private actor SuspendedKiller: ProcessKilling {
    private var continuation: CheckedContinuation<Void, Never>?

    func kill(port: PortInfo) async throws {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func resumeSuccessfully() {
        continuation?.resume()
        continuation = nil
    }
}
