import Cocoa

/// 简洁模式窗口控制器（用于"按住说话"模式）
/// 特点：无按钮、无图标，仅显示文本区域
class SimpleInputWindowController: NSObject {
    var window: InputWindow?
    private var textView: NSTextView?

    var onCancel: (() -> Void)?
    private var hintLabel: NSTextField?

    private(set) var isRecording = true
    private var currentRawText: String = ""
    private var isContentPending: Bool = false
    private var indicatorTimer: Timer?
    private var indicatorFrame: Int = 0

    func createWindow() {
        let windowRect = NSRect(x: 0, y: 0, width: 400, height: 120)
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
        container.layer?.cornerRadius = 16
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

        // 定位到鼠标所在屏幕，左右居中，上下 1/3 偏下
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
        // 仅保留文本区域，无按钮和图标
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
        textView?.alignment = .left  // 左对齐，像输入法一样从左到右
        scrollView.documentView = textView

        // 底部提示标签（兼作静音警告）
        hintLabel = NSTextField(labelWithString: "松开按键即粘贴 · ESC 取消")
        hintLabel!.font = NSFont.systemFont(ofSize: 11)
        hintLabel!.textColor = .tertiaryLabelColor
        hintLabel!.alignment = .center
        hintLabel!.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hintLabel!)

        // Auto Layout 约束
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: container.topAnchor, constant: 24),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -24),
            scrollView.bottomAnchor.constraint(equalTo: hintLabel!.topAnchor, constant: -6),

            hintLabel!.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),
            hintLabel!.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
            hintLabel!.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -24),
        ])
    }

    func show() {
        if window == nil {
            createWindow()
        }
        // 每次显示时重新定位到鼠标所在屏幕
        positionWindowOnMouseScreen()

        // 重置底部提示
        hintLabel?.stringValue = "松开按键即粘贴 · ESC 取消"
        hintLabel?.textColor = .tertiaryLabelColor

        startIndicatorTimer()
        updateRecordingState(true)
        updateText("", isPending: false)
        window?.alphaValue = 0
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(window)
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

    func updateVolume(_ volume: Float) {}

    func updateRecordingState(_ recording: Bool) {
        isRecording = recording
    }

    func showSilenceWarning() {
        DispatchQueue.main.async {
            self.hintLabel?.stringValue = "未检测到声音，请检查麦克风"
            self.hintLabel?.textColor = .systemOrange
        }
    }

    @objc func cancelClicked() {
        hide()
        onCancel?()
    }

    /// 获取当前文本
    func getCurrentText() -> String {
        return currentRawText
    }
}
