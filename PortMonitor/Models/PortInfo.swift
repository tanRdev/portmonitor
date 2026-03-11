import Foundation

struct PortInfo: Identifiable, Equatable, Comparable, Hashable, Sendable {
    let port: Int
    let processName: String
    let pid: Int
    let protocolType: String

    var id: String {
        "\(pid):\(port)"
    }

    static func < (lhs: PortInfo, rhs: PortInfo) -> Bool {
        lhs.port < rhs.port
    }
}
