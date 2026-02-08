import AppKit
import Foundation

private final class FinickySwiftAppDelegate: NSObject, NSApplicationDelegate {
    private let forceOpenWindow: Bool
    private let showMenuItem: Bool
    private let keepRunning: Bool

    private var receivedURL = false
    private var statusItem: NSStatusItem?

    init(forceOpenWindow: Bool, showMenuItem: Bool, keepRunning: Bool) {
        self.forceOpenWindow = forceOpenWindow
        self.showMenuItem = showMenuItem
        self.keepRunning = keepRunning
        super.init()
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        let manager = NSAppleEventManager.shared()
        manager.setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        var openWindow = forceOpenWindow
        if !openWindow {
            openWindow = !receivedURL
        }

        if showMenuItem && (keepRunning || !receivedURL) {
            createStatusItem()
        }

        QueueWindowDisplay(openWindow ? 1 : 0)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            ShowConfigWindow()
        }
        return true
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        receivedURL = true
        let fileURL = URL(fileURLWithPath: filename)
        forwardURL(fileURL.absoluteString, openInBackground: false, opener: nil)
        return true
    }

    func application(_ application: NSApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([any NSUserActivityRestoring]) -> Void) -> Bool {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else {
            return false
        }

        receivedURL = true
        forwardURL(url.absoluteString, openInBackground: false, opener: nil)
        return true
    }

    func application(_ application: NSApplication, didFailToContinueUserActivityWithType userActivityType: String, error: any Error) {
    }

    @objc private func showWindowAction(_ sender: Any?) {
        ShowConfigWindow()
    }

    @objc private func editConfigAction(_ sender: Any?) {
        guard let cPath = GetCurrentConfigPath() else {
            return
        }

        let path = String(cString: cPath)
        free(cPath)

        guard !path.isEmpty else {
            return
        }

        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    @objc private func handleGetURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        let pid = event.attributeDescriptor(forKeyword: keySenderPIDAttr)?.int32Value ?? 0
        let openerApp = NSRunningApplication(processIdentifier: pid_t(pid))
        let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue ?? ""

        guard !urlString.isEmpty else {
            return
        }

        receivedURL = true

        let frontApp = NSWorkspace.shared.frontmostApplication
        let finickyIsInFront = !keepRunning || frontApp == NSRunningApplication.current
        forwardURL(urlString, openInBackground: !finickyIsInFront, opener: openerApp)
    }

    private func createStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.toolTip = "Finicky"

        if let iconPath = Bundle.main.path(forResource: "menu-bar", ofType: "icns"),
           let image = NSImage(contentsOfFile: iconPath) {
            image.isTemplate = true
            image.size = NSSize(width: 18, height: 18)
            item.button?.image = image
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "Show Window", action: #selector(showWindowAction(_:)), keyEquivalent: "")

        if let path = GetCurrentConfigPath() {
            free(path)
            menu.addItem(withTitle: "Edit config", action: #selector(editConfigAction(_:)), keyEquivalent: "")
            menu.addItem(NSMenuItem.separator())
        }

        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item
    }

    private func forwardURL(_ urlString: String, openInBackground: Bool, opener: NSRunningApplication?) {
        let openerName = opener?.localizedName
        let openerBundle = opener?.bundleIdentifier
        let openerPath = opener?.bundleURL?.path

        let cURL = strdup(urlString)
        defer { free(cURL) }

        let cName = duplicatedCString(openerName)
        let cBundle = duplicatedCString(openerBundle)
        let cPath = duplicatedCString(openerPath)

        defer {
            if let cName {
                free(cName)
            }
            if let cBundle {
                free(cBundle)
            }
            if let cPath {
                free(cPath)
            }
        }

        HandleURL(cURL, cName, cBundle, cPath, openInBackground)
    }

    private func duplicatedCString(_ value: String?) -> UnsafeMutablePointer<CChar>? {
        guard let value else {
            return nil
        }
        return strdup(value)
    }
}

@_cdecl("RunSwiftApp")
public func RunSwiftApp(_ forceOpenWindow: Bool, _ showStatusItem: Bool, _ keepRunning: Bool) {
    let launch: () -> Void = {
        _ = NSApplication.shared
        let delegate = FinickySwiftAppDelegate(
            forceOpenWindow: forceOpenWindow,
            showMenuItem: showStatusItem,
            keepRunning: keepRunning
        )
        NSApp.delegate = delegate
        NSApp.finishLaunching()
        NSApp.run()
    }

    if Thread.isMainThread {
        launch()
    } else {
        DispatchQueue.main.sync(execute: launch)
    }
}
