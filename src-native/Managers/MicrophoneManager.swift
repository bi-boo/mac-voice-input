import AVFoundation
import Cocoa

class MicrophoneManager {
    static let shared = MicrophoneManager()

    private init() {}

    /// 检查并请求麦克风权限
    func checkPermission(completion: @escaping (Bool) -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)

        switch status {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }

    /// 显示权限提醒
    func showPermissionAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "麦克风权限未启用"
            alert.informativeText = "请在“系统设置 > 隐私与安全性 > 麦克风”中允许“语音输入法”访问您的麦克风，否则无法进行语音识别。"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "前往设置")
            alert.addButton(withTitle: "取消")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                if let url = URL(
                    string:
                        "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
                ) {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
}
