import AppKit
import SwiftUI
import SwiftTerm

@Observable
@MainActor
final class IntegratedTerminalSession: NSObject, @preconcurrency LocalProcessTerminalViewDelegate {
    private(set) var terminal: LocalProcessTerminalView?
    private(set) var status = "Not started"
    private(set) var isRunning = false
    private var hasStarted = false

    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillTerminate),
                                               name: NSApplication.willTerminateNotification, object: nil)
    }

    @objc private func applicationWillTerminate() { stop() }

    func startIfNeeded(directory: String) {
        guard !hasStarted else { return }
        start(directory: directory)
    }

    func start(directory: String) {
        stop()
        hasStarted = true
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directory, isDirectory: &isDirectory), isDirectory.boolValue else {
            status = "Working directory is unavailable: \(directory)"
            return
        }
        let view = LocalProcessTerminalView(frame: NSRect(x: 0, y: 0, width: 640, height: 400))
        view.processDelegate = self
        terminal = view
        let configuredShell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let shell = FileManager.default.isExecutableFile(atPath: configuredShell) ? configuredShell : "/bin/zsh"
        // cwd is a process attribute, never interpolated into a shell command.
        view.startProcess(executable: shell, args: ["-l"], currentDirectory: directory)
        isRunning = view.process.running
        status = isRunning ? directory : "Could not start \(shell)"
    }

    func stop() {
        guard let terminal else { return }
        terminal.processDelegate = nil
        if terminal.process.running {
            // interactive shells may ignore SIGTERM; hang up their job groups first.
            let foregroundGroup = tcgetpgrp(terminal.process.childfd)
            if foregroundGroup > 0 { kill(-foregroundGroup, SIGHUP) }
            let shellGroup = terminal.process.shellPid
            if shellGroup > 0 && shellGroup != foregroundGroup { kill(-shellGroup, SIGHUP) }
            terminal.terminate()
            // SwiftTerm cancels its exit monitor on terminate; reap without blocking UI.
            if shellGroup > 0 {
                DispatchQueue.global(qos: .utility).async {
                    var status: Int32 = 0
                    for _ in 0..<20 {
                        let result = waitpid(shellGroup, &status, WNOHANG)
                        if result == shellGroup || (result == -1 && errno == ECHILD) { return }
                        usleep(50_000)
                    }
                    if waitpid(shellGroup, &status, WNOHANG) == 0 {
                        kill(shellGroup, SIGKILL)
                        while waitpid(shellGroup, &status, 0) == -1 && errno == EINTR {}
                    }
                }
            }
        }
        isRunning = false
        status = "Shell stopped"
    }

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}
    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
    func processTerminated(source: TerminalView, exitCode: Int32?) {
        guard source === terminal else { return }
        isRunning = false
        status = exitCode.map { "Shell exited (\($0))" } ?? "Shell disconnected"
    }
}

struct IntegratedTerminalPane: View {
    @Bindable var session: IntegratedTerminalSession
    let directory: String

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(session.status)
                    .font(.caption.monospaced())
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(session.status)
                Spacer(minLength: 4)
                if !session.isRunning {
                    Button("Restart") { session.start(directory: directory) }
                        .buttonStyle(.borderless)
                }
            }
            .padding(10)
            Divider()
            if let terminal = session.terminal {
                NativeTerminalView(terminal: terminal)
            } else {
                Spacer()
            }
        }
        .task { session.startIfNeeded(directory: directory) }
    }
}

private struct NativeTerminalView: NSViewRepresentable {
    let terminal: LocalProcessTerminalView

    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ container: NSView, context: Context) {
        guard terminal.superview !== container else { return }
        container.subviews.forEach { $0.removeFromSuperview() }
        terminal.removeFromSuperview()
        terminal.frame = container.bounds
        terminal.autoresizingMask = [.width, .height]
        container.addSubview(terminal)
    }
}
