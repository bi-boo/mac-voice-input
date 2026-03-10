import ApplicationServices
import Cocoa

class AccessibilityManager {
    static let shared = AccessibilityManager()

    private init() {}

    /// 检查是否拥有辅助功能权限
    func checkPermission() -> Bool {
        // trust 参数为 false 时仅检查不弹窗，为 true 时若无权限会弹出系统授权提醒
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    /// 请求权限（如果当前没有权限，会弹出系统授权对话框）
    func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    /// 引导用户手动打开系统设置中的隐私页面
    func openAccessibilitySettings() {
        let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    /// 弹出一个友好的引导窗口
    func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "需要辅助功能权限"
        alert.informativeText = "为了能够自动将识别出的文字粘贴到当前窗口，此应用需要“辅助功能”权限。请在系统设置中允许此应用，然后重启应用。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "去设置")
        alert.addButton(withTitle: "稍后再说")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            openAccessibilitySettings()
        }
    }
}
