import Cocoa

class HotKeyManager {
    static let shared = HotKeyManager()

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var flagsMonitor: Any?
    private var localFlagsMonitor: Any?

    private struct HotKey {
        let identifier: String
        let keyCode: UInt16  // 0 表示纯修饰键组合
        let modifiers: NSEvent.ModifierFlags
        let isModifiersOnly: Bool  // 是否为纯修饰键组合
    }

    private var registeredKeys: [HotKey] = []

    // 记录当前按下的热键（用于检测松开）
    private var activeHotKeyId: String?

    var onHotKeyPressed: ((String) -> Void)?
    var onHotKeyReleased: ((String) -> Void)?

    private init() {}

    /// 注册一组热键
    /// - 如果 keyCode > 0，则为"修饰键+普通键"组合
    /// - 如果 keyCode == 0 或需要纯修饰键触发，则通过 flagsChanged 检测
    func register(keys: [(id: String, code: UInt16, mods: NSEvent.ModifierFlags)]) {
        unregister()

        self.registeredKeys = keys.map {
            // 检测是否为纯修饰键组合（keyCode 对应的是修饰键本身）
            // Control: 59, 62; Shift: 56, 60; Option: 58, 61; Command: 55, 54
            let isModKey = [55, 54, 56, 60, 58, 61, 59, 62, 63].contains($0.code)  // 63 是 fn

            return HotKey(
                identifier: $0.id,
                keyCode: $0.code,
                modifiers: $0.mods.intersection([.command, .shift, .option, .control, .function]),
                isModifiersOnly: isModKey || $0.code == 0
            )
        }

        // 1. 全局 keyDown/keyUp 监听（用于普通键组合）
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp]) {
            [weak self] event in
            self?.handleKeyEvent(event)
        }

        // 2. 本地 keyDown/keyUp 监听
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) {
            [weak self] event in
            self?.handleKeyEvent(event)
            return event
        }

        // 3. 全局修饰键变化监听（用于纯修饰键组合和松开检测）
        flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) {
            [weak self] event in
            self?.handleFlagsChanged(event)
        }

        // 4. 本地修饰键变化监听
        localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) {
            [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }

        let modOnlyCount = registeredKeys.filter { $0.isModifiersOnly }.count
        print("[HotKeyManager] 已注册 \(registeredKeys.count) 个热键（其中 \(modOnlyCount) 个为纯修饰键组合）")
    }

    private func handleKeyEvent(_ event: NSEvent) {
        let eventModifiers = event.modifierFlags.intersection([
            .command, .shift, .option, .control, .function,
        ])

        for key in registeredKeys where !key.isModifiersOnly {
            if event.keyCode == key.keyCode && eventModifiers == key.modifiers {
                if event.type == .keyDown {
                    if activeHotKeyId != key.identifier {
                        activeHotKeyId = key.identifier
                        print("[HotKeyManager] 按下热键: \(key.identifier)")
                        onHotKeyPressed?(key.identifier)
                    }
                } else if event.type == .keyUp {
                    if activeHotKeyId == key.identifier {
                        activeHotKeyId = nil
                        print("[HotKeyManager] 松开热键: \(key.identifier)")
                        onHotKeyReleased?(key.identifier)
                    }
                }
                break
            }
        }
    }

    /// 处理修饰键变化
    private func handleFlagsChanged(_ event: NSEvent) {
        let currentMods = event.modifierFlags.intersection([
            .command, .shift, .option, .control, .function,
        ])

        // 1. 检测纯修饰键组合的按下
        for key in registeredKeys where key.isModifiersOnly {
            // 检查当前修饰键是否完全匹配
            if currentMods == key.modifiers && activeHotKeyId == nil {
                activeHotKeyId = key.identifier
                print("[HotKeyManager] 修饰键组合触发: \(key.identifier) (mods: \(currentMods.rawValue))")
                onHotKeyPressed?(key.identifier)
                return
            }
        }

        // 2. 检测松开
        if let activeId = activeHotKeyId {
            guard let activeKey = registeredKeys.first(where: { $0.identifier == activeId }) else {
                return
            }

            // 如果修饰键不再满足要求，视为松开
            if !currentMods.contains(activeKey.modifiers) {
                print("[HotKeyManager] 修饰键释放，触发松开: \(activeId)")
                activeHotKeyId = nil
                onHotKeyReleased?(activeId)
            }
        }
    }

    func unregister() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        if let monitor = flagsMonitor {
            NSEvent.removeMonitor(monitor)
            flagsMonitor = nil
        }
        if let monitor = localFlagsMonitor {
            NSEvent.removeMonitor(monitor)
            localFlagsMonitor = nil
        }
        registeredKeys.removeAll()
        activeHotKeyId = nil
    }
}
