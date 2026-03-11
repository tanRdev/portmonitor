import Foundation

enum KillError: Error, Equatable, Sendable {
    case processNotFound
    case permissionDenied
    case killFailed(String)
}

protocol ProcessKilling: Sendable {
    func kill(port: PortInfo) async throws
}

struct ProcessKiller: ProcessKilling, Sendable {
    private let commandRunner: any CommandRunning

    init(commandRunner: any CommandRunning = ProcessCommandRunner()) {
        self.commandRunner = commandRunner
    }

    func kill(pid: Int) async throws {
        do {
            try await send(signal: "-TERM", pid: pid)
        } catch KillError.permissionDenied {
            throw KillError.permissionDenied
        } catch KillError.processNotFound {
            throw KillError.processNotFound
        } catch {
            try await send(signal: "-KILL", pid: pid)
        }
    }

    func kill(port: PortInfo) async throws {
        try await kill(pid: port.pid)
    }

    private func send(signal: String, pid: Int) async throws {
        let result = try await commandRunner.run(
            launchPath: "/bin/kill",
            arguments: [signal, String(pid)]
        )

        guard result.terminationStatus == 0 else {
            throw mapError(from: result.stderr)
        }
    }

    private func mapError(from stderr: String) -> KillError {
        let message = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = message.lowercased()

        if normalized.contains("operation not permitted") || normalized.contains("not permitted") {
            return .permissionDenied
        }

        if normalized.contains("no such process") {
            return .processNotFound
        }

        return .killFailed(message.isEmpty ? "Unknown error" : message)
    }
}
