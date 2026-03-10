# 修改记录

# [2026-02-01 22:26]
- **用户需求/反馈**: 用户请求优化偏好设置 UI，去除旧式 NSBox 边框，使其更符合现代 macOS 风格。
- **技术逻辑变更**: 
    - 重构 `GeneralViewController`，移除 `NSBox` 容器。
    - 使用 `NSStackView` 进行布局，配合 `NSBox(boxType: .separator)` 作为分隔线。
    - 统一使用 Bold Font 作为小节标题，调整间距和对齐方式。
- **涉及文件清单**: 
    - `src-native/UI/Preferences/GeneralViewController.swift`
    - `docs/prd.md`
- **变更原因**: 提升应用视觉体验，使其看起来更原生、更轻量。

# [2026-02-01 22:10]
- **用户需求/反馈**: 重新组织偏好设置标签页：1) 通用页包含快捷键、权限、开机自启动；2) 新增独立的 API 配置页。
- **技术逻辑变更**: 
    - **新建 APIConfigViewController**: 将 API 配置（App ID、Access Token）独立为单独的标签页，使用 `key` 图标。
    - **重构 GeneralViewController**: 整合快捷键录制组件（从原 ShortcutsViewController 迁移）、系统权限检查、新增开机自启动开关（使用 `SMAppService` API）。
    - **更新 PreferencesWindowController**: 调整 Tab 顺序为"通用"→"API 配置"。
    - **删除 ShortcutsViewController**: 功能已合并至通用页，移除冗余文件。
- **涉及文件清单**: 
    - `src-native/UI/Preferences/APIConfigViewController.swift` (新增)
    - `src-native/UI/Preferences/GeneralViewController.swift`
    - `src-native/UI/Preferences/PreferencesWindowController.swift`
    - `src-native/UI/Preferences/ShortcutsViewController.swift` (已删除)
    - `build-native.sh`
    - `docs/changelog.md`
- **变更原因**: 优化设置分类逻辑，将常用设置集中到通用页，API 配置独立便于管理。

# [2026-02-01 22:05]
- **用户需求/反馈**: 1) 偏好设置中 API 配置输入框打开时不应该有默认焦点；2) 所有设置修改后应自动生效，无需保存按钮。
- **技术逻辑变更**: 
    - **通用设置页**: 移除"保存配置"按钮，改为 `NSTextFieldDelegate` 监听输入完成事件自动保存；在 `viewWillAppear` 中调用 `makeFirstResponder(nil)` 移除输入框默认焦点。
    - **快捷键设置页**: 移除"保存快捷键"按钮，利用 `KeyRecorderView.onKeyRecorded` 回调在快捷键录制完成后自动保存配置并通知 App 刷新。
- **涉及文件清单**: 
    - `src-native/UI/Preferences/GeneralViewController.swift`
    - `src-native/UI/Preferences/ShortcutsViewController.swift`
    - `docs/changelog.md`
- **变更原因**: 提升用户体验，减少不必要的"保存"操作步骤，让设置修改即时生效。

# [2026-02-01 21:34]
- **用户需求/反馈**: 用户提供了一张麦克风图标图片，要求将其作为应用的 Logo。
- **技术逻辑变更**: 
    - 将用户提供的 JPEG 图片转换为 PNG 格式，并生成各种分辨率的 iconset（16x16 至 1024x1024）。
    - 使用 `iconutil` 将 iconset 转换为 macOS 标准的 `.icns` 图标文件。
    - 更新 `Info.plist` 添加 `CFBundleIconFile` 配置项指向 `AppIcon`。
    - 更新 `build-native.sh` 脚本，在打包时复制 `AppIcon.icns` 到 Resources 目录。
- **涉及文件清单**: 
    - `src-native/assets/AppIcon.icns` (新增)
    - `src-native/assets/AppIcon.png` (新增)
    - `src-native/assets/AppIcon.iconset/` (新增)
    - `src-native/Info.plist`
    - `build-native.sh`
- **变更原因**: 提升应用的品牌识别度，使用自定义图标替代系统默认图标。

# [2026-01-17 23:19]
- **用户需求/反馈**: 增加双模式切换功能：1）按住说话模式（按住快捷键录音，松开自动粘贴）；2）按下切换模式（按下显示弹窗，需手动确认输出）。按住说话默认快捷键为 fn+Control。
- **技术逻辑变更**: 
    - **配置层**: 在 `ASRConfig` 中新增 `InputMode` 枚举和 `holdHotKey` 系列字段，支持存储和加载两种模式的配置。
    - **热键管理**: 重构 `HotKeyManager`，新增 `onHotKeyReleased` 回调和 `flagsChanged` 监听，支持检测修饰键释放（包括 fn 键）。
    - **UI 层**: 新建 `SimpleInputWindowController` 作为简洁模式窗口（无按钮、仅文本区域）；更新 `SettingsWindowController` 添加模式选择下拉框和双快捷键录入。
    - **主程序**: 重构 `VoiceInputApp` 根据模式动态注册热键、显示对应窗口、处理松开回调。
- **涉及文件清单**: 
    - `src-native/Network/ASRConfig.swift`
    - `src-native/Managers/HotKeyManager.swift`
    - `src-native/UI/SimpleInputWindowController.swift` (新建)
    - `src-native/UI/SettingsWindowController.swift`
    - `src-native/VoiceInputApp.swift`
    - `src-native/Network/VolcanoASRClient.swift`
    - `build-native.sh`
- **变更原因**: 满足不同用户使用习惯，提供更灵活的语音输入触发方式。


# [2026-01-17 23:00]
- **用户需求/反馈**: 简化设置界面 - 移除无用配置项，明确标注服务商。
- **技术逻辑变更**: 
    - API 配置标题改为"火山引擎 · 豆包流式语音识别 2.0"，明确服务来源。
    - 移除"资源 ID"配置项，锁定为 `volc.seedasr.sauc.duration`。
    - 移除"提交并插入"快捷键配置项，固定为回车键（keyCode 36）。
    - 调整窗口高度从 420 减小到 340，适应精简后的布局。
- **涉及文件清单**: 
    - `src-native/UI/SettingsWindowController.swift`
- **变更原因**: 简化用户配置流程，减少不必要的选项，只保留必填项。

# [2026-01-17 22:58]
- **用户需求/反馈**: 语音录入过程中，按下 ESC 键应能取消本次录入。
- **技术逻辑变更**: 
    - 创建 `InputWindow` 子类继承自 `NSWindow`，重写 `keyDown` 方法捕获 ESC 键事件（keyCode 53）。
    - 添加 `onEscapePressed` 回调属性，在窗口创建时绑定到 `cancelClicked()` 方法。
    - 重写 `canBecomeKey` 返回 `true`，确保窗口能成为 Key Window 以接收键盘事件。
- **涉及文件清单**: 
    - `src-native/UI/InputWindowController.swift`
- **变更原因**: 提升用户体验，允许快速取消语音录入操作。

- **HUD 视觉细节深度优化**: 
    - 解决了边界圆角处的“方块白边”问题，确保阴影与圆角完美咬合。
    - 将界面材质从暗淡的 `.hudWindow` 调整为明净的 `.popover`（偏白色透感），彻底摆脱“脏灰色”。
    - 全面移除描边线条，实现无感设计的视觉一体化。
    - 优化“完成并插入”及其它按钮的视觉层级，保持全透明/玻璃感的一致性。
- **涉及文件清单**: 
    - `src-native/UI/InputWindowController.swift`
- **变更原因**: 修复视觉瑕疵，追求更纯双、高端的苹果原生设计质感。

# [2026-01-17 14:25]
- **用户需求/反馈**: HUD 界面样式陈旧，存在直角阴影、描边过粗、层级混乱等问题。
- **技术逻辑变更**: 
    - 彻底重构 `InputWindowController`：采用 `.hudWindow` 材质实现“液态玻璃”效果。
    - 优化窗口阴影与边缘，解决“直角阴影”bug。
    - 统一字体为系统标准 17pt，移除硬加粗。
    - 隐藏文本滚动条，简化按钮为图标模式，消除视觉噪音。
- **涉及文件清单**: 
    - `src-native/UI/InputWindowController.swift`
- **变更原因**: 提升应用视觉品质，对标苹果原生设计规范。

# [2026-01-17 14:20]
- **用户需求/反馈**: 修改快捷键后，必须重启应用才能生效，体验不佳。
- **技术逻辑变更**: 
    - 建立了配置变更的实时通知链：`ASRConfig.save()` 现在会自动广播新配置。
    - 在 `VoiceInputApp` 中实现了实时刷新逻辑：接收通知后立即重新注册热键并更新识别客户端配置。
    - 为 `VolcanoASRClient` 增加了动态配置刷新接口，无需重新实例化。
- **涉及文件清单**: 
    - `src-native/Network/ASRConfig.swift`
    - `src-native/VoiceInputApp.swift`
    - `src-native/Network/VolcanoASRClient.swift`
    - `src-native/UI/SettingsWindowController.swift`
- **变更原因**: 提升用户交互体验，确保设置变更即刻生效。

# [2026-01-17 14:18]
- **用户需求/反馈**: 全局快捷键失效，无法通过快捷键启动识别。
- **技术逻辑变更**: 
    - 修正了 `ASRConfig.swift` 中硬编码的默认快捷键修饰键（从 Cmd+Control 改为 Cmd+Shift）。
    - 补全了项目根目录下 `api_keys.env` 的快捷键显式配置。
- **涉及文件清单**: 
    - `src-native/Network/ASRConfig.swift`
    - `api_keys.env`
- **变更原因**: 代码默认值与 PRD/用户习惯不一致，且配置文件缺失导致回退。

# [2026-01-17 01:15]
- **用户需求/反馈**: 优化识别实时性，确保模型性能达到最高规格。
- **技术逻辑变更**: 
    - **音频分包聚合**: 实现 `audioBuffer` 逻辑，将采集到的琐碎音频（~20ms）聚合为官方建议的 200ms 标准包发送，显著提升模型推理效率。
    - **高级参数注入**: 在请求中开启了 `enable_semantic_break` (语义分句) 和 `enable_itn` (数字转写)，并将 `result_type` 设置为 `full`。
    - **性能对齐**: 确认使用 `bigmodel_async` 接口与 `volc.seedasr.sauc.duration` 资源 ID 的“满血”组合。
- **涉及文件清单**: 
    - `src-native/Network/VolcanoASRClient.swift`
- **变更原因**: 恢复 SeedASR 2.0 应有的双向流式极致体验。

# [2026-01-17 01:05]
- **用户需求/反馈**: 修复点击完成后内容能复制但无法自动粘贴到原应用的问题（焦点丢失）。
- **技术逻辑变更**: 
    - **焦点锁定**: 在 `startRecording` 瞬间通过 `NSWorkspace.shared.frontmostApplication` 暂存当前活跃应用，建立“来源记录”。
    - **强力唤回**: 在插入文本前，显式调用目标应用的 `activate()` 方法，强制 macOS 将输入焦点切回原处。
    - **模拟策略升级**: 优化 `KeyboardManager` 的 `paste()` 逻辑，增加 0.3s 的窗口切换缓冲区，确保粘贴指令发送到正确的窗口层级。
- **涉及文件清单**: 
    - `src-native/VoiceInputApp.swift`
    - `src-native/Managers/KeyboardManager.swift`
- **变更原因**: 解决由于应用间窗口切换导致的“粘贴落空”现象，实现真正的“即点即入”体验。

# [2026-01-17 00:55]
- **用户需求/反馈**: 修复点击“完成并插入”后出现“Socket is not connected”弹窗，且此后无法再次识别的问题。
- **技术逻辑变更**: 
    - **逻辑过滤**: 引入 `isClosingExpectingly` 标识位，有效识别并屏蔽发送 `isLast` 消息后服务器正常的连接关闭动作，消除系统误报（NSURLSessionWebSocketError 57）。
    - **状态强力重置**: 在 `startRecording` 逻辑中，无论当前 ASR 连接是否正常，均强制执行 `disconnect()` 进行状态清理，确保每次语音输入都是全新的连接上下文。
- **涉及文件清单**: 
    - `src-native/Network/VolcanoASRClient.swift`
    - `src-native/VoiceInputApp.swift`
- **变更原因**: 解决因 ASR 状态机未闭环导致的识别死锁，提升连续采写的稳定性。

# [2026-01-17 00:45]
- **用户需求/反馈**: “说话不显示内容”问题在初步修复后依然存在。
- **技术逻辑变更**: 
    - **协议校准**: 经深测发现 V3 协议中 `audio` 结构的采样率字段应为 `sample_rate` 而非 `rate`，已完成修正。
    - **流量监控**: 在客户端增加了每秒发送包数的汇总日志 `[ASR] 正在发送音频数据`，便于确认音频采集层是否真实产生数据并流向网络。
- **涉及文件清单**: 
    - `src-native/Network/VolcanoASRClient.swift`
    - `docs/changelog.md`
- **变更原因**: 修正由于字段命名偏差导致的服务器端解析静默失败，增强数据传输的可观测性。

# [2026-01-17 00:40]
- **用户需求/反馈**: 修复说话时不显示内容的问题。
- **技术逻辑变更**: 
    - **权限授权**: 新增 `MicrophoneManager` 类，在应用启动时主动弹出系统麦克风权限请求，确保音频采集不被静默拦截。
    - **解析容错**: 增强 `VolcanoASRClient` 的 JSON 解析逻辑，同时支持 `result` 字段为列表（Array）或字典（Dictionary）的格式，解决不同 ASR 模型版本导致的数据路径不匹配。
    - **透明化调试**: 在控制台增加 ASR 实时数据流日志，便于后续故障精确定位。
- **涉及文件清单**: 
    - `src-native/Managers/MicrophoneManager.swift`
    - `src-native/Network/VolcanoASRClient.swift`
    - `src-native/VoiceInputApp.swift`
    - `build-native.sh`
- **变更原因**: 解决由于未授权或协议微变导致的“识别中但无内容”现象，提升系统的健壮性和可维护性。

# [2026-01-17 00:35]
- **用户需求/反馈**: 修复 ASR 连接错误（Bad response from the server）。
- **技术逻辑变更**: 
    - **鉴权升级**: 在 WebSocket 握手请求中强制增加 `Authorization: Bearer; {token}`，并保留原有自定义 Header 以确保最高兼容性。
    - **逻辑纠偏**: 修正了 `ASRConfig` 中环境变量加载时的变量定义缺失问题。
    - **配置同步**: 将默认资源 ID 统一更新为火山引擎最新的大模型异步版本 `volc.seedasr.sauc.duration`。
- **涉及文件清单**: 
    - `src-native/Network/VolcanoASRClient.swift`
    - `src-native/Network/ASRConfig.swift`
    - `docs/prd.md`
    - `docs/changelog.md`
- **变更原因**: 解决与火山引擎服务器通信的鉴权校验障碍，提升首包连接成功率，修复代码中的静态缺陷。

# [2026-01-17 00:20]
- **用户需求/反馈**: 系统性检查项目,发现多个bug和大量冗余文件。要求修复所有bug并清理Electron遗留文件。
- **技术逻辑变更**: 
    - **录音暂停/恢复优化**: 在恢复录音前增加连接检查和断开逻辑,避免WebSocket连接堆积导致的状态混乱。
    - **资源管理增强**: 在 `AudioRecorder.stop()` 中添加 `audioEngine.reset()`,彻底释放音频引擎资源,防止频繁开始/停止导致的内存泄漏。
    - **路径管理优化**: 将硬编码的开发环境路径用 `#if DEBUG` 宏包裹,确保发布版本不包含特定用户路径。
    - **配置持久化**: 在 `ASRConfig` 中新增 `save()` 和 `merge()` 方法,实现配置文件的写入功能;重构 `SettingsWindowController` 使用新的保存接口,增加完整的输入验证和错误提示。
    - **错误处理改善**: 优化 `AudioRecorder` 的错误回调,提供更友好的错误信息;在设置保存时增加详细的错误提示(警告、信息、严重)。
    - **项目清理**: 删除所有旧的Electron版本文件,包括 `src/`, `main.js`, `preload.js`, `package.json`, `node_modules/`, `dist/` 等,节省200-300MB磁盘空间。
- **涉及文件清单**: 
    - `src-native/VoiceInputApp.swift`
    - `src-native/Managers/AudioRecorder.swift`
    - `src-native/Network/ASRConfig.swift`
    - `src-native/UI/SettingsWindowController.swift`
    - `docs/changelog.md`
    - (已删除) `src/`, `main.js`, `preload.js`, `package.json`, `package-lock.json`, `node_modules/`, `dist/`
- **变更原因**: 提升代码质量和稳定性,解决潜在的内存泄漏和连接问题,实现配置持久化功能,清理项目结构使其更简洁。

# [2026-01-16 23:55]
- **用户需求/反馈**: 设置页面打不开，UI 较丑且使用了 Emoji，点击插入按钮报 Socket 错误。要求移除菜单快捷键，并在设置中提供自定义快捷键功能。
- **技术逻辑变更**: 
    - 重构 `InputWindowController`：从 Frame 布局改为 Auto Layout，移除 Emoji 改用 SF Symbols，添加动画。
    - ASR 保护：在 `sendAudio` 中增加连接状态校验。
    - 动态热键：实现 `HotKeyManager` 支持从字符串解析热键并动态注销/注册全局监听。
    - 设置页面：新增 `SettingsWindowController` 集成配置读写。
- **涉及到文件清单**: 
    - `src-native/UI/InputWindowController.swift`
    - `src-native/UI/SettingsWindowController.swift`
    - `src-native/Network/VolcanoASRClient.swift`
    - `src-native/Managers/HotKeyManager.swift`
    - `src-native/VoiceInputApp.swift`
    - `build-native.sh`
- **变更原因**: 提升 UI 质感，解决异步连接导致的报错，满足用户自定义快捷键的需求。

# [2026-01-16 23:59]
- **用户需求/反馈**: 快捷键设置逻辑有问题，应支持“点击录制”而非输入文本；修改后未生效；要求参照规则更新修改记录。
- **技术逻辑变更**: 
    - **交互优化**: 引入 `KeyRecorderView`，支持鼠标点击后直接录制按键。
    - **存储升级**: 快捷键存储从字符串解析迁移为原生的键码 (KeyCode) 和修饰符 (Modifiers)，极大提升稳定性。
    - **即兴刷新**: 修复配置更新后的刷新逻辑，实现热键设置即时生效。
    - **文档补全**: 初始化并更新了 `docs/` 目录下的 PRD、架构文档和修改记录。
- **涉及到文件清单**: 
    - `src-native/Network/ASRConfig.swift`
    - `src-native/Managers/HotKeyManager.swift`
    - `src-native/UI/KeyRecorderView.swift`
    - `src-native/UI/SettingsWindowController.swift`
    - `src-native/Network/VolcanoASRClient.swift`
    - `src-native/VoiceInputApp.swift`
    - `docs/prd.md`
    - `docs/architecture.md`
    - `docs/changelog.md`
- **变更原因**: 优化快捷键设置的交互体验和底层可靠性，补齐项目规范文档，修复重构导致的编译错误。
# [2026-01-17 00:15]
- **用户需求/反馈**: 输入框 UI 不太美观，要求参照现代 macOS 26 设计规范进行重构。
- **技术逻辑变更**: 
    - **视觉升级**: 窗口圆角半径提升至 28pt，材质切换为 `.popover`（玻璃拟态），边框减至 0.3pt 以增强精致感。
    - **布局精调**: 文本内边距增加至 20pt，字体升级为 20pt Medium；底部按钮栏高度提升至 44pt，使用圆形 SF Symbols 图标。
    - **状态反馈**: 优化了录音/暂停状态下的图标色彩逻辑，增强交互感知。
- **涉及到文件清单**: 
    - `src-native/UI/InputWindowController.swift`
    - `docs/changelog.md`
- **变更原因**: 提升应用的原生质感，使其视觉风格与最新的 macOS 系列系统保持高度一致，优化用户在录音过程中的阅读和操作体验。

# [2026-01-17 00:25]
- **用户需求/反馈**: 快捷键设置后不生效（只有点击菜单才行）；应用缺乏辅助功能权限导致无法模拟粘贴。
- **技术逻辑变更**: 
    - **全场景热键**: 优化 `HotKeyManager`，同时注册 Global 和 Local 事件监听，确保应用在后台和前台（如设置页打开时）均能响应热键。
    - **多热键支持**: `HotKeyManager` 现在支持同时注册多个热键（“开始”和“完成”），并能准确识别。
    - **权限引导系统**: 新增 `AccessibilityManager`，在应用启动时自动检测辅助功能权限。若无权限，将弹出友好的引导窗口并引导用户至系统设置。
    - **构建同步**: 更新 `build-native.sh` 以包含新的管理器类。
- **涉及到文件清单**: 
    - `src-native/Managers/HotKeyManager.swift`
    - `src-native/Managers/AccessibilityManager.swift`
    - `src-native/VoiceInputApp.swift`
    - `build-native.sh`
    - `docs/changelog.md`
- **变更原因**: 解决核心交互和权限障碍，确保应用功能的完整闭环，提升用户设置和使用的成功率。

# [2026-02-01 22:16]
- **用户需求/反馈**: 优化偏好设置通用的界面项，解决对齐不规范和 Emoji 使用随意的问题。
- **技术逻辑变更**: 重构 GeneralViewController UI 布局。引入 NSBox 进行逻辑分组，通过自定义对齐辅助方法实现标签左对齐、控件右对齐。移除了权限状态显示中的 Emoji 硬编码并优化了文案。
- **涉及文件清单**: 
    - `src-native/UI/Preferences/GeneralViewController.swift`
    - `docs/prd.md`
- **变更原因**: 提升应用 UI 的原生感和专业度，符合 macOS 人机交互指南设计规范。

# [2026-02-01 22:20]
- **用户需求/反馈**: 用户反馈之前的 UI 调整仍显粗糙，需要精致化细节（字体、间距、区隔）。
- **技术逻辑变更**: 1. 细化字号规范：辅助说明统一为 10pt secondaryLabelColor。2. 优化间距体系：组间距 12pt，项内标题与说明间距 4pt。3. 增强容器质感：NSBox 内边距调整为 (15, 10)，并在权限组内增加分隔线。4. 嵌套 StackView 以实现不同层级的关联感。
- **涉及文件清单**: 
    - `src-native/UI/Preferences/GeneralViewController.swift`
- **变更原因**: 优化视觉节奏感和信息层级，消除 UI 布局带来的“粗糙感”，向 macOS 原生精致化体验对齐。

# [2026-02-01 22:21]
- **用户需求/反馈**: 提供截图反馈，要求实现更合理的布局（两侧对齐、间距平衡）。
- **技术逻辑变更**: 1. 引入弹性 Spacer：在 createRow 中使用 NSView 自动撑开文字与控件的间距，实现真正的分布对齐。2. 增强呼吸感：将 NSBox 内边距从 15pt 提升至 20pt/16pt。3. 优化对齐：取消固定行宽限制，改用父视图比例约束以适配不同内容宽度。4. 文字对齐修正：确保状态文本右对齐且垂直水平精准居中。
- **涉及文件清单**: 
    - `src-native/UI/Preferences/GeneralViewController.swift`
- **变更原因**: 解决截图显示的“未完全对齐”问题，提升 UI 的精致度和空间利用合理性。
