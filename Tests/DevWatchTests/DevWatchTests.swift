import XCTest
import SwiftUI
@testable import DevWatchCore

final class DevWatchTests: XCTestCase {
    func testDevServerModelFormatting() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let server = DevServer(
            primaryPid: 12345,
            pids: [12345],
            command: "\(home)/.nvm/versions/node/v20.0.0/bin/node server.js",
            path: "\(home)/Projects/my-app",
            ports: [5173]
        )

        XCTAssertEqual(server.primaryPort, 5173)
        XCTAssertEqual(server.folderName, "my-app")
        XCTAssertEqual(server.displayPath, "~/Projects/my-app")
        XCTAssertEqual(server.displayCommand, "node server.js")
    }

    func testCommandCleaning() {
        XCTAssertEqual(DevServer.cleanCommand("node index.js"), "node index.js")
        XCTAssertEqual(DevServer.cleanCommand("/opt/homebrew/bin/node index.js"), "node index.js")
        XCTAssertEqual(DevServer.cleanCommand("npm run dev"), "npm run dev")

        // Long pnpm/node_modules path
        let longPnpm = "/usr/local/bin/node /Users/developer/Projects/demo-app/node_modules/.pnpm/@rocicorp+zero@0.25.12_@opentelemetry+core@2.11.0_@opentelemetry+api@1.9.1_/node_modules/@rocicorp/zero/out/zero-cache/src/server/syncer.js serving --upstream-max-conns-per-worker 2 --cvr-max-conns-per-worker 2"
        let cleaned = DevServer.cleanCommand(longPnpm, cwd: "/Users/developer/Projects/demo-app")
        XCTAssertEqual(cleaned, "node @rocicorp/zero/.../syncer.js serving --upstream-max-conns-per-worker 2 --cvr-max-conns-per-worker 2")

        // Relative path in cwd
        let inCwd = "/usr/local/bin/node /Users/developer/Projects/my-app/server/index.js"
        XCTAssertEqual(DevServer.cleanCommand(inCwd, cwd: "/Users/developer/Projects/my-app"), "node server/index.js")
    }

    @MainActor
    func testLiveDevServerDetectionAndTermination() async throws {
        // Spawn a real test Node server on port 9482
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let scriptFile = tempDir.appendingPathComponent("test-server.js")
        let scriptContent = """
        const http = require('http');
        const s = http.createServer((q, r) => r.end('ok'));
        s.listen(9482);
        setInterval(() => {}, 1000);
        """
        try scriptContent.write(to: scriptFile, atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["node", scriptFile.path]
        process.currentDirectoryURL = tempDir
        try process.run()

        // Wait 1.5 seconds for the server to bind port
        try await Task.sleep(nanoseconds: 1_500_000_000)

        let pm = ProcessManager()
        pm.scan()

        // Wait for scan to complete
        var found = false
        for _ in 0..<10 {
            try await Task.sleep(nanoseconds: 300_000_000)
            if let match = pm.servers.first(where: { $0.ports.contains(9482) }) {
                XCTAssertEqual(match.folderName, tempDir.lastPathComponent)
                found = true
                // Test killing it
                pm.killServer(match)
                break
            }
        }

        XCTAssertTrue(found, "DevWatch should detect the running test server on port 9482")

        // Wait for termination
        try await Task.sleep(nanoseconds: 1_000_000_000)

        // Ensure process is dead
        process.terminate()
    }

    @MainActor
    func testGenerateScreenshot() throws {
        let mockServers = [
            DevServer(
                primaryPid: 48210,
                pids: [48210],
                command: "npx vite --port 5173",
                displayCommand: "vite --port 5173",
                path: "~/Projects/frontend-dashboard",
                ports: [5173]
            ),
            DevServer(
                primaryPid: 51902,
                pids: [51902],
                command: "npm run dev",
                displayCommand: "next dev",
                path: "~/Projects/ecommerce-web",
                ports: [3000]
            ),
            DevServer(
                primaryPid: 53891,
                pids: [53891],
                command: "bun run dev",
                displayCommand: "bun run dev",
                path: "~/Projects/backend-auth",
                ports: [8080]
            )
        ]

        let pm = ProcessManager(mockServers: mockServers)
        let heroView = ScreenshotHeroView(processManager: pm)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 480),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.appearance = NSAppearance(named: .darkAqua)
        window.isOpaque = false
        window.backgroundColor = .clear

        let hostingView = NSHostingView(rootView: heroView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 580, height: 480)
        window.contentView = hostingView
        hostingView.layoutSubtreeIfNeeded()

        guard let rep = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            XCTFail("Failed to create bitmap rep")
            return
        }
        hostingView.cacheDisplay(in: hostingView.bounds, to: rep)

        guard let pngData = rep.representation(using: .png, properties: [:]) else {
            XCTFail("Failed to encode PNG")
            return
        }

        let projectDir = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let assetsDir = projectDir.appendingPathComponent("assets")
        try FileManager.default.createDirectory(at: assetsDir, withIntermediateDirectories: true)
        
        let outputURL = assetsDir.appendingPathComponent("screenshot.png")
        try pngData.write(to: outputURL)
        print("📸 Screenshot saved to: \(outputURL.path)")
    }
}

private struct PopoverArrow: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct ScreenshotHeroView: View {
    @ObservedObject var processManager: ProcessManager

    var body: some View {
        VStack(spacing: 0) {
            // Simulated macOS Menu Bar
            HStack(spacing: 14) {
                HStack(spacing: 6) {
                    Image(systemName: "applelogo")
                        .font(.system(size: 13, weight: .semibold))
                    Text("DevWatch")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(.white.opacity(0.9))

                Spacer()

                // DevWatch Active Badge in Menu Bar
                HStack(spacing: 4) {
                    Text("3")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 2.5)
                .background(
                    Capsule()
                        .fill(Color(red: 0.16, green: 0.72, blue: 0.38))
                )

                Image(systemName: "wifi")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))

                Image(systemName: "battery.100")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))

                Text("9:41 AM")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(.horizontal, 18)
            .frame(height: 32)
            .background(Color(red: 0.12, green: 0.13, blue: 0.15))

            // Popover Dropdown
            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    PopoverArrow()
                        .fill(Color(red: 0.18, green: 0.19, blue: 0.22))
                        .frame(width: 16, height: 8)
                        .padding(.trailing, 96)

                    PopoverContentView(processManager: processManager, useVisualEffect: false, onQuit: {})
                        .background(Color(red: 0.18, green: 0.19, blue: 0.22))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.55), radius: 30, x: 0, y: 15)
                }
                .padding(.trailing, 16)
            }
            .padding(.top, 2)
            .padding(.bottom, 24)
        }
        .frame(width: 580)
        .background(
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.09, blue: 0.11), Color(red: 0.05, green: 0.06, blue: 0.08)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .preferredColorScheme(.dark)
    }
}
