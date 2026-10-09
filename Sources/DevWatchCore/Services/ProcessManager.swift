import Foundation
import Darwin
import Combine

private struct RawProcess: Sendable {
    let pid: pid_t
    let ppid: pid_t
    let command: String
}

// Background scanner and terminator — fully nonisolated & thread-safe
private enum ProcessScanner {
    static func terminateProcesses(pids: [pid_t]) {
        guard !pids.isEmpty else { return }

        // Discover any child processes
        var targetPids = Set<pid_t>(pids)
        let allProcs = getAllProcesses()
        for p in pids {
            let children = findChildren(of: p, in: allProcs)
            targetPids.formUnion(children)
        }

        // Send SIGTERM first for graceful termination
        for pid in targetPids {
            Darwin.kill(pid, SIGTERM)
        }

        usleep(250_000) // 250ms

        // Force kill with SIGKILL if still running
        for pid in targetPids {
            if Darwin.kill(pid, 0) == 0 {
                Darwin.kill(pid, SIGKILL)
            }
        }
    }

    private static func findChildren(of parentPid: pid_t, in procs: [RawProcess]) -> Set<pid_t> {
        var result = Set<pid_t>()
        for proc in procs where proc.ppid == parentPid {
            result.insert(proc.pid)
            result.formUnion(findChildren(of: proc.pid, in: procs))
        }
        return result
    }

    static func detectDevServers() -> [DevServer] {
        let portsMap = getListeningPorts()
        let allProcs = getAllProcesses()
        var procByPid: [pid_t: RawProcess] = [:]
        for proc in allProcs {
            procByPid[proc.pid] = proc
        }

        var candidateServers: [DevServer] = []
        var consumedPids = Set<pid_t>()

        // Exclusion criteria
        let isExcluded: (RawProcess) -> Bool = { proc in
            let cmd = proc.command
            if cmd.contains("/Applications/") ||
               cmd.contains("/System/") ||
               cmd.contains("/Library/") ||
               cmd.contains("node_modules/@getpaseo") ||
               cmd.contains("Paseo Helper") ||
               cmd.contains("Discord Helper") ||
               cmd.contains("Slack Helper") ||
               cmd.contains("Raycast Backend") ||
               cmd.contains("Code Helper") ||
               cmd.contains("Cursor Helper") ||
               cmd.contains("DevWatch") ||
               cmd.contains("agy") {
                return true
            }
            return false
        }

        // Check if process belongs to Node/JS dev ecosystem
        let isNodeEcosystem: (RawProcess) -> Bool = { proc in
            let cmd = proc.command
            let firstWord = cmd.split(separator: " ").first.map(String.init) ?? ""
            let binName = (firstWord as NSString).lastPathComponent

            if binName == "node" || binName == "bun" || binName == "deno" ||
               binName == "npm" || binName == "pnpm" || binName == "yarn" || binName == "npx" {
                return true
            }
            if cmd.contains("node ") || cmd.contains("bun ") || cmd.contains("deno ") ||
               cmd.contains("npm ") || cmd.contains("pnpm ") || cmd.contains("yarn ") ||
               cmd.contains("vite") || cmd.contains("next") || cmd.contains("nodemon") ||
               cmd.contains("tsx ") || cmd.contains("ts-node") {
                return true
            }
            return false
        }

        // Check if command looks like a dev command
        let isDevCommand: (String) -> Bool = { cmd in
            let lower = cmd.lowercased()
            return lower.contains("run dev") || lower.contains(" dev") ||
                   lower.contains("run start") || lower.contains(" start") ||
                   lower.contains("run serve") || lower.contains(" serve") ||
                   lower.contains("run watch") || lower.contains(" watch") ||
                   lower.contains("vite") || lower.contains("next dev") ||
                   lower.contains("remix dev") || lower.contains("astro dev") ||
                   lower.contains("nuxt dev") || lower.contains("gatsby develop") ||
                   lower.contains("webpack serve") || lower.contains("webpack-dev-server") ||
                   lower.contains("nodemon") || lower.contains("tsx watch") ||
                   lower.contains("ts-node-dev")
        }

        // 1. First Pass: Detect processes actively listening on TCP ports
        for (pid, ports) in portsMap {
            guard let proc = procByPid[pid], !isExcluded(proc), isNodeEcosystem(proc) else {
                continue
            }

            guard let cwd = getCwd(pid: pid), !cwd.isEmpty, cwd != "/" else {
                continue
            }

            // Check if this process has a parent that is a dev runner (e.g. npm run dev, pnpm dev)
            var pidsToKill = [pid]
            var displayCommand = proc.command
            var parentPid = proc.ppid

            while parentPid > 1, let parent = procByPid[parentPid], !isExcluded(parent) {
                if isNodeEcosystem(parent) && (isDevCommand(parent.command) || parent.command.contains("npm") || parent.command.contains("pnpm") || parent.command.contains("yarn")) {
                    displayCommand = parent.command
                    pidsToKill.append(parentPid)
                    consumedPids.insert(parentPid)
                }
                parentPid = parent.ppid
            }

            consumedPids.insert(pid)
            let server = DevServer(
                primaryPid: pid,
                pids: pidsToKill,
                command: proc.command,
                displayCommand: displayCommand,
                path: cwd,
                ports: ports
            )
            candidateServers.append(server)
        }

        // 2. Second Pass: Processes running dev commands that might not have bound port yet
        for proc in allProcs {
            let pid = proc.pid
            guard !consumedPids.contains(pid),
                  !isExcluded(proc),
                  isNodeEcosystem(proc),
                  isDevCommand(proc.command) else {
                continue
            }

            guard let cwd = getCwd(pid: pid), !cwd.isEmpty, cwd != "/" else {
                continue
            }

            consumedPids.insert(pid)
            let server = DevServer(
                primaryPid: pid,
                pids: [pid],
                command: proc.command,
                displayCommand: proc.command,
                path: cwd,
                ports: []
            )
            candidateServers.append(server)
        }

        // Sort by folder name and port
        return candidateServers.sorted {
            if $0.folderName == $1.folderName {
                return ($0.primaryPort ?? 0) < ($1.primaryPort ?? 0)
            }
            return $0.folderName.localizedStandardCompare($1.folderName) == .orderedAscending
        }
    }

    private static func getCwd(pid: pid_t) -> String? {
        var pathInfo = proc_vnodepathinfo()
        let size = proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &pathInfo, Int32(MemoryLayout<proc_vnodepathinfo>.size))
        if size > 0 {
            return withUnsafePointer(to: &pathInfo.pvi_cdir.vip_path) { ptr in
                ptr.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) { cStr in
                    let str = String(cString: cStr).trimmingCharacters(in: .whitespacesAndNewlines)
                    return str.isEmpty ? nil : str
                }
            }
        }
        return nil
    }

    private static func getAllProcesses() -> [RawProcess] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-ww", "-eo", "pid,ppid,args"]
        let pipe = Pipe()
        task.standardOutput = pipe
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            guard let output = String(data: data, encoding: .utf8) else { return [] }

            var list: [RawProcess] = []
            let lines = output.components(separatedBy: .newlines)
            for line in lines.dropFirst() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { continue }
                let parts = trimmed.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
                guard parts.count == 3,
                      let pid = pid_t(parts[0]),
                      let ppid = pid_t(parts[1]) else { continue }
                list.append(RawProcess(pid: pid, ppid: ppid, command: String(parts[2])))
            }
            return list
        } catch {
            return []
        }
    }

    private static func getListeningPorts() -> [pid_t: [Int]] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        task.arguments = ["-nP", "-iTCP", "-sTCP:LISTEN"]
        let pipe = Pipe()
        task.standardOutput = pipe
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            guard let output = String(data: data, encoding: .utf8) else { return [:] }

            var ports: [pid_t: [Int]] = [:]
            for line in output.components(separatedBy: .newlines) {
                let parts = line.split(whereSeparator: { $0.isWhitespace })
                guard parts.count >= 9, let pid = pid_t(parts[1]) else { continue }
                let name = String(parts[8])
                if let colonIdx = name.lastIndex(of: ":") {
                    let portStr = name[name.index(after: colonIdx)...]
                    if let port = Int(portStr) {
                        if !ports[pid, default: []].contains(port) {
                            ports[pid, default: []].append(port)
                        }
                    }
                }
            }
            return ports
        } catch {
            return [:]
        }
    }
}

@MainActor
public final class ProcessManager: ObservableObject {
    @Published public private(set) var servers: [DevServer] = []
    @Published public private(set) var isScanning: Bool = false
    @Published public private(set) var lastScanTime: Date = Date()

    private var timer: AnyCancellable?
    private var scanTask: Task<Void, Never>?

    public init(mockServers: [DevServer]? = nil) {
        if let mock = mockServers {
            self.servers = mock
        } else {
            startTimer()
            scan()
        }
    }

    deinit {
        timer?.cancel()
        scanTask?.cancel()
    }

    public func startTimer() {
        timer?.cancel()
        timer = Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.scan()
            }
    }

    public func scan() {
        guard !isScanning else { return }
        isScanning = true

        scanTask?.cancel()
        scanTask = Task {
            let detected = await Task.detached(priority: .userInitiated) {
                ProcessScanner.detectDevServers()
            }.value

            self.servers = detected
            self.lastScanTime = Date()
            self.isScanning = false
        }
    }

    public func killServer(_ server: DevServer) {
        // Optimistically remove from list for snappy UI
        servers.removeAll { $0.id == server.id }
        
        Task {
            await Task.detached(priority: .userInitiated) {
                ProcessScanner.terminateProcesses(pids: server.pids)
            }.value
            
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
            self.scan()
        }
    }

    public func killAll() {
        let allPids = servers.flatMap { $0.pids }
        servers.removeAll()

        Task {
            await Task.detached(priority: .userInitiated) {
                ProcessScanner.terminateProcesses(pids: allPids)
            }.value

            try? await Task.sleep(nanoseconds: 300_000_000)
            self.scan()
        }
    }
}
