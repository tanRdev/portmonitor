import Foundation
import Combine

enum PortScannerError: Error, Equatable {
    case commandFailed(status: Int32, message: String)

    var userMessage: String {
        switch self {
        case let .commandFailed(_, message):
            let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                return "Unable to scan ports."
            }

            return "Unable to scan ports: \(trimmed)"
        }
    }
}

@MainActor
protocol PortScanning: AnyObject {
    var portsPublisher: AnyPublisher<[PortInfo], Never> { get }
    var errorPublisher: AnyPublisher<PortScannerError, Never> { get }

    func startScanning()
    func stopScanning()
    func setUpdateInterval(_ interval: TimeInterval)
    func refresh() async throws
}

@MainActor
final class PortScanner: ObservableObject, PortScanning {
    @Published private(set) var ports: [PortInfo] = []

    private var timer: Timer?
    private var updateInterval: TimeInterval
    private let commandRunner: any CommandRunning
    private let parser: LsofOutputParser
    private let errorSubject = PassthroughSubject<PortScannerError, Never>()

    var portsPublisher: AnyPublisher<[PortInfo], Never> {
        $ports.eraseToAnyPublisher()
    }

    var errorPublisher: AnyPublisher<PortScannerError, Never> {
        errorSubject.eraseToAnyPublisher()
    }

    init(
        commandRunner: any CommandRunning = ProcessCommandRunner(),
        parser: LsofOutputParser = LsofOutputParser(),
        updateInterval: TimeInterval = 3.0
    ) {
        self.commandRunner = commandRunner
        self.parser = parser
        self.updateInterval = updateInterval
    }

    func startScanning() {
        stopScanning()
        refreshIgnoringErrors()

        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshIgnoringErrors()
            }
        }
    }

    func stopScanning() {
        timer?.invalidate()
        timer = nil
    }

    func setUpdateInterval(_ interval: TimeInterval) {
        updateInterval = interval

        // Restart the timer so the new interval takes effect immediately.
        if timer != nil {
            startScanning()
        }
    }

    func refresh() async throws {
        let result = try await commandRunner.run(
            launchPath: "/usr/sbin/lsof",
            arguments: ["-nP", "-iTCP", "-sTCP:LISTEN", "-FpcnT"]
        )

        if result.terminationStatus == 1,
           result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           result.stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ports = []
            return
        }

        guard result.terminationStatus == 0 else {
            throw PortScannerError.commandFailed(status: result.terminationStatus, message: result.stderr)
        }

        ports = parser.parse(result.stdout)
    }

    private func refreshIgnoringErrors() {
        Task { @MainActor in
            do {
                try await refresh()
            } catch let error as PortScannerError {
                errorSubject.send(error)
            } catch {
                errorSubject.send(.commandFailed(status: -1, message: error.localizedDescription))
            }
        }
    }
}
