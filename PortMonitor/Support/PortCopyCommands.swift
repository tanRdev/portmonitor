import AppKit

enum PortCopyCommands {
    static func lsofCommand(for port: PortInfo) -> String {
        "lsof -i :\(port.port)"
    }

    static func copyPort(_ port: PortInfo) {
        write(String(port.port))
    }

    static func copyPID(_ port: PortInfo) {
        write(String(port.pid))
    }

    static func copyProcessName(_ port: PortInfo) {
        write(port.processName)
    }

    static func copyLsofCommand(_ port: PortInfo) {
        write(lsofCommand(for: port))
    }

    private static func write(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }
}
