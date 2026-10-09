import Foundation
import AppKit

public struct DevServer: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let primaryPid: pid_t
    public let pids: [pid_t]
    public let command: String
    public let displayCommand: String
    public let path: String
    public let displayPath: String
    public let folderName: String
    public let ports: [Int]
    public var isKilling: Bool

    public var primaryPort: Int? {
        ports.first
    }

    public init(
        id: UUID = UUID(),
        primaryPid: pid_t,
        pids: [pid_t] = [],
        command: String,
        displayCommand: String? = nil,
        path: String,
        ports: [Int] = [],
        isKilling: Bool = false
    ) {
        self.id = id
        self.primaryPid = primaryPid
        self.pids = pids.isEmpty ? [primaryPid] : pids
        self.command = command
        self.path = path
        self.ports = ports
        self.isKilling = isKilling

        // Clean up display command
        let rawToClean = displayCommand ?? command
        self.displayCommand = Self.cleanCommand(rawToClean, cwd: path)

        // Format display path (replace user home with ~)
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(homeDir) {
            self.displayPath = "~" + path.dropFirst(homeDir.count)
        } else {
            self.displayPath = path
        }

        // Extract folder name
        let folder = (path as NSString).lastPathComponent
        self.folderName = (folder.isEmpty || folder == "/") ? "Root" : folder
    }

    public static func cleanCommand(_ raw: String, cwd: String = "") -> String {
        let str = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !str.isEmpty else { return "" }

        // Tokenize command line respecting quotes
        var tokens = [String]()
        var current = ""
        var inQuotes = false
        var quoteChar: Character = "\""
        for ch in str {
            if ch == "\"" || ch == "'" {
                if !inQuotes {
                    inQuotes = true
                    quoteChar = ch
                } else if ch == quoteChar {
                    inQuotes = false
                } else {
                    current.append(ch)
                }
            } else if ch.isWhitespace && !inQuotes {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
            } else {
                current.append(ch)
            }
        }
        if !current.isEmpty { tokens.append(current) }
        guard !tokens.isEmpty else { return str }

        // 1. Simplify binary executable (token 0)
        var bin = (tokens[0] as NSString).lastPathComponent
        if bin.hasPrefix("node") { bin = "node" }
        else if bin.hasPrefix("bun") { bin = "bun" }
        else if bin.hasPrefix("deno") { bin = "deno" }
        tokens[0] = bin

        // 2. Simplify script or target path (token 1)
        if tokens.count > 1 {
            let script = tokens[1]
            if script.hasPrefix("/") || script.hasPrefix("./") {
                let scriptBase = (script as NSString).lastPathComponent

                if script.contains("/node_modules/") {
                    // Check for .bin wrapper, e.g. .../node_modules/.bin/vite -> vite
                    if script.contains("/.bin/") {
                        tokens[0] = scriptBase
                        tokens.remove(at: 1)
                    } else if let lastNM = script.range(of: "/node_modules/", options: .backwards) {
                        let rel = String(script[lastNM.upperBound...])
                        let parts = rel.split(separator: "/")
                        if parts.count > 1 {
                            let pkg = (parts[0].hasPrefix("@") && parts.count > 2) ? "\(parts[0])/\(parts[1])" : String(parts[0])
                            tokens[1] = "\(pkg)/.../\(scriptBase)"
                        } else {
                            tokens[1] = ".../\(scriptBase)"
                        }
                    } else {
                        tokens[1] = ".../\(scriptBase)"
                    }
                } else if !cwd.isEmpty && script.hasPrefix(cwd) {
                    var rel = String(script.dropFirst(cwd.count))
                    if rel.hasPrefix("/") { rel = String(rel.dropFirst()) }
                    tokens[1] = rel
                } else {
                    let home = FileManager.default.homeDirectoryForCurrentUser.path
                    if script.hasPrefix(home) {
                        tokens[1] = "~" + script.dropFirst(home.count)
                    } else {
                        tokens[1] = scriptBase
                    }
                }
            }
        }

        return tokens.joined(separator: " ")
    }

    @MainActor
    public func openInFinder() {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
    }

    @MainActor
    public func openInBrowser() {
        guard let port = primaryPort else { return }
        if let url = URL(string: "http://localhost:\(port)") {
            NSWorkspace.shared.open(url)
        }
    }

    @MainActor
    public func copyCommand() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
    }

    @MainActor
    public func copyPath() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(path, forType: .string)
    }
}
