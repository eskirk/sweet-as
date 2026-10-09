import AppKit
import Foundation
import SwiftTerm

@main
struct IntegratedTerminalTest {
    @MainActor
    static func main() async throws {
        _ = NSApplication.shared
        // use a known shell; like the UI, this exercises normal login-shell startup.
        setenv("SHELL", "/bin/bash", 1)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("Pie terminal 'quoted' \(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let session = IntegratedTerminalSession()
        session.startIfNeeded(directory: root.path)
        defer { session.stop() }
        precondition(session.isRunning, session.status)
        let original = session.terminal!
        session.startIfNeeded(directory: "/")
        precondition(session.terminal === original, "reopening a tab must preserve its shell")
        let command = Array("pwd > actual-cwd; printf ready > ready\n".utf8)
        original.process.send(data: command[...])
        for _ in 0..<100 {
            if FileManager.default.fileExists(atPath: root.appendingPathComponent("ready").path) { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        let cwd = try String(contentsOf: root.appendingPathComponent("actual-cwd"), encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        precondition(URL(fileURLWithPath: cwd).resolvingSymlinksInPath() == root.resolvingSymlinksInPath())

        let other = IntegratedTerminalSession()
        other.startIfNeeded(directory: root.path)
        precondition(other.terminal !== original, "sessions must not share terminals")
        other.stop()
        precondition(!other.isRunning && session.isRunning)

        original.process.send(data: Array("exit\n".utf8)[...])
        for _ in 0..<100 {
            if !session.isRunning { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        precondition(!session.isRunning, "shell exit must update the UI state")
        session.start(directory: root.path)
        precondition(session.isRunning && session.terminal !== original)
        let shellPID = session.terminal!.process.shellPid
        session.stop()
        precondition(!session.isRunning)
        for _ in 0..<100 {
            if kill(shellPID, 0) != 0 { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        precondition(kill(shellPID, 0) != 0, "stop must terminate the shell, not just update the UI")

        let missing = IntegratedTerminalSession()
        missing.startIfNeeded(directory: root.appendingPathComponent("missing").path)
        precondition(!missing.isRunning && missing.terminal == nil)
        print("PASS: cwd with spaces/quotes, lazy retention, independent sessions, exit/restart, stop, missing cwd")
    }
}
