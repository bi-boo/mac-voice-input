import AppKit
import CoreGraphics
import Foundation

class KeyboardManager {
    static let shared = KeyboardManager()

    private init() {}

    /// 模拟按下 Cmd+V 进行粘贴
    func paste() {
        // 使用 .hidSystemState 确保事件被系统级捕获
        let source = CGEventSource(stateID: .hidSystemState)

        // Command 键码是 0x37
        // V 键码是 0x09

        let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        vDown?.flags = .maskCommand

        let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        vUp?.flags = .maskCommand

        // 发送按键序列：keyUp 延迟 10ms 发送，避免阻塞主线程
        vDown?.post(tap: .cgAnnotatedSessionEventTap)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            vUp?.post(tap: .cgAnnotatedSessionEventTap)
        }

        print("[KeyboardManager] 已执行 Cmd+V 粘贴模拟")
    }

    /// 将文本写入剪贴板
    func writeToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// 获取当前活跃的应用程序名称
    func getActiveAppName() -> String? {
        if let frontmostApp = NSWorkspace.shared.frontmostApplication {
            return frontmostApp.localizedName
        }
        return nil
    }

    /// 激活指定的应用程序
    func activateApp(bundleIdentifier: String) {
        if let app = NSRunningApplication.runningApplications(
            withBundleIdentifier: bundleIdentifier
        ).first {
            app.activateApp()
        }
    }
}
