import AppKit
import Foundation
import WebKit

private enum HostedFileContent {
    case text(String)
    case data(Data)
}

private var hostedHTMLContent: String?
private var hostedFiles: [String: HostedFileContent] = [:]
private var sharedWindowController: SwiftWindowController?

private final class SwiftWindowController: NSObject, WKScriptMessageHandler, WKURLSchemeHandler, WKNavigationDelegate {
    private var window: NSWindow?
    private var webView: WKWebView?

    private var tabContainer: FinickySwiftTabContainerView?
    private var overviewView: FinickySwiftOverviewView?
    private var configView: FinickySwiftConfigFormView?

    private var cloudSyncEnabled = false
    private var cloudSyncInFlight = false
    private var saveInFlight = false
    private var previewInFlight = false
    private var didRequestInitialData = false

    func showWindow() {
        DispatchQueue.main.async {
            if self.window == nil {
                self.setupWindow()
                self.setupMenu()
            }

            self.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            self.requestInitialDataIfNeededAsync()
        }
    }

    func closeWindow() {
        DispatchQueue.main.async {
            self.window?.close()
        }
    }

    func sendMessageToWebView(_ message: String) {
        DispatchQueue.main.async {
            self.deliverMessageOnMainThread(message)
        }
    }

    private func setupWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Finicky"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.center()
        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear
        window.minSize = NSSize(width: 860, height: 560)
        window.maxSize = NSSize(width: 1400, height: 1000)

        let rootView = NSView(frame: window.contentView?.bounds ?? .zero)
        rootView.autoresizingMask = [.width, .height]

        let tabContainer = FinickySwiftTabContainerView(frame: rootView.bounds)
        tabContainer.autoresizingMask = [.width, .height]

        let overviewView = FinickySwiftOverviewView(frame: tabContainer.bounds)
        overviewView.onICloudToggleRequested = { [weak self] in
            self?.onCloudSyncAction()
        }

        let configView = FinickySwiftConfigFormView(frame: tabContainer.bounds)
        configView.onICloudToggleRequested = { [weak self] in
            self?.onCloudSyncAction()
        }
        configView.onRequestChromiumProfiles = { [weak self] in
            self?.sendNativeMessage(["type": "getChromiumProfiles"])
        }
        configView.onFormatRequested = { [weak self] in
            self?.onFormat()
        }
        configView.onSaveRequested = { [weak self] in
            self?.onSave()
        }

        tabContainer.addTab(withIdentifier: "overviewNative", label: "Overview", view: overviewView)
        tabContainer.addTab(withIdentifier: "configNative", label: "Config", view: configView)
        tabContainer.addTab(withIdentifier: "webLegacy", label: "Web (Legacy)", view: buildWebViewContainer(frame: tabContainer.bounds))

        rootView.addSubview(tabContainer)
        window.contentView = rootView
        window.makeFirstResponder(nil)

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { _ in
            WindowDidClose()
        }

        self.window = window
        self.tabContainer = tabContainer
        self.overviewView = overviewView
        self.configView = configView

        WindowIsReady()
    }

    private func buildWebViewContainer(frame: NSRect) -> NSView {
        let container = NSView(frame: frame)
        container.autoresizingMask = [.width, .height]

        let config = WKWebViewConfiguration()
        config.userContentController.add(self, name: "finicky")
        config.setURLSchemeHandler(self, forURLScheme: "finicky-assets")

        let webView = WKWebView(frame: container.bounds, configuration: config)
        webView.autoresizingMask = [.width, .height]
        webView.navigationDelegate = self
        webView.configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")

        if let html = hostedHTMLContent {
            let baseURL = URL(string: "finicky-assets://local/")!
            webView.loadHTMLString(html, baseURL: baseURL)
        }

        container.addSubview(webView)
        self.webView = webView
        return container
    }

    private func setupMenu() {
        guard let window else { return }

        let mainMenu = NSMenu()
        NSApp.mainMenu = mainMenu

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu

        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = NSApp
        appMenu.addItem(quitItem)

        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: "File")
        fileMenuItem.submenu = fileMenu

        let closeItem = NSMenuItem(title: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        closeItem.target = window
        fileMenu.addItem(closeItem)

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu

        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
    }

    private func requestInitialDataIfNeededAsync() {
        if didRequestInitialData {
            return
        }
        didRequestInitialData = true
        DispatchQueue.main.async { [weak self] in
            self?.sendNativeMessage(["type": "getICloudSyncStatus"])
            self?.sendNativeMessage(["type": "getConfigBuilderData"])
        }
    }

    private func sendNativeMessage(_ message: [String: Any]) {
        guard JSONSerialization.isValidJSONObject(message),
              let data = try? JSONSerialization.data(withJSONObject: message),
              let jsonString = String(data: data, encoding: .utf8) else {
            return
        }

        let cMessage = strdup(jsonString)
        DispatchQueue.global(qos: .userInitiated).async {
            HandleWebViewMessage(cMessage)
            free(cMessage)
        }
    }

    private func deliverMessageOnMainThread(_ message: String) {
        applyIncomingBackendMessage(message)

        guard let webView else { return }

        let escaped = message
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let js = "finicky.receiveMessage(\"\(escaped)\")"
        if !webView.isLoading {
            webView.evaluateJavaScript(js, completionHandler: nil)
        }
    }

    private func applyIncomingBackendMessage(_ message: String) {
        guard let data = message.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = obj["type"] as? String else {
            return
        }

        let payload = obj["message"]

        switch type {
        case "config":
            if let dict = payload as? NSDictionary {
                overviewView?.updateConfigWithMessage(dict)
            }

        case "updateInfo":
            if let dict = payload as? NSDictionary {
                overviewView?.updateUpdateInfo(dict)
            }

        case "configBuilderData":
            if let dict = payload as? [String: Any] {
                configView?.setBrowserOptions(dict["browsers"] as? NSArray ?? [])
                configView?.setChromiumProfileGroups(dict["profiles"] as? NSArray ?? [])
                configView?.setConfigPath(dict["configPath"] as? String ?? "")
                configView?.applyDraft(dict["draft"] as? NSDictionary ?? [:])
                configView?.setBuilderError(dict["error"] as? String ?? "")
            }

        case "chromiumProfiles":
            if let dict = payload as? [String: Any] {
                configView?.setChromiumProfileGroups(dict["groups"] as? NSArray ?? [])
            }

        case "previewGeneratedConfigResult":
            previewInFlight = false
            configView?.setPreviewLoading(false)

            if let dict = payload as? [String: Any], (dict["ok"] as? Bool ?? false) {
                configView?.setPreviewContent(dict["content"] as? String ?? "")
                configView?.setBuilderError("")
            } else {
                let err = (payload as? [String: Any])?["error"] as? String ?? "Format failed"
                configView?.setBuilderError(err)
            }

        case "saveGeneratedConfigResult":
            saveInFlight = false
            configView?.setSaveLoading(false)

            if let dict = payload as? [String: Any], (dict["ok"] as? Bool ?? false) {
                var message = dict["message"] as? String ?? "Saved"
                let backupPath = dict["backupPath"] as? String ?? ""
                if !backupPath.isEmpty {
                    message += " | Backup: \(backupPath)"
                }
                configView?.setBuilderStatus(message)
                configView?.setBuilderError("")
                sendNativeMessage(["type": "getConfigBuilderData"])
            } else {
                let err = (payload as? [String: Any])?["error"] as? String ?? "Save failed"
                configView?.setBuilderStatus("")
                configView?.setBuilderError(err)
            }

        case "cloudSyncStatus":
            handleCloudSyncStatus(payload as? [String: Any] ?? [:], error: (payload as? [String: Any])?["error"] as? String ?? "")

        case "cloudSyncResult":
            cloudSyncInFlight = false
            overviewView?.setICloudToggleLoading(false)
            configView?.setICloudToggleLoading(false)

            let dict = payload as? [String: Any] ?? [:]
            if dict["ok"] as? Bool ?? false {
                let message = dict["message"] as? String ?? ""
                let backupPath = dict["backupPath"] as? String ?? ""
                overviewView?.setICloudResultMessage(message, backupPath: backupPath, error: "")
                configView?.setICloudResultMessage(message, backupPath: backupPath, error: "")
                sendNativeMessage(["type": "getICloudSyncStatus"])
            } else {
                let err = dict["error"] as? String ?? "unknown"
                overviewView?.setICloudResultMessage("", backupPath: "", error: err)
                configView?.setICloudResultMessage("", backupPath: "", error: err)
                handleCloudSyncStatus(["enabled": cloudSyncEnabled], error: err)
            }

        default:
            break
        }
    }

    private func handleCloudSyncStatus(_ status: [String: Any], error: String) {
        cloudSyncEnabled = status["enabled"] as? Bool ?? false
        let configPath = status["configPath"] as? String ?? ""
        let cloudPath = status["cloudPath"] as? String ?? ""

        overviewView?.updateICloudEnabled(cloudSyncEnabled, configPath: configPath, cloudPath: cloudPath, error: error)
        configView?.updateICloudWithEnabled(cloudSyncEnabled, configPath: configPath, cloudPath: cloudPath, error: error)
    }

    private func onFormat() {
        if previewInFlight { return }

        var errorMessage: NSString?
        guard let payload = configView?.buildRequestPayload(withError: &errorMessage) as? [String: Any] else {
            configView?.setBuilderError(errorMessage as String? ?? "Invalid request")
            return
        }

        previewInFlight = true
        configView?.setPreviewLoading(true)

        var msg = payload
        msg["type"] = "previewGeneratedConfig"
        sendNativeMessage(msg)
    }

    private func onSave() {
        if saveInFlight { return }

        var errorMessage: NSString?
        guard let payload = configView?.buildRequestPayload(withError: &errorMessage) as? [String: Any] else {
            configView?.setBuilderError(errorMessage as String? ?? "Invalid request")
            return
        }

        saveInFlight = true
        configView?.setSaveLoading(true)

        var msg = payload
        msg["type"] = "saveGeneratedConfig"
        sendNativeMessage(msg)
    }

    private func onCloudSyncAction() {
        if cloudSyncInFlight { return }

        cloudSyncInFlight = true
        overviewView?.setICloudToggleLoading(true)
        configView?.setICloudToggleLoading(true)

        if cloudSyncEnabled {
            sendNativeMessage(["type": "disableICloudSync"])
        } else {
            sendNativeMessage(["type": "enableICloudSync"])
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if let body = message.body as? String {
            let cMessage = strdup(body)
            DispatchQueue.global(qos: .userInitiated).async {
                HandleWebViewMessage(cMessage)
                free(cMessage)
            }
            return
        }

        if JSONSerialization.isValidJSONObject(message.body),
           let data = try? JSONSerialization.data(withJSONObject: message.body),
           let json = String(data: data, encoding: .utf8) {
            let cMessage = strdup(json)
            DispatchQueue.global(qos: .userInitiated).async {
                HandleWebViewMessage(cMessage)
                free(cMessage)
            }
        }
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        guard let requestURL = urlSchemeTask.request.url else { return }

        var path = requestURL.path
        if path.hasPrefix("/") { path.removeFirst() }
        if path.hasPrefix("local/") { path.removeFirst(6) }

        guard let content = hostedFiles[path] else {
            urlSchemeTask.didFailWithError(NSError(domain: NSURLErrorDomain, code: NSURLErrorResourceUnavailable))
            return
        }

        let data: Data
        switch content {
        case .text(let text):
            data = text.data(using: .utf8) ?? Data()
        case .data(let binary):
            data = binary
        }

        let mimeType: String
        if path.hasSuffix(".css") {
            mimeType = "text/css"
        } else if path.hasSuffix(".js") {
            mimeType = "application/javascript"
        } else if path.hasSuffix(".png") {
            mimeType = "image/png"
        } else {
            mimeType = "text/plain"
        }

        let response = URLResponse(url: requestURL, mimeType: mimeType, expectedContentLength: data.count, textEncodingName: nil)
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        WindowIsReady()
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        if url.scheme == "finicky-assets" {
            decisionHandler(.allow)
            return
        }

        if navigationAction.navigationType == .linkActivated {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
            return
        }

        decisionHandler(.allow)
    }
}

@_cdecl("ShowWindow")
public func ShowWindow() {
    DispatchQueue.main.async {
        if sharedWindowController == nil {
            sharedWindowController = SwiftWindowController()
        }
        sharedWindowController?.showWindow()
    }
}

@_cdecl("CloseWindow")
public func CloseWindow() {
    DispatchQueue.main.async {
        sharedWindowController?.closeWindow()
    }
}

@_cdecl("SendMessageToWebView")
public func SendMessageToWebView(_ message: UnsafePointer<CChar>?) {
    guard let message else { return }
    let text = String(cString: message)
    DispatchQueue.main.async {
        sharedWindowController?.sendMessageToWebView(text)
    }
}

@_cdecl("SetHTMLContent")
public func SetHTMLContent(_ content: UnsafePointer<CChar>?) {
    guard let content else { return }
    hostedHTMLContent = String(cString: content)
}

@_cdecl("SetFileContent")
public func SetFileContent(_ path: UnsafePointer<CChar>?, _ content: UnsafePointer<CChar>?) {
    guard let path, let content else { return }
    let key = String(cString: path)
    if key.hasSuffix(".png") {
        let bytes = Data(bytes: content, count: strlen(content))
        hostedFiles[key] = .data(bytes)
    } else {
        hostedFiles[key] = .text(String(cString: content))
    }
}

@_cdecl("SetFileContentWithLength")
public func SetFileContentWithLength(_ path: UnsafePointer<CChar>?, _ content: UnsafePointer<CChar>?, _ length: Int) {
    guard let path, let content else { return }
    hostedFiles[String(cString: path)] = .data(Data(bytes: content, count: max(0, length)))
}
