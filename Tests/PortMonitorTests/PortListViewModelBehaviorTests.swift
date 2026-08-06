import Combine
import Foundation
import Testing
@testable import PortMonitor

@MainActor
struct PortListViewModelBehaviorTests {
    private func makeViewModel(
        scanner: StubScanner = StubScanner(),
        killer: RecordingKiller = RecordingKiller(),
        defaults: UserDefaults
    ) -> PortListViewModel {
        PortListViewModel(scanner: scanner, killer: killer, terminateApp: {}, defaults: defaults)
    }

    private func makeIsolatedDefaults() -> UserDefaults {
        let suiteName = "PortListViewModelBehaviorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    // MARK: - Filtering

    @Test
    func filtersPortsByPortNumberSubstring() {
        let viewModel = makeViewModel(defaults: makeIsolatedDefaults())
        let node = PortInfo(port: 3000, processName: "node", pid: 101, protocolType: "TCP")
        let postgres = PortInfo(port: 5432, processName: "postgres", pid: 102, protocolType: "TCP")
        viewModel.ports = [node, postgres]

        viewModel.filterText = "300"

        #expect(viewModel.visiblePorts == [node])
    }

    @Test
    func filtersPortsByProcessNameCaseInsensitively() {
        let viewModel = makeViewModel(defaults: makeIsolatedDefaults())
        let node = PortInfo(port: 3000, processName: "node", pid: 101, protocolType: "TCP")
        let postgres = PortInfo(port: 5432, processName: "Postgres", pid: 102, protocolType: "TCP")
        viewModel.ports = [node, postgres]

        viewModel.filterText = "postgres"

        #expect(viewModel.visiblePorts == [postgres])
    }

    @Test
    func emptyFilterShowsAllPorts() {
        let viewModel = makeViewModel(defaults: makeIsolatedDefaults())
        let node = PortInfo(port: 3000, processName: "node", pid: 101, protocolType: "TCP")
        viewModel.ports = [node]

        viewModel.filterText = ""

        #expect(viewModel.visiblePorts == [node])
    }

    // MARK: - Sorting

    @Test
    func sortsByProcessNameWithPortTiebreak() {
        let viewModel = makeViewModel(defaults: makeIsolatedDefaults())
        let node = PortInfo(port: 3000, processName: "node", pid: 101, protocolType: "TCP")
        let codeA = PortInfo(port: 8080, processName: "Code", pid: 102, protocolType: "TCP")
        let codeB = PortInfo(port: 8081, processName: "Code", pid: 103, protocolType: "TCP")
        viewModel.ports = [codeB, node, codeA]

        viewModel.setSortOrder(.byProcess)

        #expect(viewModel.visiblePorts == [codeA, codeB, node])
    }

    @Test
    func sortOrderPersistsAcrossLaunches() {
        let defaults = makeIsolatedDefaults()
        let viewModel = makeViewModel(defaults: defaults)

        viewModel.setSortOrder(.byProcess)

        let reloaded = makeViewModel(defaults: defaults)
        #expect(reloaded.sortOrder == .byProcess)
    }

    // MARK: - Stale state

    @Test
    func marksListStaleWhenScanFailsWithExistingPorts() {
        let scanner = StubScanner()
        let viewModel = makeViewModel(scanner: scanner, defaults: makeIsolatedDefaults())
        scanner.emitPorts([PortInfo(port: 3000, processName: "node", pid: 101, protocolType: "TCP")])

        scanner.emitError(.commandFailed(status: 1, message: "boom"))

        #expect(viewModel.isStale)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.ports.isEmpty == false)
    }

    @Test
    func clearsStaleAndErrorWhenFreshPortsArrive() {
        let scanner = StubScanner()
        let viewModel = makeViewModel(scanner: scanner, defaults: makeIsolatedDefaults())
        scanner.emitPorts([PortInfo(port: 3000, processName: "node", pid: 101, protocolType: "TCP")])
        scanner.emitError(.commandFailed(status: 1, message: "boom"))

        scanner.emitPorts([PortInfo(port: 3000, processName: "node", pid: 101, protocolType: "TCP")])

        #expect(viewModel.isStale == false)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func dismissErrorClearsMessageButKeepsStaleFlag() {
        let scanner = StubScanner()
        let viewModel = makeViewModel(scanner: scanner, defaults: makeIsolatedDefaults())
        scanner.emitPorts([PortInfo(port: 3000, processName: "node", pid: 101, protocolType: "TCP")])
        scanner.emitError(.commandFailed(status: 1, message: "boom"))

        viewModel.dismissError()

        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.isStale)
    }

    // MARK: - Manual refresh

    @Test
    func refreshNowRefreshesScannerAndSurfacesFailures() async {
        let scanner = StubScanner(refreshError: .commandFailed(status: 2, message: "nope"))
        let viewModel = makeViewModel(scanner: scanner, defaults: makeIsolatedDefaults())

        await viewModel.refreshNow()

        #expect(scanner.refreshCount == 1)
        #expect(viewModel.errorMessage == "Unable to scan ports: nope")
        #expect(viewModel.isRefreshing == false)
    }

    // MARK: - Force kill

    @Test
    func offersForceKillAfterGenericKillFailure() async {
        let killer = RecordingKiller(killError: KillError.killFailed("still running"))
        let viewModel = makeViewModel(killer: killer, defaults: makeIsolatedDefaults())
        let port = PortInfo(port: 8080, processName: "server", pid: 303, protocolType: "TCP")

        await viewModel.killPort(port)

        #expect(viewModel.failedKillPort == port)
    }

    @Test
    func doesNotOfferForceKillWhenProcessAlreadyGone() async {
        let killer = RecordingKiller(killError: KillError.processNotFound)
        let viewModel = makeViewModel(killer: killer, defaults: makeIsolatedDefaults())
        let port = PortInfo(port: 8080, processName: "server", pid: 303, protocolType: "TCP")

        await viewModel.killPort(port)

        #expect(viewModel.failedKillPort == nil)
    }

    @Test
    func forceKillUsesSIGKILLAndClearsFailureState() async {
        let killer = RecordingKiller(killError: KillError.killFailed("still running"))
        let scanner = StubScanner()
        let viewModel = makeViewModel(scanner: scanner, killer: killer, defaults: makeIsolatedDefaults())
        let port = PortInfo(port: 8080, processName: "server", pid: 303, protocolType: "TCP")
        await viewModel.killPort(port)

        await viewModel.forceKillFailedPort()

        #expect(await killer.forceKilledPids == [303])
        #expect(viewModel.failedKillPort == nil)
        #expect(scanner.refreshCount == 1)
    }

    @Test
    func forceKillFailureKeepsFailureStateAndShowsMessage() async {
        let killer = RecordingKiller(
            killError: KillError.killFailed("still running"),
            forceKillError: KillError.killFailed("nope")
        )
        let viewModel = makeViewModel(killer: killer, defaults: makeIsolatedDefaults())
        let port = PortInfo(port: 8080, processName: "server", pid: 303, protocolType: "TCP")
        await viewModel.killPort(port)

        await viewModel.forceKillFailedPort()

        #expect(viewModel.failedKillPort == port)
        #expect(viewModel.errorMessage == "Failed to kill process: nope")
    }

    // MARK: - Refresh interval

    @Test
    func setRefreshIntervalForwardsToScannerAndPersists() {
        let defaults = makeIsolatedDefaults()
        let scanner = StubScanner()
        let viewModel = makeViewModel(scanner: scanner, defaults: defaults)

        viewModel.setRefreshInterval(10)

        #expect(scanner.recordedInterval == 10)
        #expect(viewModel.refreshInterval == 10)

        let reloadedScanner = StubScanner()
        let reloaded = makeViewModel(scanner: reloadedScanner, defaults: defaults)
        #expect(reloaded.refreshInterval == 10)
        #expect(reloadedScanner.recordedInterval == 10)
    }
}

// MARK: - Test doubles

@MainActor
final class StubScanner: PortScanning {
    let portsSubject = PassthroughSubject<[PortInfo], Never>()
    let errorSubject = PassthroughSubject<PortScannerError, Never>()
    private let refreshError: (any Error)?

    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var refreshCount = 0
    private(set) var recordedInterval: TimeInterval?

    init(refreshError: PortScannerError? = nil) {
        self.refreshError = refreshError
    }

    /// For simulating refresh failures that are not `PortScannerError`s.
    init(untypedRefreshError: any Error) {
        self.refreshError = untypedRefreshError
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

    func setUpdateInterval(_ interval: TimeInterval) {
        recordedInterval = interval
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

actor RecordingKiller: ProcessKilling {
    private let killError: Error?
    private let forceKillError: Error?
    private(set) var forceKilledPids: [Int] = []

    init(killError: Error? = nil, forceKillError: Error? = nil) {
        self.killError = killError
        self.forceKillError = forceKillError
    }

    func kill(port: PortInfo) async throws {
        if let killError {
            throw killError
        }
    }

    func forceKill(port: PortInfo) async throws {
        forceKilledPids.append(port.pid)

        if let forceKillError {
            throw forceKillError
        }
    }
}
