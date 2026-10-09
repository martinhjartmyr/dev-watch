import SwiftUI

public struct FooterView: View {
    @ObservedObject public var processManager: ProcessManager
    public let onQuit: () -> Void

    @State private var isKillAllHovered: Bool = false

    public init(processManager: ProcessManager, onQuit: @escaping () -> Void) {
        self.processManager = processManager
        self.onQuit = onQuit
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Quit Button
            Button(action: onQuit) {
                HStack(spacing: 4) {
                    Image(systemName: "power")
                        .font(.system(size: 10))
                    Text("Quit")
                        .font(.system(size: 11))
                }
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Quit DevWatch")

            Spacer()

            // Kill All Button
            Button(action: { processManager.killAll() }) {
                HStack(spacing: 5) {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 12))
                    Text(processManager.servers.isEmpty ? "Kill All" : "Kill All (\(processManager.servers.count))")
                        .font(.system(size: 11, weight: .bold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(processManager.servers.isEmpty ? Color.gray.opacity(0.2) : (isKillAllHovered ? Color.red : Color.red.opacity(0.85)))
                )
                .foregroundColor(processManager.servers.isEmpty ? Color.secondary : Color.white)
            }
            .buttonStyle(.plain)
            .disabled(processManager.servers.isEmpty)
            .onHover { hovering in
                isKillAllHovered = hovering
            }
            .help(processManager.servers.isEmpty ? "No active servers to kill" : "Terminate all running Node dev servers")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.6))
    }
}
