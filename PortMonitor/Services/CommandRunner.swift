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

        // Start the process before any structured-concurrency work so a
        // spawn failure cannot leave pipe readers behind.
        do {
            try process.run()
        } catch {
            stdoutPipe.fileHandleForWriting.closeFile()
            stderrPipe.fileHandleForWriting.closeFile()
            stdoutPipe.fileHandleForReading.closeFile()
            stderrPipe.fileHandleForReading.closeFile()
            throw error
        }

        async let stdoutData = readAll(from: stdoutPipe.fileHandleForReading)
        async let stderrData = readAll(from: stderrPipe.fileHandleForReading)

        let terminationStatus = await terminationObserver.waitForExit()
        let (finalStdout, finalStderr) = await (stdoutData, stderrData)

        return CommandResult(
            stdout: String(data: finalStdout, encoding: .utf8) ?? "",
            stderr: String(data: finalStderr, encoding: .utf8) ?? "",
            terminationStatus: terminationStatus
        )
    }

    /// Reads the pipe in 64 KB chunks on a background executor instead of
    /// byte-at-a-time through `FileHandle.AsyncBytes`.
    private func readAll(from handle: FileHandle) async -> Data {
        let fileDescriptor = handle.fileDescriptor

        return await Task.detached(priority: .utility) {
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 64 * 1024)

            while true {
                let count = buffer.withUnsafeMutableBytes { pointer in
                    Darwin.read(fileDescriptor, pointer.baseAddress, pointer.count)
                }

                // 0 is EOF; a negative count is a read error, treated as
                // end-of-stream to match the previous best-effort behavior.
                guard count > 0 else { break }
                data.append(contentsOf: buffer[..<count])
            }

            return data
        }.value
    }
}
