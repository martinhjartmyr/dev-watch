import AppKit
import SwiftUI
import Combine

@MainActor
public final class StatusBarController: NSObject {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let processManager: ProcessManager
    private var cancellables = Set<AnyCancellable>()
    private var eventMonitor: Any?

    public init(processManager: ProcessManager) {
        self.processManager = processManager
        super.init()
        setupStatusItem()
        setupPopover()
        setupBindings()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover)
            updateStatusItem(count: 0)
        }
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 460, height: 480)
        
        let contentView = PopoverContentView(
            processManager: processManager,
            onQuit: {
                NSApplication.shared.terminate(nil)
            }
        )
        popover.contentViewController = NSHostingController(rootView: contentView)
    }

    private func setupBindings() {
        processManager.$servers
            .receive(on: DispatchQueue.main)
            .sink { [weak self] servers in
                self?.updateStatusItem(count: servers.count)
            }
            .store(in: &cancellables)
    }

    private func updateStatusItem(count: Int) {
        guard let button = statusItem.button else { return }
        
        let image = createBadgeImage(count: count)
        button.image = image
        button.imagePosition = .imageOnly
        button.toolTip = count == 0
            ? "DevWatch: No Node dev servers running"
            : "DevWatch: \(count) Node dev server\(count == 1 ? "" : "s") running"
    }

    private func createBadgeImage(count: Int) -> NSImage {
        let countStr = "\(count)"
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .bold)
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: count > 0 ? NSColor.white : NSColor(white: 0.9, alpha: 0.85)
        ]
        let textSize = (countStr as NSString).size(withAttributes: textAttributes)

        let padH: CGFloat = 5.0
        let badgeW = max(18.0, textSize.width + padH * 2)
        let badgeH: CGFloat = 16.0
        let totalSize = NSSize(width: badgeW + 4, height: 22.0)

        let image = NSImage(size: totalSize, flipped: false) { rect in
            let badgeRect = NSRect(
                x: (rect.width - badgeW) / 2.0,
                y: (rect.height - badgeH) / 2.0,
                width: badgeW,
                height: badgeH
            )
            
            let path = NSBezierPath(roundedRect: badgeRect, xRadius: badgeH / 2, yRadius: badgeH / 2)
            
            if count > 0 {
                // Vibrant emerald green badge when servers are running
                NSColor(red: 0.16, green: 0.72, blue: 0.38, alpha: 1.0).setFill()
            } else {
                // Subtle dark gray / translucent badge when idle
                NSColor(white: 0.45, alpha: 0.35).setFill()
            }
            path.fill()

            let textY = badgeRect.origin.y + (badgeH - textSize.height) / 2.0 + 0.5
            let textRect = NSRect(
                x: badgeRect.origin.x + (badgeW - textSize.width) / 2.0,
                y: textY,
                width: textSize.width,
                height: textSize.height
            )
            
            (countStr as NSString).draw(in: textRect, withAttributes: textAttributes)
            return true
        }
        
        image.isTemplate = false
        return image
    }

    @objc private func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        
        // Refresh immediately upon opening
        processManager.scan()
        
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        
        // Ensure popover window becomes key so buttons and shortcuts work
        popover.contentViewController?.view.window?.makeKey()

        // Monitor clicks outside the popover
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePopover()
        }
    }

    private func closePopover() {
        popover.performClose(nil)
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}
