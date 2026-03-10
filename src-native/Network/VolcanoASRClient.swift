import Compression
import Foundation

/// 火山引擎豆包大模型流式语音识别客户端
/// 协议文档：https://www.volcengine.com/docs/6561/xxx
class VolcanoASRClient: NSObject {
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?

    // 配置
    private var config: ASRConfig

    // 端点（使用双向流式异步模式）
    private let wsEndpoint = URL(
        string: "wss://openspeech.bytedance.com/api/v3/sauc/bigmodel_async")!

    // 状态
    private(set) var isConnected = false
    private(set) var isRecognizing = false
    private var connectId: String = ""

    /// 是否由于主动结束而期望关闭连接（用于屏蔽非异常断连弹窗）
    private var isClosingExpectingly = false

    // 发送统计
    private var lastAudioLogTime: Date = Date()
    private var audioPacketCount: Int = 0

    // 回调
    // onResult: (text, isFinalUtterance, isCorrected) -> Void
    // - text: 识别文本
    // - isFinalUtterance: 当前句子是否已确定（definite=true）
    // - isCorrected: 是否为校正结果（prefetch=false）
    var onResult: ((String, Bool, Bool) -> Void)?
    var onError: ((Error) -> Void)?
    var onConnected: (() -> Void)?

    // 线程安全队列
    private let processingQueue = DispatchQueue(label: "com.volc.asr.processor")

    init(config: ASRConfig) {
        self.config = config
        super.init()
    }

    /// 更新配置
    func updateConfig(_ config: ASRConfig) {
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            self.config = config
            print("[ASR] 配置已实时刷新")
        }
    }

    /// 便捷初始化（兼容旧代码）
    convenience init(appId: String, accessToken: String) {
        let config = ASRConfig(
            appKey: appId, accessKey: accessToken, resourceId: "volc.seedasr.sauc.duration",
            inputMode: .pressToToggle,
            holdHotKeyCode: 59, holdHotKeyModifiers: [.function, .control],
            startHotKeyCode: 9, startHotKeyModifiers: [.command, .shift],
            stopHotKeyCode: 36, stopHotKeyModifiers: [],
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
        self.init(config: config)
    }

    func connect() {
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            guard self.webSocketTask == nil else { return }

            self.connectId = UUID().uuidString
            self.isClosingExpectingly = false

            // 每次连接重建 session，确保之前的 session（含 delegate 强引用）已释放
            self.urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: nil)

            var request = URLRequest(url: self.wsEndpoint)
            request.addValue(self.config.appKey, forHTTPHeaderField: "X-Api-App-Key")
            request.addValue(self.config.accessKey, forHTTPHeaderField: "X-Api-Access-Key")
            request.addValue(self.config.resourceId, forHTTPHeaderField: "X-Api-Resource-Id")
            request.addValue(self.connectId, forHTTPHeaderField: "X-Api-Connect-Id")

            // 增加 Bearer 鉴权头 (火山引擎大模型异步接口标准)
            // 格式为: Bearer; {token}
            let authHeader = "Bearer; \(self.config.accessKey)"
            request.addValue(authHeader, forHTTPHeaderField: "Authorization")

            self.webSocketTask = self.urlSession?.webSocketTask(with: request)
            self.webSocketTask?.resume()

            self.receiveMessage()
            print("[ASR] 正在发起连接... (connectId: \(self.connectId))")
        }
    }

    func disconnect() {
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            self.isClosingExpectingly = true
            self.webSocketTask?.cancel(with: .normalClosure, reason: nil)
            self.webSocketTask = nil
            // 释放 session 以断开 delegate 强引用，防止 retain cycle
            self.urlSession?.invalidateAndCancel()
            self.urlSession = nil
            self.isConnected = false
            self.isRecognizing = false
            print("[ASR] 已由客户端主动断开")
        }
    }

    /// 重置识别状态（清空上下文）
    func reset() {
        print("[ASR] 正在重置 ASR 上下文...")
        disconnect()
        // 延迟一小会儿后自动重连并开始，以确保服务端已处理断连
        processingQueue.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.connect()
        }
    }

    /// 发送初始请求（Full Client Request）
    func startRecognition() {
        processingQueue.async { [weak self] in
            guard let self = self else { return }

            // 构建请求参数（完整配置）
            let payload: [String: Any] = [
                "app": [
                    "appid": self.config.appKey,
                    "token": self.config.accessKey,
                    "cluster": self.config.resourceId,
                ],
                "user": [
                    "uid": "mac_user_01"
                ],
                "audio": [
                    "format": self.config.audioFormat,
                    "sample_rate": self.config.audioSampleRate,
                ],
                "request": [
                    "model_name": self.config.modelName,
                    "enable_itn": self.config.enableITN,  // 文本规范化
                    "enable_punctuation": self.config.enablePunctuation,  // 启用标点符号
                    "show_utterances": self.config.showUtterances,  // 显示分句
                    "result_type": self.config.resultType,  // 返回完整结果
                    "enable_nonstream": self.config.enableNonStream,  // 二遍识别
                    "enable_ddc": self.config.enableDDC,  // 语义顺滑
                    "end_window_size": self.config.endWindowSize,  // 判停静音阈值
                    "enable_accelerate_text": self.config.enableAccelerateText,  // 首字加速
                    "accelerate_score": self.config.accelerateScore,  // 加速率
                ],
            ]

            guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
                print("[ASR] 错误：无法序列化 JSON")
                return
            }

            print("[ASR] 发送初始请求: model=\(self.config.modelName), sampleRate=\(self.config.audioSampleRate)")

            // 不压缩，直接发送原始 JSON
            let finalData = jsonData
            let compression: UInt8 = 0x00  // 0=No compression

            // 构建二进制消息
            // Header: version=1, headerSize=1, msgType=1(full client request), msgFlag=0
            // serialization=1(JSON), compression=0(None)
            let header = self.buildHeader(
                msgType: 0x01,
                msgFlag: 0x00,
                serialization: 0x01,
                compression: compression
            )

            var message = header
            let payloadSize = UInt32(finalData.count).bigEndian
            let payloadSizeData = withUnsafeBytes(of: payloadSize) { Data($0) }
            message.append(payloadSizeData)
            message.append(finalData)

            self.webSocketTask?.send(.data(message)) { [weak self] error in
                if let error = error {
                    print("[ASR] 发送初始请求失败: \(error)")
                    DispatchQueue.main.async {
                        self?.onError?(error)
                    }
                } else {
                    print("[ASR] 已发送初始请求 (\(finalData.count) bytes)")
                }
            }

            self.isRecognizing = true
        }
    }

    /// 发送音频数据（Audio Only Request）
    func sendAudio(data: Data, isLast: Bool = false) {
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            guard self.isConnected else {
                if isLast { print("[ASR] 警告：尝试发送最后一包但已断连") }
                return
            }

            // 构建音频消息（即使数据为空，也需发送结束标记）
            let message = self.buildAudioMessage(data: data, isLast: isLast)
            self.webSocketTask?.send(.data(message)) { [weak self] error in
                if let error = error {
                    DispatchQueue.main.async {
                        self?.onError?(error)
                    }
                }
            }

            // 发送统计日志 (每秒汇总一次)
            if !data.isEmpty {
                self.audioPacketCount += 1
                let now = Date()
                if now.timeIntervalSince(self.lastAudioLogTime) >= 1.0 {
                    print("[ASR] 正在发送音频数据: \(self.audioPacketCount) pps, size: \(data.count) bytes")
                    self.audioPacketCount = 0
                    self.lastAudioLogTime = now
                }
            }

            if isLast {
                print("[ASR] 已发送最后一包音频，等待服务端返回最终结果...")
                // 不立即关闭，等待服务端返回最终校正结果
                // 服务端会在返回最终结果后主动关闭连接
                self.isClosingExpectingly = true
            }
        }
    }

    /// 构建音频消息包（V3 二进制协议）
    private func buildAudioMessage(data: Data, isLast: Bool) -> Data {
        // msgType=2(audio only), msgFlag: 0=正常, 2=最后一包
        let msgFlag: UInt8 = isLast ? 0x02 : 0x00

        // 音频数据不压缩，直接发送 PCM
        let header = buildHeader(
            msgType: 0x02,
            msgFlag: msgFlag,
            serialization: 0x00,
            compression: 0x00
        )

        var message = header
        let payloadSize = UInt32(data.count).bigEndian
        let payloadSizeData = withUnsafeBytes(of: payloadSize) { Data($0) }
        message.append(payloadSizeData)
        message.append(data)

        return message
    }

    // MARK: - WebSocket 监听逻辑
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                switch message {
                case .data(let data):
                    self.handleServerMessage(data)
                case .string(let text):
                    print("[ASR] 收到文本消息: \(text)")
                @unknown default:
                    break
                }
                // 继续监听
                self.processingQueue.async { [weak self] in
                    guard let self = self else { return }
                    if self.isConnected {
                        self.receiveMessage()
                    }
                }

            case .failure(let error):
                self.processingQueue.async { [weak self] in
                    guard let self = self else { return }

                    // 如果是主动关闭或期望的关闭，不抛出错误回调
                    if self.isClosingExpectingly {
                        print("[ASR] 连接已按预期关闭 (\(error.localizedDescription))")
                        self.isConnected = false
                        self.isRecognizing = false
                        return
                    }

                    print("[ASR] 接收消息失败: \(error.localizedDescription)")
                    self.isConnected = false
                    self.isRecognizing = false

                    // 提供更详细的错误信息
                    let detailedError = NSError(
                        domain: "VolcanoASR",
                        code: (error as NSError).code,
                        userInfo: [
                            NSLocalizedDescriptionKey:
                                "WebSocket连接错误: \(error.localizedDescription)\n\n可能原因:\n1. API配置错误(App ID或Access Token)\n2. 网络连接问题\n3. 服务端暂时不可用\n\n请检查设置中的API配置是否正确。"
                        ]
                    )
                    DispatchQueue.main.async {
                        self.onError?(detailedError)
                    }
                }
            }
        }
    }

    private func handleServerMessage(_ data: Data) {
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            self.doHandleServerMessage(data)
        }
    }

    private func doHandleServerMessage(_ data: Data) {
        guard data.count >= 4 else {
            print("[ASR] 消息太短: \(data.count) bytes")
            return
        }

        // 解析 Header
        let msgType = (data[1] >> 4) & 0x0F
        let msgFlag = data[1] & 0x0F
        let compression = data[2] & 0x0F

        // 判断是否有 sequence number（msgFlag 的 bit0 为 1 时有 sequence）
        let hasSequence = (msgFlag & 0x01) != 0
        let headerSize = 4
        let sequenceSize = hasSequence ? 4 : 0
        let payloadSizeOffset = headerSize + sequenceSize

        guard data.count >= payloadSizeOffset + 4 else {
            print("[ASR] 消息格式错误")
            return
        }

        // 读取 payload size
        let payloadSize = UInt32(
            bigEndian: data.subdata(in: payloadSizeOffset..<payloadSizeOffset + 4)
                .withUnsafeBytes { $0.load(as: UInt32.self) })

        let payloadOffset = payloadSizeOffset + 4
        guard data.count >= payloadOffset + Int(payloadSize) else {
            print("[ASR] Payload 不完整")
            return
        }

        var payload = data.subdata(in: payloadOffset..<payloadOffset + Int(payloadSize))

        // 处理错误消息
        if msgType == 0x0F {
            handleErrorMessage(data)
            return
        }

        // 解压 Gzip
        if compression == 0x01 {
            if let decompressed = gzipDecompress(data: payload) {
                payload = decompressed
            } else {
                print("[ASR] Gzip 解压失败")
                return
            }
        }

        // 解析 JSON
        guard let json = try? JSONSerialization.jsonObject(with: payload) as? [String: Any] else {
            print("[ASR] JSON 解析失败")
            return
        }

        // 调试日志：打印识别中的 JSON 结构
        if isRecognizing {
            if let jsonString = String(data: payload, encoding: .utf8) {
                print("[ASR] 实时数据流: \(jsonString)")
            }
        }

        // 提取识别结果
        // 健壮处理：result 可能是 [String: Any] 或 [[String: Any]]
        var resultDict: [String: Any]?

        if let dict = json["result"] as? [String: Any] {
            resultDict = dict
        } else if let list = json["result"] as? [[String: Any]], let first = list.first {
            // 火山某些版本或配置下返回的是数组
            resultDict = first
        }

        if let result = resultDict {
            if let text = result["text"] as? String {
                // 检查是否有确定的分句
                var isFinalUtterance = false
                if let utterances = result["utterances"] as? [[String: Any]] {
                    for utt in utterances {
                        if let definite = utt["definite"] as? Bool, definite {
                            isFinalUtterance = true
                            break
                        }
                    }
                }

                // 检查是否为校正结果（prefetch 为 false 时表示这是校正后的结果）
                let isPrefetch = result["prefetch"] as? Bool ?? true
                let isCorrected = !isPrefetch

                if isCorrected {
                    print("收到校正结果: \(text)")
                } else {
                    print("收到实时结果: \(text) (final: \(isFinalUtterance))")
                }

                DispatchQueue.main.async {
                    self.onResult?(text, isFinalUtterance, isCorrected)
                }
            }
        } else {
            // 检查是否有错误字段
            if let errorCode = json["code"] as? Int, errorCode != 0 {
                let message = json["message"] as? String ?? "未知服务端错误"
                print("[ASR] 业务逻辑错误 [\(errorCode)]: \(message)")
            }
        }
    }

    private func handleErrorMessage(_ data: Data) {
        guard data.count >= 12 else { return }

        // 读取错误码
        let errorCode = UInt32(
            bigEndian: data.subdata(in: 4..<8)
                .withUnsafeBytes { $0.load(as: UInt32.self) })

        // 读取错误消息长度
        let msgSize = UInt32(
            bigEndian: data.subdata(in: 8..<12)
                .withUnsafeBytes { $0.load(as: UInt32.self) })

        var errorMsg = "未知错误"
        if data.count >= 12 + Int(msgSize) {
            errorMsg =
                String(data: data.subdata(in: 12..<12 + Int(msgSize)), encoding: .utf8) ?? errorMsg
        }

        print("[ASR] 服务端错误 [\(errorCode)]: \(errorMsg)")

        // 根据错误码提供更友好的提示
        var friendlyMsg = errorMsg
        switch errorCode {
        case 1_000_001:
            friendlyMsg = "鉴权失败: App ID或Access Token错误\n\n请在设置中检查API密钥配置。"
        case 1_000_002:
            friendlyMsg = "资源ID配置错误\n\n当前使用: \(config.resourceId)\n请确认是否正确。"
        case 1_000_003:
            friendlyMsg = "请求频率超限\n\n请稍后再试。"
        case 1_000_004:
            friendlyMsg = "音频格式错误\n\n期望: 16kHz PCM 16-bit 单声道"
        default:
            if errorMsg.contains("auth") || errorMsg.contains("token") {
                friendlyMsg = "认证失败: \(errorMsg)\n\n请检查API密钥配置。"
            } else {
                friendlyMsg = "服务端错误 [\(errorCode)]: \(errorMsg)"
            }
        }

        let error = NSError(
            domain: "VolcanoASR",
            code: Int(errorCode),
            userInfo: [NSLocalizedDescriptionKey: friendlyMsg]
        )
        DispatchQueue.main.async {
            self.onError?(error)
        }
    }

    // MARK: - 协议构建

    private func buildHeader(
        msgType: UInt8, msgFlag: UInt8, serialization: UInt8, compression: UInt8
    ) -> Data {
        var header = Data(count: 4)
        header[0] = (0x01 << 4) | 0x01  // Version=1, HeaderSize=1 (即 4 bytes)
        header[1] = (msgType << 4) | msgFlag
        header[2] = (serialization << 4) | compression
        header[3] = 0x00  // Reserved
        return header
    }

    // MARK: - Gzip 解压

    private func gzipDecompress(data: Data) -> Data? {
        guard data.count > 18 else { return nil }

        // 跳过 Gzip header（10 bytes）和尾部（8 bytes: CRC32 + size）
        let compressedData = data.subdata(in: 10..<data.count - 8)
        guard !compressedData.isEmpty else { return nil }

        // 循环解压，缓冲区不足时翻倍，避免高压缩率数据被截断
        var bufferSize = max(compressedData.count * 4, 65536)
        let maxBufferSize = 100 * 1024 * 1024  // 100MB 安全上限

        while bufferSize <= maxBufferSize {
            var buffer = [UInt8](repeating: 0, count: bufferSize)

            let decompressedSize = compressedData.withUnsafeBytes { sourcePtr -> Int in
                let sourceBuffer = sourcePtr.bindMemory(to: UInt8.self)
                return compression_decode_buffer(
                    &buffer, bufferSize,
                    sourceBuffer.baseAddress!, compressedData.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }

            if decompressedSize == 0 {
                print("[ASR] Gzip 解压失败")
                return nil
            }

            if decompressedSize < bufferSize {
                // 成功且缓冲区未被填满，说明数据完整
                return Data(buffer[0..<decompressedSize])
            }

            // 缓冲区已满，可能被截断，翻倍后重试
            bufferSize *= 2
        }

        print("[ASR] Gzip 解压: 数据超过安全限制 (\(maxBufferSize) bytes)")
        return nil
    }
}

// MARK: - URLSessionWebSocketDelegate

extension VolcanoASRClient: URLSessionWebSocketDelegate {
    func urlSession(
        _ session: URLSession, webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        print("[ASR] WebSocket 连接成功")
        processingQueue.async { [weak self] in
            self?.isConnected = true
        }
        DispatchQueue.main.async {
            self.onConnected?()
        }
    }

    func urlSession(
        _ session: URLSession, webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?
    ) {
        print("[ASR] WebSocket 连接关闭: \(closeCode)")
        processingQueue.async { [weak self] in
            self?.isConnected = false
            self?.isRecognizing = false
        }
    }
}
