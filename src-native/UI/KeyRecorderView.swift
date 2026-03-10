import Cocoa

class KeyRecorderView: NSButton {
    var keyCode: UInt16?
    var modifierFlags: NSEvent.ModifierFlags?

    private var isRecording = false
    // 记录录制过程中按下修饰键的峰值（用于支持单修饰键热键）
    private var peakModifiers: NSEvent.ModifierFlags = []
    private var peakKeyCode: UInt16 = 0

    var onKeyRecorded: ((UInt16, NSEvent.ModifierFlags) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        self.bezelStyle = .rounded
        self.setButtonType(.pushOnPushOff)
        self.title = "点击录制"
    }

    override func mouseDown(with event: NSEvent) {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        peakModifiers = []
        peakKeyCode = 0
        self.title = "请按下按键..."
        self.highlight(true)
        window?.makeFirstResponder(self)
    }

    private func stopRecording() {
        isRecording = false
        self.highlight(false)
        updateTitle()
    }

    override func keyDown(with event: NSEvent) {
        if isRecording {
            self.keyCode = event.keyCode
            self.modifierFlags = event.modifierFlags.intersection([
                .command, .shift, .option, .control, .function,
            ])
            peakModifiers = []
            peakKeyCode = 0
            stopRecording()
            if let code = keyCode, let mods = modifierFlags {
                onKeyRecorded?(code, mods)
            }
        } else {
            super.keyDown(with: event)
        }
    }

    // 监听修饰键变化以捕获纯修饰键组合（包括单个修饰键，如 fn）
    override func flagsChanged(with event: NSEvent) {
        if isRecording {
            let mods = event.modifierFlags.intersection([
                .command, .shift, .option, .control, .function,
            ])

            let currentCount = [
                mods.contains(.command), mods.contains(.shift),
                mods.contains(.option), mods.contains(.control),
                mods.contains(.function),
            ].filter { $0 }.count

            let peakCount = [
                peakModifiers.contains(.command), peakModifiers.contains(.shift),
                peakModifiers.contains(.option), peakModifiers.contains(.control),
                peakModifiers.contains(.function),
            ].filter { $0 }.count

            if currentCount > peakCount {
                // 修饰键增加，更新峰值记录
                peakModifiers = mods
                peakKeyCode = event.keyCode
            } else if currentCount < peakCount && peakCount > 0 {
                // 修饰键减少（松开），以峰值组合作为录制结果（支持单修饰键）
                self.keyCode = peakKeyCode
                self.modifierFlags = peakModifiers
                peakModifiers = []
                peakKeyCode = 0
                stopRecording()
                if let code = keyCode, let flags = modifierFlags {
                    onKeyRecorded?(code, flags)
                }
            }
        }
        super.flagsChanged(with: event)
    }

    func setKey(code: UInt16, mods: NSEvent.ModifierFlags) {
        self.keyCode = code
        self.modifierFlags = mods
        updateTitle()
    }

    private func updateTitle() {
        guard let code = keyCode, let mods = modifierFlags else {
            self.title = "点击录制"
            return
        }

        var parts: [String] = []

        // 添加修饰键符号
        if mods.contains(.function) { parts.append("fn") }
        if mods.contains(.control) { parts.append("⌃") }
        if mods.contains(.option) { parts.append("⌥") }
        if mods.contains(.shift) { parts.append("⇧") }
        if mods.contains(.command) { parts.append("⌘") }

        // 检查 keyCode 是否是修饰键本身
        let modifierKeyCodes: [UInt16] = [
            55, 54,  // Command (左/右)
            56, 60,  // Shift (左/右)
            58, 61,  // Option (左/右)
            59, 62,  // Control (左/右)
            63,  // fn
        ]

        // 如果 keyCode 不是修饰键本身，添加按键名称
        if !modifierKeyCodes.contains(code) {
            parts.append(keyName(from: code))
        }

        // 如果只有修饰键（如 fn+Control），确保显示正确
        if parts.isEmpty {
            self.title = "点击录制"
        } else {
            self.title = parts.joined(separator: " ")
        }
    }

    private func keyName(from code: UInt16) -> String {
        let specialMap: [UInt16: String] = [
            36: "↩", 48: "⇥", 49: "␣", 51: "⌫", 53: "⎋",
            123: "←", 124: "→", 125: "↓", 126: "↑",
        ]
        if let special = specialMap[code] { return special }

        // 字母和数字映射
        let charMap: [UInt16: String] = [
            0: "A", 11: "B", 8: "C", 2: "D", 14: "E", 3: "F", 5: "G", 4: "H", 34: "I", 38: "J",
            40: "K", 37: "L", 46: "M", 45: "N", 31: "O", 35: "P", 12: "Q", 15: "R", 1: "S",
            17: "T", 32: "U", 9: "V", 13: "W", 7: "X", 16: "Y", 6: "Z",
            18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6", 26: "7", 28: "8", 25: "9",
            29: "0",
        ]
        return charMap[code] ?? "Key:\(code)"
    }

    override var acceptsFirstResponder: Bool { true }
}
