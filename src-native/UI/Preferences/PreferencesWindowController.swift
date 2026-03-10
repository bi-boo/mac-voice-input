import Cocoa

class PreferencesWindowController: NSWindowController {

    private let tabViewController = NSTabViewController()

    convenience init() {
        // 创建主窗口
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "偏好设置"
        window.center()

        // 禁止调整大小
        window.styleMask.remove(.resizable)

        self.init(window: window)

        setupTabs()
        setupToolbar()
    }

    private func setupTabs() {
        tabViewController.view.frame = NSRect(x: 0, y: 0, width: 500, height: 400)

        // 添加通用页（包含快捷键、权限、开机自启动）
        let generalVC = GeneralViewController()
        generalVC.title = "通用"
        let generalItem = NSTabViewItem(viewController: generalVC)
        generalItem.label = "通用"
        generalItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "通用")
        tabViewController.addTabViewItem(generalItem)

        // 添加 API 配置页
        let apiConfigVC = APIConfigViewController()
        apiConfigVC.title = "API 配置"
        let apiConfigItem = NSTabViewItem(viewController: apiConfigVC)
        apiConfigItem.label = "API 配置"
        apiConfigItem.image = NSImage(systemSymbolName: "key", accessibilityDescription: "API 配置")
        tabViewController.addTabViewItem(apiConfigItem)

        tabViewController.tabStyle = .toolbar

        self.contentViewController = tabViewController
    }

    private func setupToolbar() {
        // NSTabViewController 设为 tabStyle = .toolbar 后会自动管理 Toolbar
        // 这里不需要手动创建 NSToolbar，除非需要自定义
    }

    func show() {
        self.showWindow(nil)
        NSApp.activateApp()
        self.window?.makeKeyAndOrderFront(nil)
    }
}
