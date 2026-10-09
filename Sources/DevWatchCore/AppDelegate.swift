import AppKit

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var processManager: ProcessManager?
    private var statusBarController: StatusBarController?

    public override init() {
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        let pm = ProcessManager()
        self.processManager = pm
        self.statusBarController = StatusBarController(processManager: pm)
    }

    public func applicationWillTerminate(_ notification: Notification) {
        // Cleanup
    }
}
