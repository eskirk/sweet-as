import Foundation

@main
struct MCPStatusTest {
    static func main() {
        let checkedAt = Date(timeIntervalSince1970: 100)
        let report = """
        github: connected, 8 tools (codemode)
        docs: needs sign-in, run /mcp login docs (direct)
        local: disabled (hidden)
        broken: disconnected, reconnects on next call (codemode)
            connection refused
        """
        let parsed = MCPStatusSnapshot(report: report, checkedAt: checkedAt)
        precondition(parsed?.serverCount == 4)
        precondition(parsed?.text == report)
        precondition(parsed?.checkedAt == checkedAt)
        precondition(MCPStatusSnapshot(report: "No MCP servers configured. Add them to ~/.pi/agent/mcp.json or .pi/mcp.json.")?.serverCount == 0)
        precondition(MCPStatusSnapshot(report: "config error: invalid server entry")?.serverCount == 0)
        precondition(MCPStatusSnapshot(report: "overridden: tools from extension")?.serverCount == 0)
        precondition(MCPStatusSnapshot(report: "MCP servers need attention:\n  github: disconnected") == nil)
        precondition(MCPStatusSnapshot(report: "Reconnected to MCP server github (connected).") == nil)
        precondition(MCPStatusSnapshot(report: "") == nil)
        precondition(MCPStatusSnapshot(report: "hello: this is not server status") == nil)
        precondition(MCPStatusSnapshot(report: "github: connected, 2 tools (direct)\nUnexpected notification") == nil)
        print("MCP status parsing checks passed")
    }
}
