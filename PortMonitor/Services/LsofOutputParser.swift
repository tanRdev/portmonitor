import Foundation

struct LsofOutputParser: Sendable {
    func parse(_ output: String) -> [PortInfo] {
        var ports = Set<PortInfo>()
        var currentPID: Int?
        var currentProcessName = ""
        var currentAddress: String?

        for rawLine in output.split(whereSeparator: \.isNewline) {
            let line = String(rawLine)
            guard let field = line.first else { continue }
            let value = String(line.dropFirst())

            switch field {
            case "p":
                currentPID = Int(value)
                currentAddress = nil
            case "c":
                currentProcessName = value
            case "f":
                currentAddress = nil
            case "n":
                currentAddress = value
            case "T" where value == "ST=LISTEN":
                guard
                    let pid = currentPID,
                    !currentProcessName.isEmpty,
                    let address = currentAddress,
                    let port = extractPort(from: address)
                else {
                    continue
                }

                ports.insert(PortInfo(
                    port: port,
                    processName: currentProcessName,
                    pid: pid,
                    protocolType: "TCP"
                ))
            default:
                continue
            }
        }

        return ports.sorted()
    }

    private func extractPort(from address: String) -> Int? {
        guard let separator = address.lastIndex(of: ":") else {
            return nil
        }

        return Int(address[address.index(after: separator)...])
    }
}
