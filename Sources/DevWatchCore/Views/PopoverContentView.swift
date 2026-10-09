import SwiftUI

public struct PopoverContentView: View {
    @ObservedObject public var processManager: ProcessManager
    public let useVisualEffect: Bool
    public let onQuit: () -> Void

    public init(processManager: ProcessManager, useVisualEffect: Bool = true, onQuit: @escaping () -> Void) {
        self.processManager = processManager
        self.useVisualEffect = useVisualEffect
        self.onQuit = onQuit
    }

    public var body: some View {
        VStack(spacing: 0) {
            HeaderView(processManager: processManager, onQuit: onQuit)

            Divider()

            if processManager.servers.isEmpty {
                EmptyStateView()
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 8) {
                        ForEach(processManager.servers) { server in
                            ServerCardView(server: server) {
                                processManager.killServer(server)
                            }
                        }
                    }
                    .padding(12)
                }
                .frame(maxHeight: 520)
            }

            Divider()

            FooterView(processManager: processManager, onQuit: onQuit)
        }
        .frame(width: 460)
        .background {
            if useVisualEffect {
                VisualEffectView().ignoresSafeArea()
            } else {
                Color(nsColor: .windowBackgroundColor).ignoresSafeArea()
            }
        }
    }
}

// macOS Vibrancy VisualEffectView
struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .popover
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
