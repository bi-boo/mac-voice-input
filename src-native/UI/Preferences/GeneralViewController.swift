import AVFoundation
import Cocoa
import ServiceManagement

class GeneralViewController: NSViewController {

    // 快捷键组件
    private var holdRecorder: KeyRecorderView!
    private var toggleRecorder: KeyRecorderView!

    // 权限状态
    private var micStatusIcon: NSImageView!
    private var micStatusLabel: NSTextField!
    private var axStatusIcon: NSImageView!
    private var axStatusLabel: NSTextField!

    // 开机自启动
    private var launchAtLoginSwitch: NSSwitch!

    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 450))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadData()
    }

    private func setupUI() {
        let container = NSStackView()
        container.orientation = .vertical
        container.spacing = 20
        container.alignment = .leading
        container.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(container)

        // 约束容器
        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            container.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
        ])

        // 辅助方法：创建分组标题（卡片外部）
        func createSectionTitle(title: String) -> NSTextField {
            let label = NSTextField(labelWithString: title)
            label.font = NSFont.boldSystemFont(ofSize: 13)
            label.textColor = .labelColor
            return label
        }

        // 辅助方法：创建卡片容器
        func createCard() -> NSView {
            let card = NSView()
            card.wantsLayer = true
            card.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
            card.layer?.cornerRadius = 10
            card.translatesAutoresizingMaskIntoConstraints = false
            return card
        }

        // 辅助方法：创建卡片内分隔线
        func createCardSeparator() -> NSView {
            let separator = NSView()
            separator.wantsLayer = true
            separator.layer?.backgroundColor = NSColor.separatorColor.cgColor
            separator.translatesAutoresizingMaskIntoConstraints = false
            separator.heightAnchor.constraint(equalToConstant: 1).isActive = true
            return separator
        }

        // 辅助方法：通用行（两端对齐）
        func createRow(label: String, control: NSView, padding: CGFloat = 16) -> NSStackView {
            let row = NSStackView()
            row.orientation = .horizontal
            row.distribution = .fill
            row.alignment = .centerY
            row.spacing = 10
            row.translatesAutoresizingMaskIntoConstraints = false
            row.edgeInsets = NSEdgeInsets(top: 10, left: padding, bottom: 10, right: padding)

            let labelField = NSTextField(labelWithString: label)
            labelField.alignment = .left
            labelField.font = NSFont.systemFont(ofSize: 13)
            labelField.translatesAutoresizingMaskIntoConstraints = false

            let spacer = NSView()
            spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

            row.addArrangedSubview(labelField)
            row.addArrangedSubview(spacer)
            row.addArrangedSubview(control)

            return row
        }

        // ===== 1. 启动设置卡片 =====
        let startupSection = NSStackView()
        startupSection.orientation = .vertical
        startupSection.alignment = .leading
        startupSection.spacing = 8

        let startupTitle = createSectionTitle(title: "启动")
        startupSection.addArrangedSubview(startupTitle)

        let startupCard = createCard()
        let startupContent = NSStackView()
        startupContent.orientation = .vertical
        startupContent.spacing = 0
        startupContent.translatesAutoresizingMaskIntoConstraints = false

        launchAtLoginSwitch = NSSwitch()
        launchAtLoginSwitch.target = self
        launchAtLoginSwitch.action = #selector(launchAtLoginChanged)

        let launchRow = createRow(label: "开机时自动启动", control: launchAtLoginSwitch)
        startupContent.addArrangedSubview(launchRow)
        launchRow.widthAnchor.constraint(equalTo: startupContent.widthAnchor).isActive = true

        startupCard.addSubview(startupContent)
        NSLayoutConstraint.activate([
            startupContent.topAnchor.constraint(equalTo: startupCard.topAnchor),
            startupContent.bottomAnchor.constraint(equalTo: startupCard.bottomAnchor),
            startupContent.leadingAnchor.constraint(equalTo: startupCard.leadingAnchor),
            startupContent.trailingAnchor.constraint(equalTo: startupCard.trailingAnchor),
        ])

        startupSection.addArrangedSubview(startupCard)
        startupCard.widthAnchor.constraint(equalTo: startupSection.widthAnchor).isActive = true

        container.addArrangedSubview(startupSection)
        startupSection.widthAnchor.constraint(equalTo: container.widthAnchor).isActive = true

        // ===== 2. 快捷键设置卡片 =====
        let shortcutsSection = NSStackView()
        shortcutsSection.orientation = .vertical
        shortcutsSection.alignment = .leading
        shortcutsSection.spacing = 8

        let shortcutsTitle = createSectionTitle(title: "快捷键")
        shortcutsSection.addArrangedSubview(shortcutsTitle)

        let shortcutsCard = createCard()
        let shortcutsContent = NSStackView()
        shortcutsContent.orientation = .vertical
        shortcutsContent.spacing = 0
        shortcutsContent.translatesAutoresizingMaskIntoConstraints = false

        // 按住说话
        holdRecorder = KeyRecorderView(frame: .zero)
        holdRecorder.translatesAutoresizingMaskIntoConstraints = false
        holdRecorder.widthAnchor.constraint(equalToConstant: 120).isActive = true
        holdRecorder.heightAnchor.constraint(equalToConstant: 24).isActive = true

        let holdRow = createRow(label: "按住说话", control: holdRecorder)
        shortcutsContent.addArrangedSubview(holdRow)
        holdRow.widthAnchor.constraint(equalTo: shortcutsContent.widthAnchor).isActive = true

        // 分隔线
        let shortcutsSep = createCardSeparator()
        let sepWrapper1 = NSView()
        sepWrapper1.translatesAutoresizingMaskIntoConstraints = false
        sepWrapper1.addSubview(shortcutsSep)
        NSLayoutConstraint.activate([
            shortcutsSep.leadingAnchor.constraint(equalTo: sepWrapper1.leadingAnchor, constant: 16),
            shortcutsSep.trailingAnchor.constraint(equalTo: sepWrapper1.trailingAnchor),
            shortcutsSep.topAnchor.constraint(equalTo: sepWrapper1.topAnchor),
            shortcutsSep.bottomAnchor.constraint(equalTo: sepWrapper1.bottomAnchor),
        ])
        shortcutsContent.addArrangedSubview(sepWrapper1)
        sepWrapper1.widthAnchor.constraint(equalTo: shortcutsContent.widthAnchor).isActive = true

        // 按下说话
        toggleRecorder = KeyRecorderView(frame: .zero)
        toggleRecorder.translatesAutoresizingMaskIntoConstraints = false
        toggleRecorder.widthAnchor.constraint(equalToConstant: 120).isActive = true
        toggleRecorder.heightAnchor.constraint(equalToConstant: 24).isActive = true

        let toggleRow = createRow(label: "按下说话", control: toggleRecorder)
        shortcutsContent.addArrangedSubview(toggleRow)
        toggleRow.widthAnchor.constraint(equalTo: shortcutsContent.widthAnchor).isActive = true

        shortcutsCard.addSubview(shortcutsContent)
        NSLayoutConstraint.activate([
            shortcutsContent.topAnchor.constraint(equalTo: shortcutsCard.topAnchor),
            shortcutsContent.bottomAnchor.constraint(equalTo: shortcutsCard.bottomAnchor),
            shortcutsContent.leadingAnchor.constraint(equalTo: shortcutsCard.leadingAnchor),
            shortcutsContent.trailingAnchor.constraint(equalTo: shortcutsCard.trailingAnchor),
        ])

        shortcutsSection.addArrangedSubview(shortcutsCard)
        shortcutsCard.widthAnchor.constraint(equalTo: shortcutsSection.widthAnchor).isActive = true

        // 快捷键提示文字
        let shortcutsNote = NSTextField(labelWithString: "「按住说话」松开自动粘贴；「按下说话」再次按下停止")
        shortcutsNote.font = NSFont.systemFont(ofSize: 11)
        shortcutsNote.textColor = .secondaryLabelColor
        shortcutsSection.addArrangedSubview(shortcutsNote)

        container.addArrangedSubview(shortcutsSection)
        shortcutsSection.widthAnchor.constraint(equalTo: container.widthAnchor).isActive = true

        // ===== 3. 系统权限卡片 =====
        let permSection = NSStackView()
        permSection.orientation = .vertical
        permSection.alignment = .leading
        permSection.spacing = 8

        let permTitle = createSectionTitle(title: "系统权限")
        permSection.addArrangedSubview(permTitle)

        let permCard = createCard()
        let permContent = NSStackView()
        permContent.orientation = .vertical
        permContent.spacing = 0
        permContent.translatesAutoresizingMaskIntoConstraints = false

        micStatusIcon = NSImageView()
        micStatusIcon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        micStatusIcon.translatesAutoresizingMaskIntoConstraints = false
        micStatusIcon.widthAnchor.constraint(equalToConstant: 16).isActive = true
        micStatusIcon.heightAnchor.constraint(equalToConstant: 16).isActive = true

        micStatusLabel = NSTextField(labelWithString: "检查中...")
        micStatusLabel.font = NSFont.systemFont(ofSize: 13)

        let micStatusView = NSStackView(views: [micStatusIcon, micStatusLabel])
        micStatusView.orientation = .horizontal
        micStatusView.spacing = 4
        micStatusView.alignment = .centerY

        let micRow = createRow(label: "麦克风权限", control: micStatusView)
        permContent.addArrangedSubview(micRow)
        micRow.widthAnchor.constraint(equalTo: permContent.widthAnchor).isActive = true

        // 分隔线
        let permSep1 = createCardSeparator()
        let sepWrapper2 = NSView()
        sepWrapper2.translatesAutoresizingMaskIntoConstraints = false
        sepWrapper2.addSubview(permSep1)
        NSLayoutConstraint.activate([
            permSep1.leadingAnchor.constraint(equalTo: sepWrapper2.leadingAnchor, constant: 16),
            permSep1.trailingAnchor.constraint(equalTo: sepWrapper2.trailingAnchor),
            permSep1.topAnchor.constraint(equalTo: sepWrapper2.topAnchor),
            permSep1.bottomAnchor.constraint(equalTo: sepWrapper2.bottomAnchor),
        ])
        permContent.addArrangedSubview(sepWrapper2)
        sepWrapper2.widthAnchor.constraint(equalTo: permContent.widthAnchor).isActive = true

        axStatusIcon = NSImageView()
        axStatusIcon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        axStatusIcon.translatesAutoresizingMaskIntoConstraints = false
        axStatusIcon.widthAnchor.constraint(equalToConstant: 16).isActive = true
        axStatusIcon.heightAnchor.constraint(equalToConstant: 16).isActive = true

        axStatusLabel = NSTextField(labelWithString: "检查中...")
        axStatusLabel.font = NSFont.systemFont(ofSize: 13)

        let axStatusView = NSStackView(views: [axStatusIcon, axStatusLabel])
        axStatusView.orientation = .horizontal
        axStatusView.spacing = 4
        axStatusView.alignment = .centerY

        let axRow = createRow(label: "辅助功能权限", control: axStatusView)
        permContent.addArrangedSubview(axRow)
        axRow.widthAnchor.constraint(equalTo: permContent.widthAnchor).isActive = true

        // 分隔线
        let permSep2 = createCardSeparator()
        let sepWrapper3 = NSView()
        sepWrapper3.translatesAutoresizingMaskIntoConstraints = false
        sepWrapper3.addSubview(permSep2)
        NSLayoutConstraint.activate([
            permSep2.leadingAnchor.constraint(equalTo: sepWrapper3.leadingAnchor, constant: 16),
            permSep2.trailingAnchor.constraint(equalTo: sepWrapper3.trailingAnchor),
            permSep2.topAnchor.constraint(equalTo: sepWrapper3.topAnchor),
            permSep2.bottomAnchor.constraint(equalTo: sepWrapper3.bottomAnchor),
        ])
        permContent.addArrangedSubview(sepWrapper3)
        sepWrapper3.widthAnchor.constraint(equalTo: permContent.widthAnchor).isActive = true

        // 授权按钮行
        let checkBtn = NSButton(
            title: "前往系统设置授权", target: self, action: #selector(openPermissionSetup))
        checkBtn.bezelStyle = .push
        checkBtn.controlSize = .regular
        checkBtn.isBordered = false
        checkBtn.contentTintColor = .systemBlue

        let btnRow = createRow(label: "", control: checkBtn)
        permContent.addArrangedSubview(btnRow)
        btnRow.widthAnchor.constraint(equalTo: permContent.widthAnchor).isActive = true

        permCard.addSubview(permContent)
        NSLayoutConstraint.activate([
            permContent.topAnchor.constraint(equalTo: permCard.topAnchor),
            permContent.bottomAnchor.constraint(equalTo: permCard.bottomAnchor),
            permContent.leadingAnchor.constraint(equalTo: permCard.leadingAnchor),
            permContent.trailingAnchor.constraint(equalTo: permCard.trailingAnchor),
        ])

        permSection.addArrangedSubview(permCard)
        permCard.widthAnchor.constraint(equalTo: permSection.widthAnchor).isActive = true

        container.addArrangedSubview(permSection)
        permSection.widthAnchor.constraint(equalTo: container.widthAnchor).isActive = true
    }

    private func loadData() {
        // 加载快捷键
        if let config = ASRConfig.load() {
            holdRecorder.setKey(code: config.holdHotKeyCode, mods: config.holdHotKeyModifiers)
            toggleRecorder.setKey(code: config.startHotKeyCode, mods: config.startHotKeyModifiers)
        }

        // 设置快捷键自动保存回调
        holdRecorder.onKeyRecorded = { [weak self] _, _ in
            self?.saveHotKeys()
        }
        toggleRecorder.onKeyRecorded = { [weak self] _, _ in
            self?.saveHotKeys()
        }

        // 加载开机自启动状态
        loadLaunchAtLoginState()

        // 刷新权限状态
        refreshPermissions()
    }

    // MARK: - 开机自启动

    private func loadLaunchAtLoginState() {
        if #available(macOS 13.0, *) {
            let status = SMAppService.mainApp.status
            launchAtLoginSwitch.state = (status == .enabled) ? .on : .off
        } else {
            // macOS 12 及更早版本使用旧 API
            launchAtLoginSwitch.state = .off
        }
    }

    @objc private func launchAtLoginChanged() {
        let shouldEnable = launchAtLoginSwitch.state == .on

        if #available(macOS 13.0, *) {
            do {
                if shouldEnable {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("[设置] 开机自启动设置失败: \(error)")
                // 恢复开关状态
                launchAtLoginSwitch.state = shouldEnable ? .off : .on
            }
        }
    }

    // MARK: - 快捷键保存

    private func saveHotKeys() {
        guard let holdCode = holdRecorder.keyCode, let holdMods = holdRecorder.modifierFlags else {
            return
        }

        guard let toggleCode = toggleRecorder.keyCode, let toggleMods = toggleRecorder.modifierFlags
        else {
            return
        }

        guard let currentConfig = ASRConfig.load() else {
            return
        }

        let newConfig = ASRConfig(
            appKey: currentConfig.appKey,
            accessKey: currentConfig.accessKey,
            resourceId: currentConfig.resourceId,
            inputMode: currentConfig.inputMode,
            holdHotKeyCode: holdCode,
            holdHotKeyModifiers: holdMods,
            startHotKeyCode: toggleCode,
            startHotKeyModifiers: toggleMods,
            stopHotKeyCode: currentConfig.stopHotKeyCode,
            stopHotKeyModifiers: currentConfig.stopHotKeyModifiers,
            modelName: currentConfig.modelName,
            enableITN: currentConfig.enableITN,
            enablePunctuation: currentConfig.enablePunctuation,
            showUtterances: currentConfig.showUtterances,
            resultType: currentConfig.resultType,
            audioFormat: currentConfig.audioFormat,
            audioSampleRate: currentConfig.audioSampleRate,
            enableNonStream: currentConfig.enableNonStream,
            enableDDC: currentConfig.enableDDC,
            endWindowSize: currentConfig.endWindowSize,
            enableAccelerateText: currentConfig.enableAccelerateText,
            accelerateScore: currentConfig.accelerateScore
        )

        if newConfig.save() {
            // 通知 App 刷新快捷键
            NotificationCenter.default.post(
                name: NSNotification.Name("ASRConfigChanged"),
                object: newConfig
            )
        }
    }

    // MARK: - 权限检查

    private func refreshPermissions() {
        let micAllowed = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        let micSymbol = micAllowed ? "checkmark.circle.fill" : "xmark.circle.fill"
        micStatusIcon.image = NSImage(systemSymbolName: micSymbol, accessibilityDescription: nil)
        micStatusIcon.contentTintColor = micAllowed ? .systemGreen : .secondaryLabelColor
        micStatusLabel.stringValue = micAllowed ? "已授权" : "未授权"
        micStatusLabel.textColor = micAllowed ? .systemGreen : .secondaryLabelColor

        let axOptions = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let axAllowed = AXIsProcessTrustedWithOptions(axOptions as CFDictionary)
        let axSymbol = axAllowed ? "checkmark.circle.fill" : "xmark.circle.fill"
        axStatusIcon.image = NSImage(systemSymbolName: axSymbol, accessibilityDescription: nil)
        axStatusIcon.contentTintColor = axAllowed ? .systemGreen : .secondaryLabelColor
        axStatusLabel.stringValue = axAllowed ? "已授权" : "未授权"
        axStatusLabel.textColor = axAllowed ? .systemGreen : .secondaryLabelColor
    }

    @objc private func openPermissionSetup() {
        NotificationCenter.default.post(
            name: NSNotification.Name("ShowPermissionSetup"), object: nil)
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        refreshPermissions()
        loadLaunchAtLoginState()
    }
}
