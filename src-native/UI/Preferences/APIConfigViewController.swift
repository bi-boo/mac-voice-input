import Cocoa

class APIConfigViewController: NSViewController, NSTextFieldDelegate {

    private var appKeyField: NSTextField!
    private var accessKeyField: NSTextField!
    private var saveStatusLabel: NSTextField?

    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 320))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadData()
    }

    private func setupUI() {
        // --- API 配置标题（独立视图避免 NSGridView 列宽限制截断）---
        let apiHeader = NSTextField(labelWithString: "火山引擎 · 豆包流式语音识别")
        apiHeader.font = NSFont.boldSystemFont(ofSize: 13)
        apiHeader.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(apiHeader)

        let grid = NSGridView(views: [])
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.rowSpacing = 12
        grid.columnSpacing = 8
        grid.xPlacement = .leading
        grid.yPlacement = .center

        view.addSubview(grid)

        NSLayoutConstraint.activate([
            apiHeader.topAnchor.constraint(equalTo: view.topAnchor, constant: 30),
            apiHeader.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            apiHeader.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),

            grid.topAnchor.constraint(equalTo: apiHeader.bottomAnchor, constant: 16),
            grid.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            grid.widthAnchor.constraint(equalToConstant: 400),
        ])

        // App ID
        appKeyField = NSTextField()
        appKeyField.placeholderString = "请输入 App ID"
        appKeyField.translatesAutoresizingMaskIntoConstraints = false
        appKeyField.widthAnchor.constraint(equalToConstant: 280).isActive = true
        appKeyField.delegate = self

        let appKeyLabel = NSTextField(labelWithString: "App ID:")
        appKeyLabel.alignment = .right

        grid.addRow(with: [appKeyLabel, appKeyField])

        // Access Token
        accessKeyField = NSSecureTextField()
        accessKeyField.placeholderString = "请输入 Access Token"
        accessKeyField.translatesAutoresizingMaskIntoConstraints = false
        accessKeyField.widthAnchor.constraint(equalToConstant: 280).isActive = true
        accessKeyField.delegate = self

        let accessKeyLabel = NSTextField(labelWithString: "Access Token:")
        accessKeyLabel.alignment = .right

        grid.addRow(with: [accessKeyLabel, accessKeyField])

        // Spacer row
        grid.addRow(with: [NSView()])

        // --- 保存状态反馈 ---
        saveStatusLabel = NSTextField(labelWithString: "")
        saveStatusLabel!.font = NSFont.systemFont(ofSize: 11)
        saveStatusLabel!.textColor = .systemGreen
        grid.addRow(with: [NSView(), saveStatusLabel!])

        // --- 帮助信息（独立视图避免 NSGridView 列宽限制截断）---
        let helpNote = NSTextField(labelWithString: "登录火山引擎控制台获取 API 凭据")
        helpNote.font = NSFont.systemFont(ofSize: 11)
        helpNote.textColor = .secondaryLabelColor
        helpNote.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(helpNote)

        NSLayoutConstraint.activate([
            helpNote.topAnchor.constraint(equalTo: grid.bottomAnchor, constant: 12),
            helpNote.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            helpNote.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
        ])
    }

    private func loadData() {
        if let config = ASRConfig.load() {
            appKeyField.stringValue = config.appKey
            accessKeyField.stringValue = config.accessKey
        }
    }

    // MARK: - NSTextFieldDelegate 自动保存

    func controlTextDidEndEditing(_ obj: Notification) {
        saveConfiguration()
    }

    private func saveConfiguration() {
        let appKey = appKeyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let accessKey = accessKeyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let currentConfig = ASRConfig.load() else {
            return
        }

        let newConfig = ASRConfig(
            appKey: appKey,
            accessKey: accessKey,
            resourceId: currentConfig.resourceId,
            inputMode: currentConfig.inputMode,
            holdHotKeyCode: currentConfig.holdHotKeyCode,
            holdHotKeyModifiers: currentConfig.holdHotKeyModifiers,
            startHotKeyCode: currentConfig.startHotKeyCode,
            startHotKeyModifiers: currentConfig.startHotKeyModifiers,
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
            DispatchQueue.main.async {
                self.saveStatusLabel?.stringValue = "✓ 已保存"
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.saveStatusLabel?.stringValue = ""
                }
            }
        }
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        // 确保窗口加载后输入框不自动获取焦点
        DispatchQueue.main.async {
            self.view.window?.makeFirstResponder(nil)
        }
    }
}
