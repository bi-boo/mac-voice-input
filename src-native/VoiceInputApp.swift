import AVFoundation
import ApplicationServices
import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?

    // 模块
    let recorder = AudioRecorder()
    lazy var asrClient: VolcanoASRClient = {
        if let config = ASRConfig.load() {
            print("[App] ASR 配置加载成功，双模式均可用")
            return VolcanoASRClient(config: config)
        }
        print("[App] 错误：未找到 ASR 配置，请配置 ~/.config/volc_asr/api_keys.env")
        ASRConfig.createExampleConfig()
        return VolcanoASRClient(appId: "", accessToken: "")
    }()
    let keyboardManager = KeyboardManager.shared

    // 双模式窗口
    let inputWindow = InputWindowController()  // 按下切换模式
    let simpleInputWindow = SimpleInputWindowController()  // 按住说话模式

    let settingsController = PreferencesWindowController()
    let permissionSetupController = PermissionSetupWindowController()

    var isRecording = false
    private var isStarting = false  // 防止连接建立前重复触发 startRecording
    var currentText = ""  // 当前识别的文本
    private var lastFrontmostApp: NSRunningApplication?  // 记录开始录音时的前台应用

    // 当前活跃的输入模式（由触发的快捷键决定）
    private var activeInputMode: InputMode = .pressToToggle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 日志重定向到文件（方便调试，因为 GUI 应用看不到控制台）
        let logsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/VoiceInput")
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
        let logPath = logsDir.appendingPathComponent("voice_input.log").path
        freopen(logPath, "a+", stdout)
        freopen(logPath, "a+", stderr)

        print("\n\n--- [App] 启动于 \(Date()) ---")
        print("[App] 日志正在输出到: \(logPath)")

        setupStatusItem()
        setupHotKeys()
        setupInputWindows()

        // 权限引导：延迟检查，给窗口足够时间初始化
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.checkPermissionsOnLaunch()
        }

        // 监听配置变更
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleConfigChanged(_:)),
            name: NSNotification.Name("ASRConfigChanged"),
            object: nil)

        // 监听权限设置窗口打开请求
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleShowPermissionSetup),
            name: NSNotification.Name("ShowPermissionSetup"),
            object: nil)

        // 设置 ASR 回调
        asrClient.onResult = { [weak self] text, isFinalUtterance, isCorrected in
            guard let self = self else { return }

            if isCorrected {
                print("收到校正结果: \(text)")
            } else {
                print("收到实时结果: \(text) (final: \(isFinalUtterance))")
            }

            self.currentText = text

            // 根据当前活跃模式更新对应窗口
            if self.activeInputMode == .holdToSpeak {
                self.simpleInputWindow.updateText(text, isPending: !isFinalUtterance)
            } else {
                self.inputWindow.updateText(text, isPending: !isFinalUtterance)
            }
        }

        asrClient.onError = { [weak self] error in
            print("[App] ASR 报错: \(error.localizedDescription)")
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "语音识别错误"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.addButton(withTitle: "确定")
                alert.runModal()
                self?.stopRecording()
            }
        }

        // 设置录音回调
        recorder.onAudioData = { [weak self] data in
            self?.asrClient.sendAudio(data: data)
        }

        recorder.onVolumeChanged = { [weak self] volume in
            if self?.activeInputMode == .holdToSpeak {
                self?.simpleInputWindow.updateVolume(volume)
            } else {
                self?.inputWindow.updateVolume(volume)
            }
        }

        recorder.onError = { error in
            print("[App] 录音报错: \(error.localizedDescription)")
        }

        // 静音检测
        recorder.onSilenceDetected = { [weak self] in
            print("[App] 警告：检测到麦克风无声音输入")
            if self?.activeInputMode == .holdToSpeak {
                self?.simpleInputWindow.showSilenceWarning()
            } else {
                self?.inputWindow.showSilenceWarning()
            }
        }

        print("[App] 初始化完成，菜单栏图标应该可见")
    }

    func setupStatusItem() {
        print("[App] 正在设置菜单栏图标...")
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "语音输入")
            print("[App] 菜单栏图标已设置")
        }

        let menu = NSMenu()

        // 显示快捷键（不可点击）
        let holdKeyItem = NSMenuItem(title: "按住说话: fn ⌃", action: nil, keyEquivalent: "")
        holdKeyItem.isEnabled = false
        menu.addItem(holdKeyItem)

        let toggleKeyItem = NSMenuItem(title: "按下说话: ⌃ ⌥ ⌘ 6", action: nil, keyEquivalent: "")
        toggleKeyItem.isEnabled = false
        menu.addItem(toggleKeyItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(
            title: "设置", action: #selector(showSettings), keyEquivalent: "")
        settingsItem.image = nil
        menu.addItem(settingsItem)

        let quitItem = NSMenuItem(
            title: "退出", action: #selector(quitApp), keyEquivalent: "")
        quitItem.image = nil
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu

        // 更新菜单中的快捷键显示
        updateMenuHotKeyDisplay()
    }

    private func updateMenuHotKeyDisplay(config: ASRConfig? = nil) {
        guard let menu = statusItem?.menu, menu.items.count >= 2 else { return }

        if let config = config ?? ASRConfig.load() {
            // 按住说话快捷键
            let holdKeyStr = formatHotKeyString(
                code: config.holdHotKeyCode, mods: config.holdHotKeyModifiers)
            menu.items[0].title = "按住说话: \(holdKeyStr)"

            // 按下切换快捷键
            let toggleKeyStr = formatHotKeyString(
                code: config.startHotKeyCode, mods: config.startHotKeyModifiers)
            menu.items[1].title = "按下说话: \(toggleKeyStr)"
        }
    }

    private func formatHotKeyString(code: UInt16, mods: NSEvent.ModifierFlags) -> String {
        var parts: [String] = []
        if mods.contains(.function) { parts.append("fn") }
        if mods.contains(.control) { parts.append("⌃") }
        if mods.contains(.option) { parts.append("⌥") }
        if mods.contains(.shift) { parts.append("⇧") }
        if mods.contains(.command) { parts.append("⌘") }

        // 检查是否是修饰键本身
        let modifierKeyCodes: [UInt16] = [55, 54, 56, 60, 58, 61, 59, 62, 63]
        if !modifierKeyCodes.contains(code) {
            parts.append(keyName(from: code))
        }

        return parts.joined(separator: " ")
    }

    private func keyName(from code: UInt16) -> String {
        let charMap: [UInt16: String] = [
            0: "A", 11: "B", 8: "C", 2: "D", 14: "E", 3: "F", 5: "G", 4: "H", 34: "I", 38: "J",
            40: "K", 37: "L", 46: "M", 45: "N", 31: "O", 35: "P", 12: "Q", 15: "R", 1: "S",
            17: "T", 32: "U", 9: "V", 13: "W", 7: "X", 16: "Y", 6: "Z",
            18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6", 26: "7", 28: "8", 25: "9",
            29: "0", 36: "↩", 48: "⇥", 49: "␣", 51: "⌫", 53: "⎋",
        ]
        return charMap[code] ?? ""
    }

    @objc func handleConfigChanged(_ notification: Notification) {
        let config = notification.object as? ASRConfig ?? ASRConfig.load()
        if let config = config {
            print("[App] 收到配置变更通知，正在刷新核心模块...")

            // 1. 刷新快捷键
            setupHotKeys(with: config)

            // 2. 刷新 ASR Client
            self.asrClient.updateConfig(config)

            // 3. 更新菜单显示
            updateMenuHotKeyDisplay(config: config)

            print("[App] 核心模块刷新完成")
        }
    }

    @objc func handleShowPermissionSetup() {
        permissionSetupController.show()
    }

    func setupHotKeys(with config: ASRConfig? = nil) {
        let targetConfig = config ?? ASRConfig.load()
        if let config = targetConfig {
            // 同时注册两种模式的快捷键
            let keys: [(id: String, code: UInt16, mods: NSEvent.ModifierFlags)] = [
                // 按住说话快捷键
                (id: "hold", code: config.holdHotKeyCode, mods: config.holdHotKeyModifiers),
                // 按下切换快捷键
                (id: "start", code: config.startHotKeyCode, mods: config.startHotKeyModifiers),
                (id: "stop", code: config.stopHotKeyCode, mods: config.stopHotKeyModifiers),
            ]

            print("[App] 正在注册双模式快捷键...")
            print(
                "[App]   - 按住说话: code=\(config.holdHotKeyCode), mods=\(config.holdHotKeyModifiers.rawValue)"
            )
            print(
                "[App]   - 按下切换: code=\(config.startHotKeyCode), mods=\(config.startHotKeyModifiers.rawValue)"
            )

            HotKeyManager.shared.register(keys: keys)

            // 按下回调
            HotKeyManager.shared.onHotKeyPressed = { [weak self] id in
                DispatchQueue.main.async {
                    guard let self = self else { return }

                    if id == "hold" {
                        // 按住说话模式：设置模式并开始录音
                        self.activeInputMode = .holdToSpeak
                        self.startRecording()
                    } else if id == "start" {
                        // 按下切换模式：设置模式并切换录音状态
                        self.activeInputMode = .pressToToggle
                        self.toggleRecording()
                    } else if id == "stop" {
                        // 按下切换模式：确认输入
                        if self.isRecording && self.activeInputMode == .pressToToggle {
                            self.inputWindow.insertClicked()
                        }
                    }
                }
            }

            // 松开回调（仅按住说话模式使用）
            HotKeyManager.shared.onHotKeyReleased = { [weak self] id in
                DispatchQueue.main.async {
                    guard let self = self else { return }

                    if id == "hold" && self.isRecording && self.activeInputMode == .holdToSpeak {
                        // 按住说话模式：松开时自动粘贴
                        self.insertAndStopRecording()
                    }
                }
            }
        }
    }

    func setupInputWindows() {
        // 设置按下切换模式窗口回调
        inputWindow.onConfirm = { [weak self] text in
            guard let self = self else { return }
            print("[App] 用户确认插入文本: \(text)")
            self.stopRecording()

            if !text.isEmpty {
                self.keyboardManager.writeToClipboard(text)

                if let app = self.lastFrontmostApp {
                    print("[App] 正在尝试激活原应用: \(app.localizedName ?? "未知")")
                    app.activateApp()
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.keyboardManager.paste()
                }
            }
        }

        inputWindow.onCancel = { [weak self] in
            print("[App] 用户取消输入")
            self?.stopRecording()
        }

        inputWindow.onClear = { [weak self] in
            print("[App] 用户清空内容，重启录音流程")
            self?.asrClient.reset()
        }

        // 设置按住说话模式窗口回调
        simpleInputWindow.onCancel = { [weak self] in
            print("[App] 用户取消输入（简洁模式）")
            self?.stopRecording()
        }
    }

    /// 按住说话模式下松开时：插入文本并停止录音
    private func insertAndStopRecording() {
        let text = simpleInputWindow.getCurrentText()
        print("[App] 按住说话模式松开，插入文本: \(text)")

        stopRecording()

        if !text.isEmpty {
            keyboardManager.writeToClipboard(text)

            if let app = lastFrontmostApp {
                print("[App] 正在尝试激活原应用: \(app.localizedName ?? "未知")")
                app.activateApp()
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.keyboardManager.paste()
            }
        }
    }

    @objc func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    func startRecording() {
        guard !isStarting && !isRecording else {
            print("[App] startRecording 忽略：已在录音中或正在连接")
            return
        }

        // 权限检查
        MicrophoneManager.shared.checkPermission { [weak self] granted in
            guard let self = self else { return }

            if !granted {
                MicrophoneManager.shared.showPermissionAlert()
                return
            }

            // 在显示自己的窗口前，先记录谁是前台
            self.lastFrontmostApp = NSWorkspace.shared.frontmostApplication
            print("[App] 记录当前前台应用: \(self.lastFrontmostApp?.localizedName ?? "无")")

            print("[App] 开始启动录音流程（模式: \(self.activeInputMode.rawValue)）")

            self.isStarting = true
            // 强力重置
            self.isRecording = false
            self.asrClient.disconnect()

            // 根据模式显示对应窗口
            DispatchQueue.main.async {
                self.currentText = ""

                if self.activeInputMode == .holdToSpeak {
                    self.simpleInputWindow.updateText("", isPending: false)
                    self.simpleInputWindow.show()
                    self.simpleInputWindow.updateRecordingState(true)
                } else {
                    self.inputWindow.updateText("", isPending: false)
                    self.inputWindow.show()
                    self.inputWindow.updateRecordingState(true)
                }
            }

            // 绑定连接成功后的回调
            self.asrClient.onConnected = { [weak self] in
                guard let self = self else { return }
                print("[App] ASR 连接已就绪，启动识别")
                self.asrClient.startRecognition()
                self.recorder.start()
                self.isStarting = false
                self.isRecording = true
                DispatchQueue.main.async {
                    self.updateUI()
                }
            }

            // 启动连接
            self.asrClient.connect()
        }
    }

    func stopRecording() {
        print("[App] 停止录音流程")
        recorder.stop()
        if asrClient.isRecognizing {
            asrClient.sendAudio(data: Data(), isLast: true)
        }
        isStarting = false
        isRecording = false

        // 根据模式隐藏对应窗口
        if activeInputMode == .holdToSpeak {
            simpleInputWindow.hide()
        } else {
            inputWindow.hide()
        }

        updateUI()
    }

    func updateUI() {
        if let button = statusItem?.button {
            button.image = NSImage(
                systemSymbolName: isRecording ? "mic.and.signal.meter.fill" : "mic.fill",
                accessibilityDescription: nil)
        }
    }

    @objc func showSettings() {
        settingsController.show()
    }

    @objc func showPermissionSetup() {
        permissionSetupController.show()
    }

    /// 检查启动时的权限状态
    private func checkPermissionsOnLaunch() {
        // 检查是否需要显示权限引导窗口
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        let micGranted = (micStatus == .authorized)

        let axOptions = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let axGranted = AXIsProcessTrustedWithOptions(axOptions as CFDictionary)

        if !micGranted || !axGranted {
            print("[App] 检测到权限缺失，显示权限引导窗口")
            permissionSetupController.onComplete = { [weak self] in
                print("[App] 权限设置完成")
                self?.updatePermissionStatusInMenu()
            }
            permissionSetupController.show()
        } else {
            print("[App] 所有权限已就绪")
        }

        // 更新菜单中的权限状态
        updatePermissionStatusInMenu()
    }

    /// 更新菜单中的权限状态显示
    private func updatePermissionStatusInMenu() {
        guard let menu = statusItem?.menu else { return }

        // 移除旧的权限状态项（如果存在）
        if let existingItem = menu.item(withTag: 1001) {
            menu.removeItem(existingItem)
        }

        // 检查权限状态
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        let micGranted = (micStatus == .authorized)

        let axOptions = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let axGranted = AXIsProcessTrustedWithOptions(axOptions as CFDictionary)

        // 如果有权限缺失，显示警告项
        if !micGranted || !axGranted {
            let warningText = "⚠️ 权限未完整"
            let warningItem = NSMenuItem(
                title: warningText, action: #selector(showPermissionSetup), keyEquivalent: "")
            warningItem.tag = 1001
            warningItem.target = self
            menu.insertItem(warningItem, at: 0)
            menu.insertItem(NSMenuItem.separator(), at: 1)
        }
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
