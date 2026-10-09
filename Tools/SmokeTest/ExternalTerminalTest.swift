import Foundation

@main
struct ExternalTerminalTest {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let directory = root.appendingPathComponent("spaces 'quotes' $(touch injected)\nnext line")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try ExternalTerminal.validateDirectory(directory.path)
        for invalid in ["relative", root.appendingPathComponent("missing").path] {
            do {
                try ExternalTerminal.validateDirectory(invalid)
                fatalError("accepted invalid directory: \(invalid)")
            } catch is ExternalTerminal.LaunchError {}
        }

        let shell = root.appendingPathComponent("test-shell")
        try "#!/bin/sh\nprintf '%s' \"$PWD\"\n".write(to: shell, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: shell.path)
        do {
            try ExternalTerminal.validateDirectory(shell.path)
            fatalError("accepted a file as a directory")
        } catch is ExternalTerminal.LaunchError {}

        let script = root.appendingPathComponent("launch.command")
        try ExternalTerminal.terminalScript(directory: directory.path)
            .write(to: script, atomically: true, encoding: .utf8)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = [script.path]
        process.currentDirectoryURL = root
        process.environment = ProcessInfo.processInfo.environment.merging(["SHELL": shell.path]) { _, new in new }
        let output = Pipe()
        process.standardOutput = output
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        precondition(process.terminationStatus == 0)
        let actual = URL(fileURLWithPath: String(decoding: data, as: UTF8.self)).resolvingSymlinksInPath()
        precondition(actual == directory.resolvingSymlinksInPath(), "incorrect shell cwd")
        precondition(!FileManager.default.fileExists(atPath: root.appendingPathComponent("injected").path))
        precondition(!FileManager.default.fileExists(atPath: script.path), "script must clean itself up")
        precondition(!ExternalTerminal.terminal.opensDirectory)
        precondition(ExternalTerminal.iTerm2.opensDirectory && ExternalTerminal.ghostty.opensDirectory)
        precondition(Set(ExternalTerminal.allCases.map(\.bundleIdentifier)).count == 3)
        for terminal in ExternalTerminal.allCases {
            precondition(ExternalTerminal(rawValue: terminal.rawValue) == terminal)
        }
        print("PASS: directory validation, quoted cwd, no command injection, script cleanup, app launch strategies")
    }
}
