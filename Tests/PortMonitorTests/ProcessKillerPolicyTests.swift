import Darwin
import Foundation
import Testing
@testable import PortMonitor

struct ProcessKillerPolicyTests {
    private let port = PortInfo(port: 3000, processName: "node", pid: 4242, protocolType: "TCP")

    private func makeKiller(
        identity: ProcessIdentity,
        outcome: SignalOutcome = .delivered,
        currentUID: uid_t = 501
    ) -> (ProcessKiller, RecordingInspector, RecordingSignalSender) {
        makeKiller(inspection: .identified(identity), outcome: outcome, currentUID: currentUID)
    }

    private func makeKiller(
        inspection: ProcessInspection,
        outcome: SignalOutcome = .delivered,
        currentUID: uid_t = 501
    ) -> (ProcessKiller, RecordingInspector, RecordingSignalSender) {
        let inspector = RecordingInspector(inspection: inspection)
        let sender = RecordingSignalSender(outcome: outcome)
        let killer = ProcessKiller(inspector: inspector, signalSender: sender, currentUID: currentUID)
        return (killer, inspector, sender)
    }

    // MARK: - PID guard

    @Test(arguments: [0, 1, -5])
    func refusesCoreSystemPIDsWithoutInspectingOrSignaling(pid: Int) async {
        let (killer, inspector, sender) = makeKiller(inspection: .notFound)
        let target = PortInfo(port: 80, processName: "launchd", pid: pid, protocolType: "TCP")

        await #expect(throws: KillError.policyRefused("Refusing to signal core system process (PID \(pid)).")) {
            try await killer.kill(port: target)
        }

        #expect(inspector.callCount == 0)
        #expect(sender.sent.isEmpty)
    }

    // MARK: - Existence

    @Test
    func reportsMissingProcessWithoutSignaling() async {
        let (killer, _, sender) = makeKiller(inspection: .notFound)

        await #expect(throws: KillError.processNotFound) {
            try await killer.kill(port: port)
        }

        #expect(sender.sent.isEmpty)
    }

    @Test
    func reportsUnsignalableProcessAsPermissionDenied() async {
        let (killer, _, sender) = makeKiller(inspection: .notPermitted)

        await #expect(throws: KillError.permissionDenied) {
            try await killer.kill(port: port)
        }

        #expect(sender.sent.isEmpty)
    }

    @Test
    func failsClosedWhenIdentityCannotBeVerified() async {
        let (killer, _, sender) = makeKiller(inspection: .unverifiable)

        await #expect(throws: KillError.policyRefused(
            "Could not verify the identity of PID 4242; refusing to signal it."
        )) {
            try await killer.kill(port: port)
        }

        #expect(sender.sent.isEmpty)
    }

    // MARK: - Ownership policy

    @Test
    func refusesProcessOwnedByAnotherUser() async {
        let identity = ProcessIdentity(pid: 4242, name: "node", uid: 0)
        let (killer, _, sender) = makeKiller(identity: identity, currentUID: 501)

        await #expect(throws: KillError.policyRefused(
            "node (PID 4242) is owned by another user (UID 0); refusing to signal it."
        )) {
            try await killer.kill(port: port)
        }

        #expect(sender.sent.isEmpty)
    }

    @Test
    func refusesProtectedSystemProcessEvenWhenOwnedByCurrentUser() async {
        let identity = ProcessIdentity(pid: 4242, name: "cfprefsd", uid: 501)
        let (killer, _, sender) = makeKiller(identity: identity)
        let target = PortInfo(port: 3000, processName: "cfprefsd", pid: 4242, protocolType: "TCP")

        await #expect(throws: KillError.policyRefused(
            "cfprefsd is a critical system process; refusing to signal it."
        )) {
            try await killer.kill(port: target)
        }

        #expect(sender.sent.isEmpty)
    }

    // MARK: - PID reuse guard

    @Test
    func refusesWhenPIDWasRecycledByDifferentProcess() async {
        let identity = ProcessIdentity(pid: 4242, name: "Code", uid: 501)
        let (killer, _, sender) = makeKiller(identity: identity)

        await #expect(throws: KillError.processIdentityChanged(expected: "node", found: "Code")) {
            try await killer.kill(port: port)
        }

        #expect(sender.sent.isEmpty)
    }

    @Test
    func matchesNamesTruncatedToKernelCommLength() async throws {
        // pbi_comm is truncated to 16 chars; lsof may report the full name.
        let identity = ProcessIdentity(pid: 4242, name: "VeryLongProcessN", uid: 501)
        let (killer, _, sender) = makeKiller(identity: identity)
        let target = PortInfo(port: 3000, processName: "VeryLongProcessName", pid: 4242, protocolType: "TCP")

        try await killer.kill(port: target)

        #expect(sender.sent == [SentSignal(signal: SIGTERM, pid: 4242)])
    }

    // MARK: - Signal delivery

    @Test
    func sendsSIGTERMToVerifiedProcess() async throws {
        let identity = ProcessIdentity(pid: 4242, name: "node", uid: 501)
        let (killer, inspector, sender) = makeKiller(identity: identity)

        try await killer.kill(port: port)

        #expect(inspector.callCount == 1)
        #expect(sender.sent == [SentSignal(signal: SIGTERM, pid: 4242)])
    }

    @Test
    func doesNotAutoEscalateToSIGKILLAfterGenericSIGTERMFailure() async {
        let identity = ProcessIdentity(pid: 4242, name: "node", uid: 501)
        let (killer, _, sender) = makeKiller(identity: identity, outcome: .failed(errno: EIO))

        await #expect(throws: KillError.killFailed("Input/output error")) {
            try await killer.kill(port: port)
        }

        // Exactly one signal was sent; escalation is the user's explicit choice.
        #expect(sender.sent == [SentSignal(signal: SIGTERM, pid: 4242)])
    }

    @Test
    func mapsEPERMToPermissionDenied() async {
        let identity = ProcessIdentity(pid: 4242, name: "node", uid: 501)
        let (killer, _, _) = makeKiller(identity: identity, outcome: .notPermitted)

        await #expect(throws: KillError.permissionDenied) {
            try await killer.kill(port: port)
        }
    }

    @Test
    func mapsESRCHToProcessNotFound() async {
        let identity = ProcessIdentity(pid: 4242, name: "node", uid: 501)
        let (killer, _, _) = makeKiller(identity: identity, outcome: .noSuchProcess)

        await #expect(throws: KillError.processNotFound) {
            try await killer.kill(port: port)
        }
    }

    @Test
    func forceKillSendsSIGKILLAfterVerification() async throws {
        let identity = ProcessIdentity(pid: 4242, name: "node", uid: 501)
        let (killer, _, sender) = makeKiller(identity: identity)

        try await killer.forceKill(port: port)

        #expect(sender.sent == [SentSignal(signal: SIGKILL, pid: 4242)])
    }

    @Test
    func forceKillStillAppliesPolicyGuards() async {
        let identity = ProcessIdentity(pid: 4242, name: "node", uid: 0)
        let (killer, _, sender) = makeKiller(identity: identity, currentUID: 501)

        await #expect(throws: KillError.policyRefused(
            "node (PID 4242) is owned by another user (UID 0); refusing to signal it."
        )) {
            try await killer.forceKill(port: port)
        }

        #expect(sender.sent.isEmpty)
    }

    // MARK: - Live SystemProcessInspector

    @Test
    func systemInspectorReadsIdentityOfCurrentProcess() throws {
        let inspection = SystemProcessInspector().inspect(Int(ProcessInfo.processInfo.processIdentifier))

        let identity = try #require(inspection.identified)
        #expect(identity.pid == ProcessInfo.processInfo.processIdentifier)
        #expect(identity.uid == geteuid())
        #expect(identity.name.isEmpty == false)
    }

    @Test
    func systemInspectorReportsLaunchdAsNotPermittedForNonRootCallers() throws {
        try #require(geteuid() != 0)

        #expect(SystemProcessInspector().inspect(1) == .notPermitted)
    }

    @Test
    func systemInspectorReportsExhaustedPIDSpaceAsNotFound() {
        #expect(SystemProcessInspector().inspect(99_999_999) == .notFound)
    }
}

private extension ProcessInspection {
    var identified: ProcessIdentity? {
        guard case let .identified(identity) = self else { return nil }
        return identity
    }
}

struct SentSignal: Equatable, Sendable {
    let signal: Int32
    let pid: Int32
}

final class RecordingInspector: ProcessInspecting, @unchecked Sendable {
    private let lock = NSLock()
    private let inspection: ProcessInspection
    private(set) var callCount = 0

    init(inspection: ProcessInspection) {
        self.inspection = inspection
    }

    func inspect(_ pid: Int) -> ProcessInspection {
        lock.lock()
        callCount += 1
        lock.unlock()
        return inspection
    }
}

final class RecordingSignalSender: SignalSending, @unchecked Sendable {
    private let lock = NSLock()
    private let outcome: SignalOutcome
    private var recorded: [SentSignal] = []

    var sent: [SentSignal] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    init(outcome: SignalOutcome) {
        self.outcome = outcome
    }

    func send(_ signal: Int32, to pid: Int32) -> SignalOutcome {
        lock.lock()
        recorded.append(SentSignal(signal: signal, pid: pid))
        lock.unlock()
        return outcome
    }
}
