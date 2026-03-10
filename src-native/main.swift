import Cocoa

let app = NSApplication.shared
app.setActivationPolicy(.accessory)  // 设置为菜单栏应用（无 Dock 图标）

let delegate = AppDelegate()
app.delegate = delegate

// 确保应用激活
app.activateApp()

print("[main] 启动应用运行循环...")
app.run()
