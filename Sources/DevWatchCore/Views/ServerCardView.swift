import SwiftUI

public struct ServerCardView: View {
    public let server: DevServer
    public let onKill: () -> Void

    @State private var isHovered: Bool = false
    @State private var copiedCommand: Bool = false
    @State private var copiedPath: Bool = false

    public init(server: DevServer, onKill: @escaping () -> Void) {
        self.server = server
        self.onKill = onKill
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Top row: Folder name, Port tag, PID, and Kill Button
            HStack(alignment: .center, spacing: 8) {
                // Folder icon & Project Name
                HStack(spacing: 5) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.accentColor)
                    Text(server.folderName)
                        .font(.system(size: 13, weight: .bold))
                        .lineLimit(1)
                }

                // Port badge (if available)
                if let port = server.primaryPort {
                    Button(action: { server.openInBrowser() }) {
                        HStack(spacing: 3) {
                            Image(systemName: "globe")
                                .font(.system(size: 9))
                            Text(verbatim: ":\(port)")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.18))
                        .foregroundColor(.green)
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .help("Open http://localhost:\(port) in browser")
                }

                // PID tag
                Text(verbatim: "PID \(server.primaryPid)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.06))
                    .cornerRadius(4)

                Spacer()

                // Kill Button
                Button(action: onKill) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                        Text("Kill")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(isHovered ? 0.9 : 0.8))
                    .foregroundColor(.white)
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)
                .help("Terminate this dev server (PIDs: \(server.pids.map(String.init).joined(separator: ", ")))")
            }

            // Command section
            HStack(alignment: .center, spacing: 6) {
                Image(systemName: "terminal")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                Text(server.displayCommand)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .foregroundColor(.primary)
                    .help(server.command)

                Spacer()

                Button(action: {
                    server.copyCommand()
                    copiedCommand = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        copiedCommand = false
                    }
                }) {
                    Image(systemName: copiedCommand ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 10))
                        .foregroundColor(copiedCommand ? .green : .secondary)
                }
                .buttonStyle(.plain)
                .help(copiedCommand ? "Copied!" : "Copy command")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.primary.opacity(0.04))
            .cornerRadius(4)

            // Path section
            HStack(alignment: .center, spacing: 6) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                Text(server.displayPath)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                // Reveal in Finder button
                Button(action: { server.openInFinder() }) {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Reveal folder in Finder")

                // Copy Path button
                Button(action: {
                    server.copyPath()
                    copiedPath = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        copiedPath = false
                    }
                }) {
                    Image(systemName: copiedPath ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 10))
                        .foregroundColor(copiedPath ? .green : .secondary)
                }
                .buttonStyle(.plain)
                .help(copiedPath ? "Copied!" : "Copy full path")
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isHovered ? Color.accentColor.opacity(0.4) : Color.primary.opacity(0.08), lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}
