import Foundation

/// Safe because access to the stored termination state is serialized with `lock`.
private final class ProcessTerminationObserver: @unchecked Sendable {
    private let lock = NSLock()
    private var terminationStatus: Int32?
    private var continuation: CheckedContinuation<Int32, Never>?

    func attach(to process: Process) {
        process.terminationHandler = { [weak self] process in
            self?.finish(with: process.terminationStatus)
        }
    }

    func waitForExit() async -> Int32 {
        await withCheckedContinuation { continuation in
            lock.lock()

            if let terminationStatus {
                lock.unlock()
                continuation.resume(returning: terminationStatus)
                return
            }

            self.continuation = continuation
            lock.unlock()
        }
    }

    private func finish(with terminationStatus: Int32) {
        lock.lock()
        let continuation = continuation

        if continuation == nil {
            self.terminationStatus = terminationStatus
        } else {
            self.continuation = nil
        }

        lock.unlock()
        continuation?.resume(returning: terminationStatus)
    }
}

struct CommandResult: Equatable, Sendable {
    let stdout: String
    let stderr: String
    let terminationStatus: Int32
}

protocol CommandRunning: Sendable {
    func run(launchPath: String, arguments: [String]) async throws -> CommandResult
}

struct ProcessCommandRunner: CommandRunning {
    func run(launchPath: String, arguments: [String]) async throws -> CommandResult {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        let terminationObserver = ProcessTerminationObserver()

        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        terminationObserver.attach(to: process)

        async let stdoutData = readAll(from: stdoutPipe.fileHandleForReading)
        async let stderrData = readAll(from: stderrPipe.fileHandleForReading)

        do {
            try process.run()
        } catch {
            stdoutPipe.fileHandleForWriting.closeFile()
            stderrPipe.fileHandleForWriting.closeFile()
            throw error
        }

        let terminationStatus = await terminationObserver.waitForExit()
        let (finalStdout, finalStderr) = try await (stdoutData, stderrData)

        return CommandResult(
            stdout: String(data: finalStdout, encoding: .utf8) ?? "",
            stderr: String(data: finalStderr, encoding: .utf8) ?? "",
            terminationStatus: terminationStatus
        )
    }

    private func readAll(from handle: FileHandle) async throws -> Data {
        var data = Data()

        for try await byte in handle.bytes {
            data.append(byte)
        }

        return data
    }
}
