import AppKit
import Foundation

@objcMembers
final class SwiftSidebarTabButton: NSButton {
    var tabIdentifier = ""
}

@objc(FinickySwiftTabContainerView)
public final class FinickySwiftTabContainerView: NSView {
    private let rootBackground = NSVisualEffectView()
    private let sidebarGlass = NSVisualEffectView()
    private let contentGlass = NSVisualEffectView()
    private let sidebarContent = NSView()
    private let appTitleLabel = NSTextField(labelWithString: "Finicky")
    private let footerLabel = NSTextField(labelWithString: "Native Swift")
    private let searchField = NSSearchField()
    private let buttonList = NSView()
    private let contentHost = NSView()

    private var tabViews: [String: NSView] = [:]
    private var tabButtons: [SwiftSidebarTabButton] = []
    private var selectedIdentifier = ""

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        wantsLayer = true
        layer?.cornerRadius = 20
        layer?.masksToBounds = true

        rootBackground.material = .underWindowBackground
        rootBackground.state = .active
        rootBackground.blendingMode = .behindWindow
        rootBackground.autoresizingMask = [.width, .height]
        rootBackground.frame = bounds
        addSubview(rootBackground)

        [sidebarGlass, contentGlass].forEach {
            $0.state = .active
            $0.blendingMode = .withinWindow
            $0.wantsLayer = true
            $0.layer?.cornerRadius = 18
            $0.layer?.borderWidth = 1
            $0.layer?.borderColor = NSColor(white: 1.0, alpha: 0.18).cgColor
            rootBackground.addSubview($0)
        }

        sidebarGlass.material = .sidebar
        contentGlass.material = .contentBackground

        sidebarContent.autoresizingMask = [.width, .height]
        sidebarGlass.addSubview(sidebarContent)

        appTitleLabel.font = NSFont.systemFont(ofSize: 24, weight: .bold)
        appTitleLabel.textColor = .labelColor
        sidebarContent.addSubview(appTitleLabel)

        searchField.placeholderString = "Search"
        searchField.focusRingType = .none
        sidebarContent.addSubview(searchField)

        buttonList.autoresizingMask = [.width]
        sidebarContent.addSubview(buttonList)

        footerLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        footerLabel.textColor = .tertiaryLabelColor
        sidebarContent.addSubview(footerLabel)

        contentHost.autoresizingMask = [.width, .height]
        contentGlass.addSubview(contentHost)
    }

    public override func layout() {
        super.layout()

        let inset: CGFloat = 14
        let sidebarWidth: CGFloat = 290

        rootBackground.frame = bounds
        sidebarGlass.frame = NSRect(x: inset, y: inset, width: sidebarWidth, height: bounds.height - inset * 2)
        contentGlass.frame = NSRect(
            x: sidebarGlass.frame.maxX + inset,
            y: inset,
            width: bounds.width - sidebarWidth - inset * 3,
            height: bounds.height - inset * 2
        )

        sidebarContent.frame = sidebarGlass.bounds
        appTitleLabel.frame = NSRect(x: 18, y: sidebarGlass.bounds.height - 76, width: sidebarGlass.bounds.width - 36, height: 36)
        searchField.frame = NSRect(x: 18, y: sidebarGlass.bounds.height - 122, width: sidebarGlass.bounds.width - 36, height: 34)
        buttonList.frame = NSRect(x: 14, y: 68, width: sidebarGlass.bounds.width - 28, height: sidebarGlass.bounds.height - 206)
        footerLabel.frame = NSRect(x: 18, y: 16, width: sidebarGlass.bounds.width - 36, height: 20)
        contentHost.frame = contentGlass.bounds.insetBy(dx: 14, dy: 14)

        updateSidebarButtonFrames()
    }

    @objc public func addTab(withIdentifier identifier: String, label: String, view: NSView) {
        guard !identifier.isEmpty else { return }

        tabViews[identifier] = view
        view.isHidden = true
        view.frame = contentHost.bounds
        view.autoresizingMask = [.width, .height]
        contentHost.addSubview(view)

        let button = SwiftSidebarTabButton()
        button.tabIdentifier = identifier
        button.title = label
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.alignment = .left
        button.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        button.target = self
        button.action = #selector(onTabButtonClicked(_:))
        button.wantsLayer = true
        button.layer?.cornerRadius = 10
        button.contentTintColor = .labelColor
        buttonList.addSubview(button)
        tabButtons.append(button)

        if selectedIdentifier.isEmpty {
            setSelectedTabIdentifier(identifier)
        }

        updateSidebarButtonFrames()
    }

    @objc private func onTabButtonClicked(_ sender: SwiftSidebarTabButton) {
        setSelectedTabIdentifier(sender.tabIdentifier)
    }

    private func setSelectedTabIdentifier(_ identifier: String) {
        guard !identifier.isEmpty else { return }

        selectedIdentifier = identifier
        tabViews.forEach { key, view in
            view.isHidden = key != identifier
        }
        updateSidebarButtonStyles()
    }

    private func updateSidebarButtonFrames() {
        var y = buttonList.bounds.height - 42
        let width = buttonList.bounds.width
        for button in tabButtons {
            button.frame = NSRect(x: 0, y: y, width: width, height: 38)
            y -= 46
        }
    }

    private func updateSidebarButtonStyles() {
        for button in tabButtons {
            let selected = button.tabIdentifier == selectedIdentifier
            button.layer?.backgroundColor = selected ? NSColor(white: 1.0, alpha: 0.52).cgColor : NSColor.clear.cgColor
            button.layer?.borderWidth = selected ? 1 : 0
            button.layer?.borderColor = NSColor(white: 1.0, alpha: 0.35).cgColor
            button.font = NSFont.systemFont(ofSize: 14, weight: selected ? .semibold : .medium)
            button.contentTintColor = selected ? .labelColor : .secondaryLabelColor
        }
    }
}

@objcMembers
final class SwiftRouteDraft: NSObject {
    var routeID = UUID().uuidString
    var patterns = ""
    var browserName = ""
    var profile = ""
}

@objc(FinickySwiftOverviewView)
public final class FinickySwiftOverviewView: NSView {
    @objc public var onICloudToggleRequested: (() -> Void)?

    private let configPathLabel = NSTextField(labelWithString: "Config: (loading)")
    private let defaultBrowserLabel = NSTextField(labelWithString: "Default Browser: (loading)")
    private let handlersLabel = NSTextField(labelWithString: "Handlers: -")
    private let cloudStatusLabel = NSTextField(labelWithString: "iCloud: Loading...")
    private let cloudDetailLabel = NSTextField(labelWithString: "")
    private let cloudToggleButton = NSButton(title: "Enable iCloud Sync", target: nil, action: nil)

    private let updateLabel = NSTextField(labelWithString: "Update: Checking...")
    private let updateDetailLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        autoresizingMask = [.width, .height]
        buildUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        buildUI()
    }

    private func buildUI() {
        let scroll = NSScrollView(frame: bounds)
        scroll.autoresizingMask = [.width, .height]
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false

        let content = NSView(frame: NSRect(x: 0, y: 0, width: bounds.width, height: 980))
        content.autoresizingMask = [.width]

        let stack = NSStackView(frame: NSRect(x: 16, y: 16, width: max(520, bounds.width - 32), height: 944))
        stack.autoresizingMask = [.width]
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16

        let title = NSTextField(labelWithString: "Overview")
        title.font = NSFont.systemFont(ofSize: 36, weight: .bold)

        let subtitle = NSTextField(labelWithString: "Current config state and sync status")
        subtitle.textColor = .secondaryLabelColor

        let mainCard = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: stack.frame.width, height: 210))
        mainCard.material = .menu
        mainCard.state = .active
        mainCard.blendingMode = .withinWindow
        mainCard.wantsLayer = true
        mainCard.layer?.cornerRadius = 14
        mainCard.layer?.borderWidth = 1
        mainCard.layer?.borderColor = NSColor(white: 1.0, alpha: 0.20).cgColor

        let mainCardStack = NSStackView(frame: NSRect(x: 16, y: 16, width: mainCard.bounds.width - 32, height: 178))
        mainCardStack.autoresizingMask = [.width, .height]
        mainCardStack.orientation = .vertical
        mainCardStack.alignment = .leading
        mainCardStack.spacing = 10

        configPathLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        configPathLabel.textColor = .tertiaryLabelColor
        configPathLabel.lineBreakMode = .byTruncatingMiddle

        defaultBrowserLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        handlersLabel.textColor = .secondaryLabelColor

        cloudStatusLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        cloudDetailLabel.textColor = .secondaryLabelColor
        cloudDetailLabel.lineBreakMode = .byWordWrapping
        cloudDetailLabel.maximumNumberOfLines = 3

        cloudToggleButton.target = self
        cloudToggleButton.action = #selector(onCloudToggle(_:))
        cloudToggleButton.bezelStyle = .rounded

        updateLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        updateDetailLabel.textColor = .secondaryLabelColor

        mainCardStack.addArrangedSubview(configPathLabel)
        mainCardStack.addArrangedSubview(defaultBrowserLabel)
        mainCardStack.addArrangedSubview(handlersLabel)
        mainCardStack.addArrangedSubview(cloudStatusLabel)
        mainCardStack.addArrangedSubview(cloudDetailLabel)
        mainCardStack.addArrangedSubview(cloudToggleButton)
        mainCard.addSubview(mainCardStack)

        let updateCard = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: stack.frame.width, height: 110))
        updateCard.material = .headerView
        updateCard.state = .active
        updateCard.blendingMode = .withinWindow
        updateCard.wantsLayer = true
        updateCard.layer?.cornerRadius = 14
        updateCard.layer?.borderWidth = 1
        updateCard.layer?.borderColor = NSColor(white: 1.0, alpha: 0.16).cgColor

        let updateStack = NSStackView(frame: NSRect(x: 16, y: 16, width: updateCard.bounds.width - 32, height: 78))
        updateStack.autoresizingMask = [.width, .height]
        updateStack.orientation = .vertical
        updateStack.alignment = .leading
        updateStack.spacing = 8
        updateStack.addArrangedSubview(updateLabel)
        updateStack.addArrangedSubview(updateDetailLabel)
        updateCard.addSubview(updateStack)

        stack.addArrangedSubview(title)
        stack.addArrangedSubview(subtitle)
        stack.addArrangedSubview(mainCard)
        stack.addArrangedSubview(updateCard)

        content.addSubview(stack)
        scroll.documentView = content
        addSubview(scroll)
    }

    @objc private func onCloudToggle(_ sender: Any?) {
        onICloudToggleRequested?()
    }

    @objc public func updateConfigWithMessage(_ configMessage: NSDictionary) {
        let configPath = configMessage["configPath"] as? String ?? ""
        let browser = configMessage["defaultBrowser"] as? String ?? ""
        let handlers = configMessage["handlers"] as? NSNumber
        let rewrites = configMessage["rewrites"] as? NSNumber

        configPathLabel.stringValue = configPath.isEmpty ? "Config: (not found)" : "Config: \(configPath)"
        defaultBrowserLabel.stringValue = browser.isEmpty ? "Default Browser: (unset)" : "Default Browser: \(browser)"
        handlersLabel.stringValue = "Handlers: \(handlers?.intValue ?? 0), Rewrites: \(rewrites?.intValue ?? 0)"
    }

    @objc public func updateICloudEnabled(_ enabled: Bool, configPath: String, cloudPath: String, error: String) {
        cloudStatusLabel.stringValue = enabled ? "iCloud: Enabled" : "iCloud: Disabled"
        cloudToggleButton.title = enabled ? "Disable iCloud Sync" : "Enable iCloud Sync"

        var details: [String] = []
        if !error.isEmpty {
            details.append(error)
            cloudDetailLabel.textColor = .systemRed
        } else {
            cloudDetailLabel.textColor = .secondaryLabelColor
        }
        if !configPath.isEmpty {
            details.append("Config: \(configPath)")
        }
        if !cloudPath.isEmpty {
            details.append("iCloud: \(cloudPath)")
        }
        cloudDetailLabel.stringValue = details.joined(separator: "\n")
    }

    @objc public func setICloudToggleLoading(_ loading: Bool) {
        cloudToggleButton.isEnabled = !loading
        if loading {
            cloudToggleButton.title = cloudToggleButton.title.contains("Disable") ? "Disabling..." : "Enabling..."
        }
    }

    @objc public func setICloudResultMessage(_ message: String, backupPath: String, error: String) {
        if !error.isEmpty {
            cloudDetailLabel.textColor = .systemRed
            cloudDetailLabel.stringValue = error
            return
        }

        cloudDetailLabel.textColor = .secondaryLabelColor
        var details: [String] = []
        if !message.isEmpty {
            details.append(message)
        }
        if !backupPath.isEmpty {
            details.append("Backup: \(backupPath)")
        }
        cloudDetailLabel.stringValue = details.joined(separator: "\n")
    }

    @objc public func updateUpdateInfo(_ updateInfo: NSDictionary) {
        let hasUpdate = updateInfo["hasUpdate"] as? Bool ?? false
        let version = updateInfo["version"] as? String ?? ""
        let enabled = updateInfo["updateCheckEnabled"] as? Bool ?? true

        if !enabled {
            updateLabel.stringValue = "Update: Disabled"
            updateDetailLabel.stringValue = "Enable checkForUpdates in config to receive release checks."
            return
        }

        if hasUpdate {
            updateLabel.stringValue = "Update: New version \(version)"
            updateDetailLabel.stringValue = "A newer release is available. Open Web (Legacy) for release links."
        } else {
            updateLabel.stringValue = "Update: Up to date"
            updateDetailLabel.stringValue = version.isEmpty ? "No update data yet." : "Current latest: \(version)"
        }
    }
}

@objcMembers
final class SwiftRouteEditorRow: NSView, NSTextViewDelegate {
    var draft: SwiftRouteDraft
    var browserOptions: [[String: Any]]
    var profileGroups: [[String: Any]]
    var onRemove: ((String) -> Void)?
    var onBrowserChanged: ((String) -> Void)?

    private let patternsView = NSTextView(frame: .zero)
    private let browserPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let profilePopup = NSPopUpButton(frame: .zero, pullsDown: false)

    init(frame frameRect: NSRect, draft: SwiftRouteDraft, browserOptions: [[String: Any]], profileGroups: [[String: Any]]) {
        self.draft = draft
        self.browserOptions = browserOptions
        self.profileGroups = profileGroups
        super.init(frame: frameRect)
        buildUI()
        refreshFromModel()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildUI() {
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.borderWidth = 1
        layer?.borderColor = NSColor(white: 1.0, alpha: 0.18).cgColor
        layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.20).cgColor

        let container = NSStackView(frame: bounds.insetBy(dx: 12, dy: 10))
        container.autoresizingMask = [.width, .height]
        container.orientation = .vertical
        container.alignment = .leading
        container.spacing = 8

        let header = NSStackView()
        header.orientation = .horizontal
        header.spacing = 10

        let title = NSTextField(labelWithString: "Route")
        title.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        let removeButton = NSButton(title: "Remove", target: self, action: #selector(onRemoveTapped(_:)))
        removeButton.bezelStyle = .rounded

        header.addArrangedSubview(title)
        header.addArrangedSubview(removeButton)

        let patternsLabel = NSTextField(labelWithString: "Patterns")
        let patternsScroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 760, height: 84))
        patternsScroll.borderType = .bezelBorder
        patternsScroll.hasVerticalScroller = true
        patternsView.delegate = self
        patternsView.isAutomaticQuoteSubstitutionEnabled = false
        patternsView.font = NSFont.systemFont(ofSize: 12)
        patternsScroll.documentView = patternsView

        let browserRow = NSStackView()
        browserRow.orientation = .horizontal
        browserRow.spacing = 10

        browserPopup.target = self
        browserPopup.action = #selector(onBrowserSelected(_:))
        browserPopup.font = NSFont.systemFont(ofSize: 13)

        profilePopup.target = self
        profilePopup.action = #selector(onProfileSelected(_:))
        profilePopup.font = NSFont.systemFont(ofSize: 13)

        browserRow.addArrangedSubview(NSTextField(labelWithString: "Browser:"))
        browserRow.addArrangedSubview(browserPopup)
        browserRow.addArrangedSubview(NSTextField(labelWithString: "Profile:"))
        browserRow.addArrangedSubview(profilePopup)

        container.addArrangedSubview(header)
        container.addArrangedSubview(patternsLabel)
        container.addArrangedSubview(patternsScroll)
        container.addArrangedSubview(browserRow)

        addSubview(container)
    }

    private func refreshFromModel() {
        patternsView.string = draft.patterns

        browserPopup.removeAllItems()
        browserPopup.addItem(withTitle: "Select browser")
        for item in browserOptions {
            if let appName = item["appName"] as? String {
                browserPopup.addItem(withTitle: appName)
            }
        }

        if draft.browserName.isEmpty {
            browserPopup.selectItem(at: 0)
        } else {
            browserPopup.selectItem(withTitle: draft.browserName)
        }

        refreshProfilePopup()
    }

    private func refreshProfilePopup() {
        profilePopup.removeAllItems()
        profilePopup.addItem(withTitle: "No profile")
        profilePopup.lastItem?.representedObject = ""

        for group in profileGroups {
            guard let appName = group["appName"] as? String, appName == draft.browserName else {
                continue
            }

            guard let profiles = group["profiles"] as? [[String: Any]] else {
                continue
            }

            for profile in profiles {
                let name = profile["name"] as? String ?? ""
                let path = profile["path"] as? String ?? ""
                guard !path.isEmpty else {
                    continue
                }
                let item = NSMenuItem(title: name.isEmpty ? path : "\(name) (\(path))", action: nil, keyEquivalent: "")
                item.representedObject = path
                profilePopup.menu?.addItem(item)
            }
        }

        if !draft.profile.isEmpty {
            let selected = profilePopup.itemArray.first(where: { ($0.representedObject as? String) == draft.profile })
            if let selected {
                profilePopup.select(selected)
            } else {
                profilePopup.selectItem(at: 0)
            }
        } else {
            profilePopup.selectItem(at: 0)
        }
    }

    @objc private func onRemoveTapped(_ sender: Any?) {
        onRemove?(draft.routeID)
    }

    @objc private func onBrowserSelected(_ sender: Any?) {
        let selected = browserPopup.titleOfSelectedItem ?? ""
        draft.browserName = selected == "Select browser" ? "" : selected
        draft.profile = ""
        refreshProfilePopup()
        onBrowserChanged?(draft.browserName)
    }

    @objc private func onProfileSelected(_ sender: Any?) {
        draft.profile = profilePopup.selectedItem?.representedObject as? String ?? ""
    }

    func textDidChange(_ notification: Notification) {
        draft.patterns = patternsView.string
    }
}

@objc(FinickySwiftConfigFormView)
public final class FinickySwiftConfigFormView: NSView {
    @objc public var onRequestChromiumProfiles: (() -> Void)?
    @objc public var onFormatRequested: (() -> Void)?
    @objc public var onSaveRequested: (() -> Void)?
    @objc public var onICloudToggleRequested: (() -> Void)?

    private let defaultBrowserPopup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 280, height: 26), pullsDown: false)
    private let configPathLabel = NSTextField(labelWithString: "Generated file path: (loading...)")
    private let cloudStatusLabel = NSTextField(labelWithString: "iCloud: Loading...")
    private let cloudResultLabel = NSTextField(labelWithString: "")
    private let cloudToggleButton = NSButton(title: "Enable iCloud Sync", target: nil, action: nil)

    private let formatButton = NSButton(title: "Format", target: nil, action: nil)
    private let saveButton = NSButton(title: "Save and Activate", target: nil, action: nil)
    private let builderErrorLabel = NSTextField(labelWithString: "")
    private let builderStatusLabel = NSTextField(labelWithString: "")
    private let previewTextView = NSTextView(frame: .zero)

    private let routesStack = NSStackView(frame: .zero)

    private var browserOptions: [[String: Any]] = []
    private var profileGroups: [[String: Any]] = []
    private var routeDrafts: [SwiftRouteDraft] = []
    private var selectedDefaultBrowser = ""
    private var cloudEnabled = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        autoresizingMask = [.width, .height]
        buildUI()
        ensureAtLeastOneRoute()
        rebuildRouteRows()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        buildUI()
    }

    private func buildUI() {
        let scroll = NSScrollView(frame: bounds)
        scroll.autoresizingMask = [.width, .height]
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false

        let content = NSView(frame: NSRect(x: 0, y: 0, width: bounds.width, height: 1960))
        content.autoresizingMask = [.width]

        let stack = NSStackView(frame: NSRect(x: 16, y: 16, width: max(600, bounds.width - 32), height: 1928))
        stack.autoresizingMask = [.width]
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16

        let title = NSTextField(labelWithString: "Config")
        title.font = NSFont.systemFont(ofSize: 36, weight: .bold)

        let subtitle = NSTextField(labelWithString: "Routes, profiles, preview and activation")
        subtitle.textColor = .secondaryLabelColor

        let builderCard = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: stack.frame.width, height: 170))
        builderCard.material = .menu
        builderCard.state = .active
        builderCard.blendingMode = .withinWindow
        builderCard.wantsLayer = true
        builderCard.layer?.cornerRadius = 14
        builderCard.layer?.borderWidth = 1
        builderCard.layer?.borderColor = NSColor(white: 1.0, alpha: 0.20).cgColor

        let builderCardStack = NSStackView(frame: NSRect(x: 16, y: 16, width: builderCard.bounds.width - 32, height: 138))
        builderCardStack.autoresizingMask = [.width, .height]
        builderCardStack.orientation = .vertical
        builderCardStack.alignment = .leading
        builderCardStack.spacing = 10

        let defaultRow = NSStackView()
        defaultRow.orientation = .horizontal
        defaultRow.spacing = 10
        defaultBrowserPopup.target = self
        defaultBrowserPopup.action = #selector(onDefaultBrowserChanged(_:))
        defaultRow.addArrangedSubview(NSTextField(labelWithString: "Default Browser:"))
        defaultRow.addArrangedSubview(defaultBrowserPopup)

        configPathLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        configPathLabel.textColor = .tertiaryLabelColor
        configPathLabel.lineBreakMode = .byTruncatingMiddle

        let cloudRow = NSStackView()
        cloudRow.orientation = .horizontal
        cloudRow.spacing = 10
        cloudToggleButton.target = self
        cloudToggleButton.action = #selector(onCloudToggle(_:))
        cloudToggleButton.bezelStyle = .rounded
        cloudRow.addArrangedSubview(cloudStatusLabel)
        cloudRow.addArrangedSubview(cloudToggleButton)

        cloudResultLabel.textColor = .secondaryLabelColor
        cloudResultLabel.lineBreakMode = .byWordWrapping
        cloudResultLabel.maximumNumberOfLines = 3

        builderCardStack.addArrangedSubview(defaultRow)
        builderCardStack.addArrangedSubview(configPathLabel)
        builderCardStack.addArrangedSubview(cloudRow)
        builderCardStack.addArrangedSubview(cloudResultLabel)
        builderCard.addSubview(builderCardStack)

        let routeHeader = NSStackView()
        routeHeader.orientation = .horizontal
        routeHeader.spacing = 10
        let routeTitle = NSTextField(labelWithString: "Routes")
        routeTitle.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        let addRouteButton = NSButton(title: "Add Route", target: self, action: #selector(onAddRoute(_:)))
        addRouteButton.bezelStyle = .rounded
        routeHeader.addArrangedSubview(routeTitle)
        routeHeader.addArrangedSubview(addRouteButton)

        routesStack.orientation = .vertical
        routesStack.alignment = .leading
        routesStack.spacing = 12

        let routesCard = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: stack.frame.width, height: 980))
        routesCard.material = .menu
        routesCard.state = .active
        routesCard.blendingMode = .withinWindow
        routesCard.wantsLayer = true
        routesCard.layer?.cornerRadius = 14
        routesCard.layer?.borderWidth = 1
        routesCard.layer?.borderColor = NSColor(white: 1.0, alpha: 0.16).cgColor

        let routesCardStack = NSStackView(frame: NSRect(x: 16, y: 16, width: routesCard.bounds.width - 32, height: routesCard.bounds.height - 32))
        routesCardStack.autoresizingMask = [.width, .height]
        routesCardStack.orientation = .vertical
        routesCardStack.alignment = .leading
        routesCardStack.spacing = 12
        routesCardStack.addArrangedSubview(routeHeader)
        routesCardStack.addArrangedSubview(routesStack)
        routesCard.addSubview(routesCardStack)

        let actionRow = NSStackView()
        actionRow.orientation = .horizontal
        actionRow.spacing = 12
        formatButton.target = self
        formatButton.action = #selector(onFormat(_:))
        formatButton.bezelStyle = .rounded
        saveButton.target = self
        saveButton.action = #selector(onSave(_:))
        saveButton.keyEquivalent = "\r"
        saveButton.bezelStyle = .recessed
        actionRow.addArrangedSubview(formatButton)
        actionRow.addArrangedSubview(saveButton)

        builderErrorLabel.textColor = .systemRed
        builderStatusLabel.textColor = .systemGreen

        let previewLabel = NSTextField(labelWithString: "Preview")
        previewLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)

        let previewScroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 860, height: 420))
        previewScroll.borderType = .bezelBorder
        previewScroll.hasVerticalScroller = true
        previewScroll.hasHorizontalScroller = true
        previewTextView.isEditable = false
        previewTextView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        previewTextView.isAutomaticQuoteSubstitutionEnabled = false
        previewScroll.documentView = previewTextView

        let previewCard = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: stack.frame.width, height: 492))
        previewCard.material = .headerView
        previewCard.state = .active
        previewCard.blendingMode = .withinWindow
        previewCard.wantsLayer = true
        previewCard.layer?.cornerRadius = 14
        previewCard.layer?.borderWidth = 1
        previewCard.layer?.borderColor = NSColor(white: 1.0, alpha: 0.14).cgColor

        let previewCardStack = NSStackView(frame: NSRect(x: 16, y: 16, width: previewCard.bounds.width - 32, height: previewCard.bounds.height - 32))
        previewCardStack.autoresizingMask = [.width, .height]
        previewCardStack.orientation = .vertical
        previewCardStack.alignment = .leading
        previewCardStack.spacing = 8
        previewCardStack.addArrangedSubview(previewLabel)
        previewCardStack.addArrangedSubview(previewScroll)
        previewCard.addSubview(previewCardStack)

        stack.addArrangedSubview(title)
        stack.addArrangedSubview(subtitle)
        stack.addArrangedSubview(builderCard)
        stack.addArrangedSubview(routesCard)
        stack.addArrangedSubview(actionRow)
        stack.addArrangedSubview(builderErrorLabel)
        stack.addArrangedSubview(builderStatusLabel)
        stack.addArrangedSubview(previewCard)

        content.addSubview(stack)
        scroll.documentView = content
        addSubview(scroll)

        setPreviewLoading(false)
        setSaveLoading(false)
    }

    private func ensureAtLeastOneRoute() {
        if routeDrafts.isEmpty {
            routeDrafts.append(SwiftRouteDraft())
        }
    }

    private func rebuildRouteRows() {
        routesStack.arrangedSubviews.forEach {
            routesStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        for draft in routeDrafts {
            let row = SwiftRouteEditorRow(
                frame: NSRect(x: 0, y: 0, width: max(760, bounds.width - 70), height: 220),
                draft: draft,
                browserOptions: browserOptions,
                profileGroups: profileGroups
            )
            row.onRemove = { [weak self] routeID in
                self?.routeDrafts.removeAll(where: { $0.routeID == routeID })
                self?.ensureAtLeastOneRoute()
                self?.rebuildRouteRows()
            }
            row.onBrowserChanged = { [weak self] browserName in
                if self?.browserSupportsProfiles(browserName) == true {
                    self?.onRequestChromiumProfiles?()
                }
            }
            routesStack.addArrangedSubview(row)
        }
    }

    private func browserSupportsProfiles(_ browserName: String) -> Bool {
        guard !browserName.isEmpty else {
            return false
        }
        for option in browserOptions {
            if let appName = option["appName"] as? String,
               appName == browserName,
               let supports = option["supportsProfiles"] as? Bool {
                return supports
            }
        }
        return false
    }

    private func sanitizePatterns(_ raw: String) -> [String] {
        raw
            .components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { value in
                var v = value
                if (v.hasPrefix("\"") && v.hasSuffix("\"")) || (v.hasPrefix("'") && v.hasSuffix("'")) {
                    v = String(v.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                return v
            }
            .filter { !$0.isEmpty }
    }

    @objc public func setBrowserOptions(_ browserOptions: NSArray) {
        self.browserOptions = browserOptions.compactMap { $0 as? [String: Any] }
        refreshDefaultBrowserPopup()
        rebuildRouteRows()
    }

    @objc public func setChromiumProfileGroups(_ profileGroups: NSArray) {
        self.profileGroups = profileGroups.compactMap { $0 as? [String: Any] }
        rebuildRouteRows()
    }

    @objc public func setConfigPath(_ configPath: String) {
        configPathLabel.stringValue = configPath.isEmpty ? "Generated file path: (will use default path)" : "Generated file path: \(configPath)"
    }

    @objc public func applyDraft(_ draft: NSDictionary) {
        if let defaultBrowser = draft["defaultBrowser"] as? String {
            selectedDefaultBrowser = defaultBrowser
        }

        routeDrafts.removeAll()
        if let routes = draft["routes"] as? [[String: Any]] {
            for route in routes {
                let item = SwiftRouteDraft()
                item.browserName = route["browser"] as? String ?? ""
                item.profile = route["profile"] as? String ?? ""
                if let patterns = route["patterns"] as? [String] {
                    item.patterns = patterns.joined(separator: ", ")
                }
                routeDrafts.append(item)
            }
        }

        ensureAtLeastOneRoute()
        refreshDefaultBrowserPopup()
        rebuildRouteRows()
    }

    @objc public func setBuilderError(_ errorText: String) {
        builderErrorLabel.stringValue = errorText
    }

    @objc public func setBuilderStatus(_ statusText: String) {
        builderStatusLabel.stringValue = statusText
    }

    @objc public func setPreviewLoading(_ loading: Bool) {
        formatButton.isEnabled = !loading
        formatButton.title = loading ? "Formatting..." : "Format"
    }

    @objc public func setSaveLoading(_ loading: Bool) {
        saveButton.isEnabled = !loading
        saveButton.title = loading ? "Saving..." : "Save and Activate"
    }

    @objc public func updateICloudWithEnabled(_ enabled: Bool, configPath: String, cloudPath: String, error: String) {
        cloudEnabled = enabled
        cloudStatusLabel.stringValue = enabled ? "iCloud: Enabled" : "iCloud: Disabled"
        cloudToggleButton.title = enabled ? "Disable iCloud Sync" : "Enable iCloud Sync"

        var lines: [String] = []
        if !error.isEmpty {
            lines.append(error)
            cloudResultLabel.textColor = .systemRed
        } else {
            cloudResultLabel.textColor = .secondaryLabelColor
        }
        if !configPath.isEmpty {
            lines.append("Config: \(configPath)")
        }
        if !cloudPath.isEmpty {
            lines.append("iCloud: \(cloudPath)")
        }
        cloudResultLabel.stringValue = lines.joined(separator: "\n")
    }

    @objc public func setICloudToggleLoading(_ loading: Bool) {
        cloudToggleButton.isEnabled = !loading
        if loading {
            cloudToggleButton.title = cloudEnabled ? "Disabling..." : "Enabling..."
        }
    }

    @objc public func setICloudResultMessage(_ message: String, backupPath: String, error: String) {
        if !error.isEmpty {
            cloudResultLabel.textColor = .systemRed
            cloudResultLabel.stringValue = error
            return
        }

        cloudResultLabel.textColor = .secondaryLabelColor
        var lines: [String] = []
        if !message.isEmpty {
            lines.append(message)
        }
        if !backupPath.isEmpty {
            lines.append("Backup: \(backupPath)")
        }
        cloudResultLabel.stringValue = lines.joined(separator: "\n")
    }

    @objc public func setPreviewContent(_ content: String) {
        previewTextView.string = content
    }

    @objc public func buildRequestPayload(withError errorMessage: AutoreleasingUnsafeMutablePointer<NSString?>?) -> NSDictionary? {
        setBuilderError("")
        setBuilderStatus("")

        let defaultBrowser = (defaultBrowserPopup.titleOfSelectedItem ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if defaultBrowser.isEmpty || defaultBrowser == "(No browsers found)" {
            errorMessage?.pointee = "Default browser is required"
            return nil
        }

        var routes: [[String: Any]] = []
        for draft in routeDrafts {
            let browser = draft.browserName.trimmingCharacters(in: .whitespacesAndNewlines)
            let patterns = sanitizePatterns(draft.patterns)
            if browser.isEmpty || patterns.isEmpty {
                continue
            }

            routes.append([
                "patterns": patterns,
                "browser": browser,
                "profile": draft.profile,
            ])
        }

        if routes.isEmpty {
            errorMessage?.pointee = "Add at least one valid route rule"
            return nil
        }

        return [
            "request": [
                "defaultBrowser": defaultBrowser,
                "routes": routes,
            ],
        ]
    }

    private func refreshDefaultBrowserPopup() {
        defaultBrowserPopup.removeAllItems()
        let names = browserOptions.compactMap { $0["appName"] as? String }

        if names.isEmpty {
            defaultBrowserPopup.addItem(withTitle: "(No browsers found)")
            return
        }

        defaultBrowserPopup.addItems(withTitles: names)
        if !selectedDefaultBrowser.isEmpty, names.contains(selectedDefaultBrowser) {
            defaultBrowserPopup.selectItem(withTitle: selectedDefaultBrowser)
        } else {
            defaultBrowserPopup.selectItem(at: 0)
            selectedDefaultBrowser = defaultBrowserPopup.titleOfSelectedItem ?? ""
        }
    }

    @objc private func onDefaultBrowserChanged(_ sender: Any?) {
        selectedDefaultBrowser = defaultBrowserPopup.titleOfSelectedItem ?? ""
    }

    @objc private func onAddRoute(_ sender: Any?) {
        routeDrafts.append(SwiftRouteDraft())
        rebuildRouteRows()
    }

    @objc private func onFormat(_ sender: Any?) {
        onFormatRequested?()
    }

    @objc private func onSave(_ sender: Any?) {
        onSaveRequested?()
    }

    @objc private func onCloudToggle(_ sender: Any?) {
        onICloudToggleRequested?()
    }
}
