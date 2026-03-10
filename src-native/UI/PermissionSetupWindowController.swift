import AVFoundation
import ApplicationServices
import Cocoa

/// 权限设置引导窗口控制器
/// 用于首次启动或权限缺失时，引导用户完成必要的系统权限授权
class PermissionSetupWindowController: NSWindowController, NSWindowDelegate {

    // MARK: - 权限状态

    private var microphoneGranted = false
    private var accessibilityGranted = false

    // MARK: - UI 组件

    private var microphoneStatusIcon: NSImageView!
    private var microphoneActionButton: NSButton!
    private var accessibilityStatusIcon: NSImageView!
    private var accessibilityActionButton: NSButton!
    private var completeButton: NSButton!

    // MARK: - 定时器

    private var statusCheckTimer: Timer?

    // MARK: - 回调

    var onComplete: (() -> Void)?

    // MARK: - 初始化

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "语音输入法 - 权限设置"
        window.isReleasedWhenClosed = false
        self.init(window: window)
        window.delegate = self
        setupUI()
        refreshPermissionStatus()
    }

    deinit {
        stopStatusCheckTimer()
    }

    // MARK: - UI 构建

    private func setupUI() {
        guard let window = window else { return }

        let contentView = NSView(frame: window.contentRect(forFrameRect: window.frame))
        contentView.wantsLayer = true
        window.contentView = contentView

        // 主标题
        let titleLabel = NSTextField(labelWithString: "开始使用前，需要您授权以下权限")
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        // 副标题
        let subtitleLabel = NSTextField(labelWithString: "授权后，您可以通过快捷键随时唤起语音输入")
        subtitleLabel.font = NSFont.systemFont(ofSize: 12)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.alignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(subtitleLabel)

        // 权限卡片容器
        let cardsStack = NSStackView()
        cardsStack.orientation = .vertical
        cardsStack.spacing = 16
        cardsStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(cardsStack)

        // 麦克风权限卡片
        let micCard = createPermissionCard(
            icon: "mic.fill",
            title: "麦克风权限",
            description: "用于采集您的语音，进行语音识别",
            statusIcon: &microphoneStatusIcon,
            actionButton: &microphoneActionButton,
            action: #selector(requestMicrophonePermission)
        )
        cardsStack.addArrangedSubview(micCard)

        // 辅助功能权限卡片
        let accessibilityCard = createPermissionCard(
            icon: "keyboard.fill",
            title: "辅助功能权限",
            description: "用于将识别结果自动粘贴到当前输入框",
            statusIcon: &accessibilityStatusIcon,
            actionButton: &accessibilityActionButton,
            action: #selector(openAccessibilitySettings)
        )
        cardsStack.addArrangedSubview(accessibilityCard)

        // 完成按钮
        completeButton = NSButton(title: "完成设置", target: self, action: #selector(completeClicked))
        completeButton.bezelStyle = .rounded
        completeButton.controlSize = .large
        completeButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(completeButton)

        // 底部提示
        let noteLabel = NSTextField(labelWithString: "授权后，点击「完成设置」开始使用")
        noteLabel.font = NSFont.systemFont(ofSize: 11)
        noteLabel.textColor = .tertiaryLabelColor
        noteLabel.alignment = .center
        noteLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(noteLabel)

        // 布局约束
        NSLayoutConstraint.activate([
            // 标题
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            titleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            // 副标题
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            // 卡片容器
            cardsStack.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 24),
            cardsStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            cardsStack.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor, constant: -24),

            // 完成按钮
            completeButton.bottomAnchor.constraint(equalTo: noteLabel.topAnchor, constant: -12),
            completeButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            completeButton.widthAnchor.constraint(equalToConstant: 140),

            // 底部提示
            noteLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            noteLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
        ])
    }

    /// 创建权限卡片
    private func createPermissionCard(
        icon: String,
        title: String,
        description: String,
        statusIcon: inout NSImageView!,
        actionButton: inout NSButton!,
        action: Selector
    ) -> NSView {
        let card = NSView()
        card.wantsLayer = true
        card.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        card.layer?.cornerRadius = 10
        card.layer?.borderWidth = 1
        card.layer?.borderColor = NSColor.separatorColor.cgColor
        card.translatesAutoresizingMaskIntoConstraints = false

        // 权限图标
        let iconView = NSImageView()
        iconView.image = NSImage(systemSymbolName: icon, accessibilityDescription: title)
        iconView.contentTintColor = .systemBlue
        iconView.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(iconView)

        // 标题
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(titleLabel)

        // 描述
        let descLabel = NSTextField(labelWithString: description)
        descLabel.font = NSFont.systemFont(ofSize: 11)
        descLabel.textColor = .secondaryLabelColor
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(descLabel)

        // 状态图标
        statusIcon = NSImageView()
        statusIcon.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(statusIcon)

        // 操作按钮
        actionButton = NSButton(title: "请求授权", target: self, action: action)
        actionButton.bezelStyle = .rounded
        actionButton.controlSize = .small
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(actionButton)

        // 卡片布局
        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(equalToConstant: 80),

            iconView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 32),
            iconView.heightAnchor.constraint(equalToConstant: 32),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),

            descLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            descLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),

            statusIcon.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            statusIcon.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            statusIcon.widthAnchor.constraint(equalToConstant: 20),
            statusIcon.heightAnchor.constraint(equalToConstant: 20),

            actionButton.trailingAnchor.constraint(equalTo: statusIcon.leadingAnchor, constant: -8),
            actionButton.centerYAnchor.constraint(equalTo: card.centerYAnchor),
        ])

        return card
    }

    // MARK: - 权限状态刷新

    private func refreshPermissionStatus() {
        // 检查麦克风权限
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        microphoneGranted = (micStatus == .authorized)
        updateMicrophoneUI()

        // 检查辅助功能权限
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        accessibilityGranted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        updateAccessibilityUI()

        // 更新完成按钮状态
        updateCompleteButton()
    }

    private func updateMicrophoneUI() {
        if microphoneGranted {
            microphoneStatusIcon.image = NSImage(
                systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "已授权")
            microphoneStatusIcon.contentTintColor = .systemGreen
            microphoneActionButton.title = "已授权"
            microphoneActionButton.isEnabled = false
        } else {
            microphoneStatusIcon.image = NSImage(
                systemSymbolName: "xmark.circle.fill", accessibilityDescription: "未授权")
            microphoneStatusIcon.contentTintColor = .systemOrange
            microphoneActionButton.title = "请求授权"
            microphoneActionButton.isEnabled = true
        }
    }

    private func updateAccessibilityUI() {
        if accessibilityGranted {
            accessibilityStatusIcon.image = NSImage(
                systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "已授权")
            accessibilityStatusIcon.contentTintColor = .systemGreen
            accessibilityActionButton.title = "已授权"
            accessibilityActionButton.isEnabled = false
        } else {
            accessibilityStatusIcon.image = NSImage(
                systemSymbolName: "xmark.circle.fill", accessibilityDescription: "未授权")
            accessibilityStatusIcon.contentTintColor = .systemOrange
            accessibilityActionButton.title = "前往设置"
            accessibilityActionButton.isEnabled = true
        }
    }

    private func updateCompleteButton() {
        let allGranted = microphoneGranted && accessibilityGranted
        completeButton.isEnabled = allGranted

        if allGranted {
            completeButton.title = "完成设置"
        } else {
            completeButton.title = "请先完成授权"
        }
    }

    // MARK: - 定时器

    private func startStatusCheckTimer() {
        stopStatusCheckTimer()
        statusCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) {
            [weak self] _ in
            self?.refreshPermissionStatus()
        }
    }

    private func stopStatusCheckTimer() {
        statusCheckTimer?.invalidate()
        statusCheckTimer = nil
    }

    // MARK: - 权限操作

    @objc private func requestMicrophonePermission() {
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            DispatchQueue.main.async {
                self?.refreshPermissionStatus()
            }
        }
    }

    @objc private func openAccessibilitySettings() {
        // 先触发系统弹窗
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)

        // 同时打开系统设置页面
        if let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func completeClicked() {
        stopStatusCheckTimer()
        onComplete?()
        self.close()
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        stopStatusCheckTimer()
    }

    // MARK: - 显示/隐藏

    func show() {
        refreshPermissionStatus()
        startStatusCheckTimer()

        window?.center()
        self.showWindow(nil)
        NSApp.activateApp()
    }

    func showIfNeeded() -> Bool {
        refreshPermissionStatus()

        if !microphoneGranted || !accessibilityGranted {
            show()
            return true
        }
        return false
    }
}
