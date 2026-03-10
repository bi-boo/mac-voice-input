# mac 语音输入法 - 技术架构文档

## 系统架构概述
应用采用 Swift 原生开发，基于 AppKit 和 AVFoundation 框架。整体架构分为网络层、管理层和 UI 层，通过 `AppDelegate` 进行协调。

## 模块说明
### 核心模块
*   **VolcanoASRClient**: 处理 WebSocket 通信、JSON 序列化、Gzip 压缩及识别结果解析。
*   **AudioRecorder**: 封装 `AVAudioEngine`，提供 16kHz PCM 音频采集。
*   **HotKeyManager**: 处理全局热键监听。
*   **KeyboardManager**: 处理剪贴板写入和 CGEvent 模拟粘贴。

### UI 模块
*   **InputWindowController**: 控制 HUD 窗口的显示、布局及交互。
*   **InputWindowController**: 控制 HUD 窗口的显示、布局及交互。
*   **PreferencesWindowController**: 管理偏好设置窗口，协调 `GeneralViewController` 和 `ShortcutsViewController`。

## 数据模型
*   **ASRConfig**: 存储 API 凭据、热键 KeyCode 及修饰符。

## 关键决策
1.  **原生开发**: 弃用 Electron 改为 Swift，以获得更低的系统开销和更好的系统集成度。
2.  **ASR V3 标准**: 采用最新的 V3 流式 API 以获得更好的大模型识别效果。
3.  **连接驱动模式**: ASR 启动逻辑由 WebSocket 握手成功回调驱动，避免连接状态竞争。

## 当前状态
- [x] 连接状态同步机制
- [x] 全局事件监听机制
- [/] 动态热键配置 (优化中)
- [x] 自动权限（Accessibility）检查引导
