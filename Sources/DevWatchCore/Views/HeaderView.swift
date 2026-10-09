import SwiftUI

public struct HeaderView: View {
    @ObservedObject public var processManager: ProcessManager
    public let onQuit: () -> Void
    @State private var rotationDegrees: Double = 0.0

    public init(processManager: ProcessManager, onQuit: @escaping () -> Void) {
        self.processManager = processManager
        self.onQuit = onQuit
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 8) {
            // App Title & Icon
            HStack(spacing: 6) {
                Image(systemName: "cpu")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.accentColor)
                
                Text("DevWatch")
                    .font(.system(size: 14, weight: .bold))
            }

            // Status Badge
            HStack(spacing: 4) {
                Circle()
                    .fill(processManager.servers.isEmpty ? Color.secondary.opacity(0.6) : Color.green)
                    .frame(width: 6, height: 6)
                
                Text(processManager.servers.isEmpty ? "Idle" : "\(processManager.servers.count) active")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(processManager.servers.isEmpty ? .secondary : .green)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(processManager.servers.isEmpty ? Color.primary.opacity(0.05) : Color.green.opacity(0.12))
            )

            Spacer()

            // Refresh Button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.5)) {
                    rotationDegrees += 360
                }
                processManager.scan()
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .medium))
                    .rotationEffect(.degrees(rotationDegrees))
                    .foregroundColor(.secondary)
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Refresh process list")
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }
}
