import Darwin
import Foundation

enum KillError: Error, Equatable, Sendable {
    case processNotFound
    case permissionDenied
    /// The PID now belongs to a different process than the one from the scan
    /// (the PID was recycled after the process exited).
    case processIdentityChanged(expected: String, found: String)
    /// A local safety policy refused to signal this process.
    case policyRefused(String)
    case killFailed(String)
}

protocol ProcessKilling: Sendable {
    func kill(port: PortInfo) async throws
    func forceKill(port: PortInfo) async throws
}

/// Snapshot of a live process, used to re-verify identity before signaling.
struct ProcessIdentity: Equatable, Sendable {
    let pid: Int32
    let name: String
    let uid: uid_t
}

/// Result of probing a PID before signaling it.
enum ProcessInspection: Equatable, Sendable {
    /// No process occupies the PID.
    case notFound
    /// The process exists but may not be signaled by this user.
    case notPermitted
    /// The process exists but its identity could not be read.
    case unverifiable
    /// The process exists and its identity was read.
    case identified(ProcessIdentity)
}

protocol ProcessInspecting: Sendable {
    func inspect(_ pid: Int) -> ProcessInspection
}

struct SystemProcessInspector: ProcessInspecting {
    func inspect(_ pid: Int) -> ProcessInspection {
        // kill(pid, 0) performs the existence/permission probe without
        // delivering a signal.
        guard Darwin.kill(Int32(pid), 0) == 0 else {
            switch errno {
            case ESRCH: return .notFound
            case EPERM: return .notPermitted
            default: return .unverifiable
            }
        }

        var info = proc_bsdinfo()
        let expectedSize = Int32(MemoryLayout<proc_bsdinfo>.size)
        let size = proc_pidinfo(Int32(pid), PROC_PIDTBSDINFO, 0, &info, expectedSize)
        guard size == expectedSize else { return .unverifiable }

        let name = withUnsafePointer(to: info.pbi_comm) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: Int(MAXCOMLEN) + 1) {
                String(cString: $0)
            }
        }

        return .identified(ProcessIdentity(pid: Int32(pid), name: name, uid: info.pbi_uid))
    }
}

/// Result of attempting to deliver a signal, classified from errno rather
/// than from localized stderr text.
enum SignalOutcome: Equatable, Sendable {
    case delivered
    case noSuchProcess
    case notPermitted
    case failed(errno: Int32)
}

protocol SignalSending: Sendable {
    func send(_ signal: Int32, to pid: Int32) -> SignalOutcome
}

struct DarwinSignalSender: SignalSending {
    func send(_ signal: Int32, to pid: Int32) -> SignalOutcome {
        guard Darwin.kill(pid, signal) != 0 else { return .delivered }

        switch errno {
        case ESRCH: return .noSuchProcess
        case EPERM: return .notPermitted
        case let code: return .failed(errno: code)
        }
    }
}

/// Local safety policy for kill targets. All checks fail closed.
enum KillTargetPolicy {
    /// Processes that must never be signaled from the app, even when they are
    /// owned by the current user (e.g. the per-user launchd or cfprefsd).
    static let protectedProcessNames: Set<String> = [
        "launchd", "kernel_task", "WindowServer", "loginwindow",
        "logd", "opendirectoryd", "securityd", "cfprefsd", "distnoted",
    ]

    /// PIDs 0 (kernel_task) and 1 (launchd) are never valid targets.
    static func refusal(forPID pid: Int) -> KillError? {
        guard pid > 1 else {
            return .policyRefused("Refusing to signal core system process (PID \(pid)).")
        }

        return nil
    }

    /// Re-verifies the live process occupying the PID against the scan result.
    static func refusal(
        for identity: ProcessIdentity,
        expectedName: String,
        currentUID: uid_t
    ) -> KillError? {
        guard identity.uid == currentUID else {
            return .policyRefused(
                "\(identity.name) (PID \(identity.pid)) is owned by another user (UID \(identity.uid)); refusing to signal it."
            )
        }

        let expected = normalized(expectedName)
        let found = normalized(identity.name)
        guard found == expected else {
            return .processIdentityChanged(expected: expectedName, found: identity.name)
        }

        if protectedProcessNames.contains(found) {
            return .policyRefused("\(identity.name) is a critical system process; refusing to signal it.")
        }

        return nil
    }

    /// lsof and proc_pidinfo both report pbi_comm, which the kernel truncates
    /// to MAXCOMLEN (16) characters, so compare on that normalization.
    static func normalized(_ name: String) -> String {
        String(name.prefix(Int(MAXCOMLEN))).lowercased()
    }
}

struct ProcessKiller: ProcessKilling, Sendable {
    private let inspector: any ProcessInspecting
    private let signalSender: any SignalSending
    private let currentUID: uid_t

    init(
        inspector: any ProcessInspecting = SystemProcessInspector(),
        signalSender: any SignalSending = DarwinSignalSender(),
        currentUID: uid_t = geteuid()
    ) {
        self.inspector = inspector
        self.signalSender = signalSender
        self.currentUID = currentUID
    }

    /// Sends SIGTERM only. There is deliberately no automatic SIGKILL
    /// escalation; the user chooses Force Kill explicitly.
    func kill(port: PortInfo) async throws {
        try await performKill(port: port, signal: SIGTERM)
    }

    func forceKill(port: PortInfo) async throws {
        try await performKill(port: port, signal: SIGKILL)
    }

    private func performKill(port: PortInfo, signal: Int32) async throws {
        if let refusal = KillTargetPolicy.refusal(forPID: port.pid) {
            throw refusal
        }

        // PIDs are recycled and the scan result may be seconds old: re-verify
        // that the process occupying the PID is still the one from the scan
        // before signaling it. Fail closed when identity cannot be confirmed.
        let identity: ProcessIdentity
        switch inspector.inspect(port.pid) {
        case .notFound:
            throw KillError.processNotFound
        case .notPermitted:
            throw KillError.permissionDenied
        case .unverifiable:
            throw KillError.policyRefused(
                "Could not verify the identity of PID \(port.pid); refusing to signal it."
            )
        case let .identified(confirmed):
            identity = confirmed
        }

        if let refusal = KillTargetPolicy.refusal(
            for: identity,
            expectedName: port.processName,
            currentUID: currentUID
        ) {
            throw refusal
        }

        switch signalSender.send(signal, to: Int32(port.pid)) {
        case .delivered:
            return
        case .noSuchProcess:
            throw KillError.processNotFound
        case .notPermitted:
            throw KillError.permissionDenied
        case let .failed(code):
            throw KillError.killFailed(String(cString: strerror(code)))
        }
    }
}
