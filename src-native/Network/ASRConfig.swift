import AppKit
import Foundation

/// 语音输入模式
enum InputMode: String, Codable {
    case holdToSpeak = "hold"  // 按住说话：按住快捷键时录音，松开自动粘贴
    case pressToToggle = "toggle"  // 按下切换：按下开始录音，再按确认键输出
}

/// 火山引擎 ASR 服务配置
struct ASRConfig {
    let appKey: String
    let accessKey: String
    let resourceId: String

    // 输入模式
    let inputMode: InputMode  // 默认 .pressToToggle

    // 快捷键配置：按住说话模式
    let holdHotKeyCode: UInt16  // 默认 22 (6)
    let holdHotKeyModifiers: NSEvent.ModifierFlags  // 默认 [.control, .option, .command]

    // 快捷键配置：按下切换模式 - 开始录音
    let startHotKeyCode: UInt16  // 默认 22 (6)
    let startHotKeyModifiers: NSEvent.ModifierFlags  // 默认 [.control, .option, .command]

    // 快捷键配置：结束/提交录音
    let stopHotKeyCode: UInt16  // 默认 36 (Return)
    let stopHotKeyModifiers: NSEvent.ModifierFlags  // 默认 []

    // ASR 技术参数
    let modelName: String
    let enableITN: Bool
    let enablePunctuation: Bool
    let showUtterances: Bool
    let resultType: String
    let audioFormat: String
    let audioSampleRate: Int

    // 新增控制参数
    let enableNonStream: Bool
    let enableDDC: Bool
    let endWindowSize: Int
    let enableAccelerateText: Bool
    let accelerateScore: Int

    /// 默认配置文件路径
    static let configPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/volc_asr/api_keys.env")

    /// 从环境变量或配置文件加载配置
    static func load() -> ASRConfig? {
        // 优先从环境变量读取
        if let appKey = ProcessInfo.processInfo.environment["VOLC_APP_KEY"],
            let accessKey = ProcessInfo.processInfo.environment["VOLC_ACCESS_KEY"]
        {
            let resourceId =
                ProcessInfo.processInfo.environment["VOLC_RESOURCE_ID"]
                ?? "volc.seedasr.sauc.duration"
            return ASRConfig(
                appKey: appKey,
                accessKey: accessKey,
                resourceId: resourceId,
                inputMode: .pressToToggle,
                holdHotKeyCode: 59,
                holdHotKeyModifiers: [.function, .control],
                startHotKeyCode: 22,
                startHotKeyModifiers: [.control, .option, .command],
                stopHotKeyCode: 36,
                stopHotKeyModifiers: [],
                modelName: "bigmodel",
                enableITN: true,
                enablePunctuation: true,
                showUtterances: true,
                resultType: "full",
                audioFormat: "pcm",
                audioSampleRate: 16000,
                enableNonStream: false,
                enableDDC: false,
                endWindowSize: 800,
                enableAccelerateText: false,
                accelerateScore: 0
            )
        }

        // 优先从项目目录读取 (针对命令行运行)
        let projectConfigPath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("api_keys.env")
        if let config = loadFromFile(projectConfigPath) {
            return config
        }

        // 针对 GUI 运行：尝试查找 .app 同级路径
        let bundleURL = Bundle.main.bundleURL.deletingLastPathComponent()
        let appSiblingConfig = bundleURL.appendingPathComponent("api_keys.env")
        if let config = loadFromFile(appSiblingConfig) {
            return config
        }

        // 尝试向上找一级（如果是 build/语音输入法.app）
        let appParentConfig = bundleURL.deletingLastPathComponent().appendingPathComponent(
            "api_keys.env")
        if let config = loadFromFile(appParentConfig) {
            return config
        }

        // 尝试从用户配置目录读取
        if let config = loadFromFile(configPath) {
            return config
        }

        return nil
    }

    /// 从 .env 文件加载配置
    private static func loadFromFile(_ path: URL) -> ASRConfig? {
        guard let content = try? String(contentsOf: path, encoding: .utf8) else { return nil }

        var dict: [String: String] = [:]
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            let parts = trimmed.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
                var value = String(parts[1]).trimmingCharacters(in: .whitespaces)
                if (value.hasPrefix("\"") && value.hasSuffix("\""))
                    || (value.hasPrefix("'") && value.hasSuffix("'"))
                {
                    value = String(value.dropFirst().dropLast())
                }
                dict[key] = value
            }
        }

        guard let appKey = dict["VOLC_APP_KEY"], let accessKey = dict["VOLC_ACCESS_KEY"] else {
            return nil
        }

        let resourceId = dict["VOLC_RESOURCE_ID"] ?? "volc.seedasr.sauc.duration"

        // 输入模式
        let inputModeStr = dict["INPUT_MODE"] ?? "toggle"
        let inputMode = InputMode(rawValue: inputModeStr) ?? .pressToToggle

        // 按住说话快捷键 (fn+Control)
        let holdCode = UInt16(dict["HOLD_HOTKEY_CODE"] ?? "59") ?? 59
        let holdMods = NSEvent.ModifierFlags(
            rawValue: UInt(dict["HOLD_HOTKEY_MODS"] ?? "8650752") ?? 8_650_752)  // fn + control

        // 按下切换快捷键
        let startCode = UInt16(dict["START_HOTKEY_CODE"] ?? "22") ?? 22
        let startMods = NSEvent.ModifierFlags(
            rawValue: UInt(dict["START_HOTKEY_MODS"] ?? "1835008") ?? 1_835_008)  // Default: Ctrl+Opt+Cmd+6

        let stopCode = UInt16(dict["STOP_HOTKEY_CODE"] ?? "36") ?? 36
        let stopMods = NSEvent.ModifierFlags(rawValue: UInt(dict["STOP_HOTKEY_MODS"] ?? "0") ?? 0)

        // 尝试加载技术参数设置 (asr_settings.json)
        var settings: ASRSettings? = nil

        // 1. 优先尝试从 api_keys.env 同级目录读取 (方便开发调试)
        let settingsPath = path.deletingLastPathComponent().appendingPathComponent(
            "asr_settings.json")
        settings = loadSettings(from: settingsPath)

        // 2. 如果没找到，尝试从 Bundle Resources 读取 (针对打包后的应用)
        if settings == nil {
            if let bundlePath = Bundle.main.url(forResource: "asr_settings", withExtension: "json")
            {
                settings = loadSettings(from: bundlePath)
            }
        }

        return ASRConfig(
            appKey: appKey,
            accessKey: accessKey,
            resourceId: resourceId,
            inputMode: inputMode,
            holdHotKeyCode: holdCode,
            holdHotKeyModifiers: holdMods,
            startHotKeyCode: startCode,
            startHotKeyModifiers: startMods,
            stopHotKeyCode: stopCode,
            stopHotKeyModifiers: stopMods,
            modelName: settings?.modelName?.value ?? "bigmodel",
            enableITN: settings?.enableITN?.value ?? true,
            enablePunctuation: settings?.enablePunctuation?.value ?? true,
            showUtterances: settings?.showUtterances?.value ?? true,
            resultType: settings?.resultType?.value ?? "full",
            audioFormat: settings?.audio?.format?.value ?? "pcm",
            audioSampleRate: settings?.audio?.sampleRate?.value ?? 16000,
            enableNonStream: settings?.enableNonStream?.value ?? false,
            enableDDC: settings?.enableDDC?.value ?? false,
            endWindowSize: settings?.endWindowSize?.value ?? 800,
            enableAccelerateText: settings?.enableAccelerateText?.value ?? false,
            accelerateScore: settings?.accelerateScore?.value ?? 0
        )
    }

    /// 辅助结构体用于解析带说明的 JSON
    private struct ConfigItem<T: Codable>: Codable {
        let value: T
    }

    private struct ASRSettings: Codable {
        let modelName: ConfigItem<String>?
        let enableITN: ConfigItem<Bool>?
        let enablePunctuation: ConfigItem<Bool>?
        let showUtterances: ConfigItem<Bool>?
        let resultType: ConfigItem<String>?
        let enableNonStream: ConfigItem<Bool>?
        let enableDDC: ConfigItem<Bool>?
        let endWindowSize: ConfigItem<Int>?
        let enableAccelerateText: ConfigItem<Bool>?
        let accelerateScore: ConfigItem<Int>?
        let audio: AudioSettings?

        struct AudioSettings: Codable {
            let format: ConfigItem<String>?
            let sampleRate: ConfigItem<Int>?

            enum CodingKeys: String, CodingKey {
                case format
                case sampleRate = "sample_rate"
            }
        }

        enum CodingKeys: String, CodingKey {
            case modelName = "model_name"
            case enableITN = "enable_itn"
            case enablePunctuation = "enable_punctuation"
            case showUtterances = "show_utterances"
            case resultType = "result_type"
            case enableNonStream = "enable_nonstream"
            case enableDDC = "enable_ddc"
            case endWindowSize = "end_window_size"
            case enableAccelerateText = "enable_accelerate_text"
            case accelerateScore = "accelerate_score"
            case audio
        }
    }

    private static func loadSettings(from path: URL) -> ASRSettings? {
        guard let data = try? Data(contentsOf: path) else {
            print("[ASRConfig] 未找到 settings 文件: \(path.path)，将使用默认值")
            return nil
        }
        return try? JSONDecoder().decode(ASRSettings.self, from: data)
    }

    /// 创建示例配置文件
    static func createExampleConfig() {
        let exampleContent = """
            # 火山引擎 ASR API 配置
            # 请在火山引擎控制台获取以下信息

            # APP ID（必填）
            VOLC_APP_KEY=你的AppID

            # Access Token（必填）
            VOLC_ACCESS_KEY=你的AccessToken

            # 资源 ID（可选，默认使用小时版）
            VOLC_RESOURCE_ID=volc.bigasr.sauc.duration

            # 快捷键配置（建议通过设置页面录制）
            START_HOTKEY_CODE=9
            START_HOTKEY_MODS=1179648
            STOP_HOTKEY_CODE=36
            STOP_HOTKEY_MODS=0
            """

        let configDir = configPath.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        try? exampleContent.write(to: configPath, atomically: true, encoding: .utf8)
        print("[ASRConfig] 已创建示例配置文件: \(configPath.path)")
    }

    /// 保存配置到文件
    func save() -> Bool {
        // 优先保存到项目目录
        let projectConfigPath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("api_keys.env")

        // 如果项目目录没有配置文件，则保存到用户配置目录
        let savePath: URL
        if FileManager.default.fileExists(atPath: projectConfigPath.path) {
            savePath = projectConfigPath
        } else {
            savePath = ASRConfig.configPath
        }

        let content = """
            # 火山引擎 ASR API 配置
            # 请在火山引擎控制台获取以下信息

            # APP ID（必填）
            VOLC_APP_KEY=\(appKey)

            # Access Token（必填）
            VOLC_ACCESS_KEY=\(accessKey)

            # 资源 ID（可选，默认使用小时版）
            VOLC_RESOURCE_ID=\(resourceId)

            # 输入模式: hold = 按住说话, toggle = 按下切换
            INPUT_MODE=\(inputMode.rawValue)

            # 按住说话快捷键
            HOLD_HOTKEY_CODE=\(holdHotKeyCode)
            HOLD_HOTKEY_MODS=\(holdHotKeyModifiers.rawValue)

            # 按下切换快捷键（开始录音）
            START_HOTKEY_CODE=\(startHotKeyCode)
            START_HOTKEY_MODS=\(startHotKeyModifiers.rawValue)

            # 确认快捷键（回车键）
            STOP_HOTKEY_CODE=\(stopHotKeyCode)
            STOP_HOTKEY_MODS=\(stopHotKeyModifiers.rawValue)
            """

        // 确保配置目录存在
        let configDir = savePath.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)

        do {
            try content.write(to: savePath, atomically: true, encoding: .utf8)
            print("[ASRConfig] 配置已保存到: \(savePath.path)")
            // 通知应用重新加载配置，直接传递自身以提高效率
            NotificationCenter.default.post(
                name: NSNotification.Name("ASRConfigChanged"), object: self)
            return true
        } catch {
            print("[ASRConfig] 保存配置失败: \(error.localizedDescription)")
            return false
        }
    }

    /// 创建合并了新配置的对象
    func merge(
        inputMode: InputMode? = nil,
        holdHotKeyCode: UInt16? = nil,
        holdHotKeyModifiers: NSEvent.ModifierFlags? = nil,
        startHotKeyCode: UInt16? = nil,
        startHotKeyModifiers: NSEvent.ModifierFlags? = nil,
        stopHotKeyCode: UInt16? = nil,
        stopHotKeyModifiers: NSEvent.ModifierFlags? = nil
    ) -> ASRConfig {
        return ASRConfig(
            appKey: self.appKey,
            accessKey: self.accessKey,
            resourceId: self.resourceId,
            inputMode: inputMode ?? self.inputMode,
            holdHotKeyCode: holdHotKeyCode ?? self.holdHotKeyCode,
            holdHotKeyModifiers: holdHotKeyModifiers ?? self.holdHotKeyModifiers,
            startHotKeyCode: startHotKeyCode ?? self.startHotKeyCode,
            startHotKeyModifiers: startHotKeyModifiers ?? self.startHotKeyModifiers,
            stopHotKeyCode: stopHotKeyCode ?? self.stopHotKeyCode,
            stopHotKeyModifiers: stopHotKeyModifiers ?? self.stopHotKeyModifiers,
            modelName: self.modelName,
            enableITN: self.enableITN,
            enablePunctuation: self.enablePunctuation,
            showUtterances: self.showUtterances,
            resultType: self.resultType,
            audioFormat: self.audioFormat,
            audioSampleRate: self.audioSampleRate,
            enableNonStream: self.enableNonStream,
            enableDDC: self.enableDDC,
            endWindowSize: self.endWindowSize,
            enableAccelerateText: self.enableAccelerateText,
            accelerateScore: self.accelerateScore
        )
    }
}
