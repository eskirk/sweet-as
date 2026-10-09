import Foundation

/// a runtime report, not a count inferred from configuration files.
struct MCPStatusSnapshot: Equatable {
    let text: String
    let serverCount: Int
    let checkedAt: Date

    init?(report: String, checkedAt: Date = Date()) {
        let text = report.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("No MCP servers configured.") {
            self.text = text
            self.serverCount = 0
            self.checkedAt = checkedAt
            return
        }

        // only accept the built-in /mcp status format; unrelated notifications
        // and extension-specific reports remain in the normal notification tray.
        let serverPattern = #"^[A-Za-z0-9_-]+: (connected|connecting|starting|disabled|disconnected|needs sign-in|error|failed)(?:[, (]|$)"#
        let lines = text.components(separatedBy: .newlines)
        var count = 0
        var hasDiagnostic = false
        for line in lines where !line.isEmpty {
            if line.range(of: serverPattern, options: .regularExpression) != nil {
                count += 1
            } else if line.hasPrefix("config error: ") || line.hasPrefix("overridden: ") {
                hasDiagnostic = true
            } else if line.hasPrefix("    "), count > 0 || hasDiagnostic {
                continue
            } else {
                return nil
            }
        }
        guard count > 0 || hasDiagnostic else { return nil }
        self.text = text
        self.serverCount = count
        self.checkedAt = checkedAt
    }
}
