import AppKit

/// 向前兼容的应用激活扩展
/// NSApplication.activate(ignoringOtherApps:) 在 macOS 14 中废弃
/// NSRunningApplication.activate(options:) 在 macOS 14 中废弃
extension NSApplication {
    func activateApp() {
        if #available(macOS 14.0, *) {
            activate()
        } else {
            activate(ignoringOtherApps: true)
        }
    }
}

extension NSRunningApplication {
    func activateApp() {
        if #available(macOS 14.0, *) {
            activate()
        } else {
            activate(options: .activateIgnoringOtherApps)
        }
    }
}
