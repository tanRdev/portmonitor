import Testing
@testable import PortMonitor

struct PortScannerParsingTests {
    @Test
    func portInfoUsesStableIdentityFromProcessAndPort() {
        let port = PortInfo(port: 3000, processName: "node", pid: 4242, protocolType: "TCP")

        #expect(port.id == "4242:3000")
    }

    @Test
    func lsofParserParsesListeningRecordsDeduplicatesAndSorts() {
        let output = """
        p25373
        cSuperset
        f41
        n127.0.0.1:41729
        TST=LISTEN
        f78
        n127.0.0.1:51741
        TST=LISTEN
        p38975
        cControlCenter
        f9
        n*:7000
        TST=LISTEN
        f10
        n*:7000
        TST=LISTEN
        p68347
        cPencil
        f49
        n[::1]:54081
        TST=LISTEN
        """

        let ports = LsofOutputParser().parse(output)

        #expect(ports.map(\.port) == [7000, 41729, 51741, 54081])
        #expect(ports.map(\.processName) == ["ControlCenter", "Superset", "Superset", "Pencil"])
        #expect(ports.map(\.id) == ["38975:7000", "25373:41729", "25373:51741", "68347:54081"])
    }

    @Test
    @MainActor
    func scannerRefreshUsesMachineReadableLsofOutput() async throws {
        let runner = StubCommandRunner(
            stdout: """
            p100
            cnode
            f12
            n*:3000
            TST=LISTEN
            p101
            cvite
            f14
            n127.0.0.1:5173
            TST=LISTEN
            """
        )
        let scanner = PortScanner(commandRunner: runner)

        try await scanner.refresh()

        #expect(scanner.ports.map(\.port) == [3000, 5173])
        #expect(await runner.calls == [
            CommandCall(launchPath: "/usr/sbin/lsof", arguments: ["-nP", "-iTCP", "-sTCP:LISTEN", "-FpcnT"])
        ])
    }

    @Test
    @MainActor
    func scannerRefreshTreatsNoMatchingPortsAsEmptyResults() async throws {
        let runner = StubCommandRunner(stdout: "", stderr: "", terminationStatus: 1)
        let scanner = PortScanner(commandRunner: runner)

        try await scanner.refresh()

        #expect(scanner.ports.isEmpty)
    }
}

private actor StubCommandRunner: CommandRunning {
    let stdout: String
    let stderr: String
    let terminationStatus: Int32
    private(set) var calls: [CommandCall] = []

    init(stdout: String, stderr: String = "", terminationStatus: Int32 = 0) {
        self.stdout = stdout
        self.stderr = stderr
        self.terminationStatus = terminationStatus
    }

    func run(launchPath: String, arguments: [String]) async throws -> CommandResult {
        calls.append(CommandCall(launchPath: launchPath, arguments: arguments))
        return CommandResult(stdout: stdout, stderr: stderr, terminationStatus: terminationStatus)
    }
}

private struct CommandCall: Equatable {
    let launchPath: String
    let arguments: [String]
}
