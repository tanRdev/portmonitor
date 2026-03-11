import Foundation

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
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            let stdoutHandle = stdoutPipe.fileHandleForReading
            let stderrHandle = stderrPipe.fileHandleForReading
            let lock = NSLock()
            var stdoutData = Data()
            var stderrData = Data()

            process.executableURL = URL(fileURLWithPath: launchPath)
            process.arguments = arguments
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            stdoutHandle.readabilityHandler = { fileHandle in
                let data = fileHandle.availableData
                guard !data.isEmpty else {
                    fileHandle.readabilityHandler = nil
                    return
                }

                lock.lock()
                stdoutData.append(data)
                lock.unlock()
            }

            stderrHandle.readabilityHandler = { fileHandle in
                let data = fileHandle.availableData
                guard !data.isEmpty else {
                    fileHandle.readabilityHandler = nil
                    return
                }

                lock.lock()
                stderrData.append(data)
                lock.unlock()
            }

            process.terminationHandler = { process in
                stdoutHandle.readabilityHandler = nil
                stderrHandle.readabilityHandler = nil

                lock.lock()
                stdoutData.append(stdoutHandle.readDataToEndOfFile())
                stderrData.append(stderrHandle.readDataToEndOfFile())
                let finalStdout = stdoutData
                let finalStderr = stderrData
                lock.unlock()

                continuation.resume(returning: CommandResult(
                    stdout: String(data: finalStdout, encoding: .utf8) ?? "",
                    stderr: String(data: finalStderr, encoding: .utf8) ?? "",
                    terminationStatus: process.terminationStatus
                ))
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
