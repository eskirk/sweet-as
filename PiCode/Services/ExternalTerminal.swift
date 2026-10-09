import AppKit

// only list apps whose directory-opening behavior we explicitly support.
enum ExternalTerminal: String, CaseIterable, Identifiable {
    case terminal
    case iTerm2
    case ghostty

    var id: String { rawValue }

    var title: String {
        switch self {
        case .terminal: return "Terminal"
        case .iTerm2: return "iTerm2"
        case .ghostty: return "Ghostty"
        }
    }

    var bundleIdentifier: String {
        switch self {
        case .terminal: return "com.apple.Terminal"
        case .iTerm2: return "com.googlecode.iterm2"
        case .ghostty: return "com.mitchellh.ghostty"
        }
    }

    var applicationURL: URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
    }

    // iTerm2 and Ghostty accept directory documents, including when already running.
    var opensDirectory: Bool { self != .terminal }

    static func validateDirectory(_ directory: String) throws {
        var isDirectory: ObjCBool = false
        guard (directory as NSString).isAbsolutePath,
              FileManager.default.fileExists(atPath: directory, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw LaunchError.invalidDirectory(directory)
        }
    }

    static func terminalScript(directory: String) -> String {
        let escaped = directory.replacingOccurrences(of: "'", with: "'\\''")
        return """
        #!/bin/zsh
        rm -f -- "$0"
        cd -- '\(escaped)' || exit 1
        exec "${SHELL:-/bin/zsh}" -l
        """
    }

    enum LaunchError: LocalizedError {
        case invalidDirectory(String)
        case notInstalled(String)

        var errorDescription: String? {
            switch self {
            case .invalidDirectory(let path):
                return "The terminal working directory does not exist: \(path)"
            case .notInstalled(let name):
                return "\(name) is not installed. Choose an installed terminal in Settings → General → Workspace."
            }
        }
    }
}
