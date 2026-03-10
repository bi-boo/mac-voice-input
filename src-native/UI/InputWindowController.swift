import Cocoa

/// 自定义窗口，用于捕获 ESC 键
class InputWindow: NSWindow {
    var onEscapePressed: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        // ESC 键的 keyCode 是 53
        if event.keyCode == 53 {
            onEscapePressed?()
        } else {
            super.keyDown(with: event)
        }
    }

    override var canBecomeKey: Bool {
        return true
    }

    override var acceptsFirstResponder: Bool {
        return true
    }

    override func becomeFirstResponder() -> Bool {
        return true
    }
}

class InputWindowController: NSObject {
    var window: InputWindow?
    private var textView: NSTextView?
    private var clearButton: NSButton?
    private var statusLabel: NSTextField?

    var onConfirm: ((String) -> Void)?
    var onCancel: (() -> Void)?
    var onClear: (() -> Void)?

    private(set) var isRecording = true

    private var currentRawText: String = ""
    private var isContentPending: Bool = false
    private var indicatorTimer: Timer?
    private var indicatorFrame: Int = 0

    func createWindow() {
        let windowRect = NSRect(x: 0, y: 0, width: 440, height: 210)
        window = InputWindow(
            contentRect: windowRect,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        // 绑定 ESC 键取消录入
        window?.onEscapePressed = { [weak self] in
            self?.cancelClicked()
        }

        window?.isOpaque = false
        window?.backgroundColor = .clear
        window?.level = .floating
        window?.hasShadow = true
        window?.isMovableByWindowBackground = true
        window?.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // window?.appearance = NSAppearance(named: .vibrantLight) // 移除可能导致系统自动加边的外观配置

        // 透明包装层确保四角无白色残留
        let wrapperView = NSView(frame: windowRect)
        wrapperView.wantsLayer = true
        wrapperView.layer?.backgroundColor = CGColor.clear
        window?.contentView = wrapperView

        let container = NSVisualEffectView()
        container.material = .popover
        container.blendingMode = .behindWindow
        container.state = .active
        container.wantsLayer = true
        container.layer?.cornerRadius = 24
        container.layer?.masksToBounds = true
        container.translatesAutoresizingMaskIntoConstraints = false
        wrapperView.addSubview(container)

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: wrapperView.topAnchor),
            container.leadingAnchor.constraint(equalTo: wrapperView.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: wrapperView.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: wrapperView.bottomAnchor),
        ])

        setupUI(in: container)

        // 定位到鼠标所在屏幕
        positionWindowOnMouseScreen()
    }

    private func positionWindowOnMouseScreen() {
        guard let window = window else { return }

        // 获取鼠标位置
        let mouseLocation = NSEvent.mouseLocation

        // 找到包含鼠标的屏幕
        let screen =
            NSScreen.screens.first { screen in
                NSMouseInRect(mouseLocation, screen.frame, false)
            } ?? NSScreen.main ?? NSScreen.screens.first

        guard let targetScreen = screen else { return }

        let screenFrame = targetScreen.visibleFrame
        let windowFrame = window.frame

        // 左右居中
        let x = screenFrame.origin.x + (screenFrame.width - windowFrame.width) / 2
        // 上下 1/3 偏下（从顶部算起 1/3 处，即从底部算起 2/3 处）
        let y = screenFrame.origin.y + screenFrame.height * 0.67 - windowFrame.height / 2

        window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func setupUI(in container: NSView) {
        // --- 顶部区域 ---
        let micIcon = NSImageView()
        micIcon.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "语音输入")
        micIcon.contentTintColor = .secondaryLabelColor
        micIcon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        micIcon.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(micIcon)

        let topCloseButton = createSimpleButton(title: "关闭", icon: "xmark")
        topCloseButton.target = self
        topCloseButton.action = #selector(cancelClicked)
        topCloseButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(topCloseButton)

        // --- 中间文本区域 ---
        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(scrollView)

        textView = NSTextView()
        textView?.isEditable = false
        textView?.font = NSFont.systemFont(ofSize: 17, weight: .regular)
        textView?.textColor = .labelColor
        textView?.backgroundColor = .clear
        textView?.drawsBackground = false
        textView?.isVerticallyResizable = true
        textView?.textContainerInset = NSSize(width: 0, height: 0)
        scrollView.documentView = textView

        // --- 底部动作区域 ---
        let footerStack = NSStackView()
        footerStack.orientation = .horizontal
        footerStack.spacing = 16
        footerStack.alignment = .centerY
        footerStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(footerStack)

        // 左侧状态提示（静音警告 / 复制反馈）
        statusLabel = NSTextField(labelWithString: "")
        statusLabel!.font = NSFont.systemFont(ofSize: 12)
        statusLabel!.textColor = .tertiaryLabelColor
        statusLabel!.setContentHuggingPriority(.defaultLow, for: .horizontal)
        footerStack.addArrangedSubview(statusLabel!)

        // 清空按钮
        clearButton = createSimpleButton(title: "清空", icon: "trash")
        clearButton?.target = self
        clearButton?.action = #selector(clearClicked)
        footerStack.addArrangedSubview(clearButton!)

        // 复制按钮
        let copyButton = createSimpleButton(title: "复制", icon: "doc.on.doc")
        copyButton.target = self
        copyButton.action = #selector(copyClicked)
        footerStack.addArrangedSubview(copyButton)

        // 插入按钮（主操作，Enter 键触发）
        let insertButton = NSButton(title: "插入", target: self, action: #selector(insertClicked))
        insertButton.bezelStyle = .rounded
        insertButton.keyEquivalent = "\r"
        insertButton.translatesAutoresizingMaskIntoConstraints = false
        footerStack.addArrangedSubview(insertButton)

        // Auto Layout 约束
        NSLayoutConstraint.activate([
            // 顶部左侧麦克风
            micIcon.topAnchor.constraint(equalTo: container.topAnchor, constant: 18),
            micIcon.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),

            // 顶部右侧关闭
            topCloseButton.centerYAnchor.constraint(equalTo: micIcon.centerYAnchor),
            topCloseButton.trailingAnchor.constraint(
                equalTo: container.trailingAnchor, constant: -16),

            // 文本区域
            scrollView.topAnchor.constraint(equalTo: micIcon.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: footerStack.topAnchor, constant: -12),

            // 底部操作栏
            footerStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            footerStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            footerStack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
            footerStack.heightAnchor.constraint(equalToConstant: 32),
        ])
    }

    private func createSimpleButton(title: String, icon: String) -> NSButton {
        let btn = NSButton()
        btn.title = title
        btn.image = NSImage(systemSymbolName: icon, accessibilityDescription: title)
        btn.imagePosition = .imageLeading
        btn.bezelStyle = .recessed
        btn.isBordered = false
        btn.controlSize = .regular
        btn.contentTintColor = .secondaryLabelColor
        return btn
    }

    func show() {
        if window == nil {
            createWindow()
        }
        // 每次显示时重新定位到鼠标所在屏幕
        positionWindowOnMouseScreen()

        // 重置状态提示
        statusLabel?.stringValue = ""

        startIndicatorTimer()
        updateRecordingState(true)
        updateText("", isPending: false)
        window?.alphaValue = 0
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(window)  // 确保窗口接收键盘事件
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            window?.animator().alphaValue = 1.0
        }
        NSApp.activateApp()
    }

    func hide() {
        stopIndicatorTimer()
        NSAnimationContext.runAnimationGroup(
            { context in
                context.duration = 0.15
                window?.animator().alphaValue = 0
            },
            completionHandler: {
                self.window?.orderOut(nil)
            })
    }

    func updateText(_ text: String, isPending: Bool) {
        currentRawText = text
        isContentPending = isPending
        refreshTextWithIndicator()
    }

    private func refreshTextWithIndicator() {
        DispatchQueue.main.async {
            guard let textView = self.textView else { return }

            let font = NSFont.systemFont(ofSize: 17)
            let textColor = NSColor.labelColor
            let cursorColor = NSColor.systemBlue

            // 构建正文属性
            let mainAttrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: textColor,
            ]
            let fullAttrString = NSMutableAttributedString(
                string: self.currentRawText, attributes: mainAttrs)

            // 录音中始终显示光标（闪烁效果用透明色实现，避免布局跳动）
            if self.isRecording {
                // 偶数帧显示蓝色，奇数帧透明（光标始终存在，只是颜色变化）
                let isVisible = self.indicatorFrame % 2 == 0
                let actualCursorColor = isVisible ? cursorColor : NSColor.clear

                let cursorAttrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: actualCursorColor,
                ]
                let cursorStr = NSAttributedString(string: "|", attributes: cursorAttrs)
                fullAttrString.append(cursorStr)
            }

            textView.textStorage?.setAttributedString(fullAttrString)
            textView.scrollToEndOfDocument(nil)
        }
    }

    private func startIndicatorTimer() {
        indicatorTimer?.invalidate()
        indicatorTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) {
            [weak self] _ in
            self?.indicatorFrame += 1
            self?.refreshTextWithIndicator()
        }
    }

    private func stopIndicatorTimer() {
        indicatorTimer?.invalidate()
        indicatorTimer = nil
    }

    /// 音量更新（保留接口，空实现）
    func updateVolume(_ volume: Float) {
    }

    func updateRecordingState(_ recording: Bool) {
        isRecording = recording
    }

    /// 显示麦克风无声音提示
    func showSilenceWarning() {
        DispatchQueue.main.async {
            self.statusLabel?.stringValue = "未检测到声音，请检查麦克风"
            self.statusLabel?.textColor = .systemOrange
        }
    }

    @objc func cancelClicked() {
        hide()
        onCancel?()
    }

    @objc func clearClicked() {
        textView?.string = ""
        currentRawText = ""
        isContentPending = false
        onClear?()
    }

    @objc func copyClicked() {
        // 使用原始文本，不包含光标字符
        let text = currentRawText
        guard !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        statusLabel?.stringValue = "✓ 已复制"
        statusLabel?.textColor = .systemGreen
        // 2 秒后自动清除，与 API 页保存反馈保持一致
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let label = self?.statusLabel, label.stringValue == "✓ 已复制" else { return }
            label.stringValue = ""
        }
    }

    @objc func insertClicked() {
        // 使用原始文本，不包含光标字符
        let text = currentRawText
        hide()
        onConfirm?(text)
    }
}
