import SwiftUI

public struct EmptyStateView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "server.rack")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(.secondary.opacity(0.7))

            VStack(spacing: 4) {
                Text("No Dev Servers Running")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)

                Text("Start a dev server with npm run dev, vite, next, etc. It will appear here automatically.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 180)
        .padding(.vertical, 24)
    }
}
