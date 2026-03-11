import Foundation
import Testing
@testable import PortMonitor

struct CommandRunnerTests {
    @Test
    func processCommandRunnerCapturesStandardOutputAndError() async throws {
        let runner = ProcessCommandRunner()

        let result = try await runner.run(
            launchPath: "/bin/sh",
            arguments: ["-c", "printf 'ports'; printf ' warning' 1>&2"]
        )

        #expect(result.stdout == "ports")
        #expect(result.stderr == " warning")
        #expect(result.terminationStatus == 0)
    }

    @Test
    func processCommandRunnerReturnsNonZeroTerminationStatus() async throws {
        let runner = ProcessCommandRunner()

        let result = try await runner.run(
            launchPath: "/bin/sh",
            arguments: ["-c", "printf 'failed' 1>&2; exit 7"]
        )

        #expect(result.stdout.isEmpty)
        #expect(result.stderr == "failed")
        #expect(result.terminationStatus == 7)
    }

    @Test
    func processCommandRunnerCapturesInterleavedOutputBeforeExit() async throws {
        let runner = ProcessCommandRunner()

        let result = try await runner.run(
            launchPath: "/bin/sh",
            arguments: ["-c", "printf 'a'; printf 'b' 1>&2; sleep 0.1; printf 'c'; printf 'd' 1>&2"]
        )

        #expect(result.stdout == "ac")
        #expect(result.stderr == "bd")
        #expect(result.terminationStatus == 0)
    }
}
