import AVFoundation
import Foundation

class AudioRecorder: NSObject {
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?

    // 采样设置：16kHz, 16-bit PCM, 单声道
    private let sampleRate: Double = 16000
    private let channels: AVAudioChannelCount = 1

    // 静音检测（silentPacketCount/hasSilenceWarned 由音频线程访问，需加锁保护）
    private var silentPacketCount = 0
    private let silentThreshold: Int = 30  // 连续 30 包无声即触发提示（约 3 秒）
    private let volumeThreshold: Float = 100  // 音量阈值（16-bit PCM 的绝对值）
    private var hasSilenceWarned = false
    private let silenceLock = NSLock()

    var onAudioData: ((Data) -> Void)?
    var onError: ((Error) -> Void)?
    var onSilenceDetected: (() -> Void)?  // 检测到持续静音时触发
    var onVolumeChanged: ((Float) -> Void)?  // 实时音量回调

    private(set) var isRecording = false

    func start() {
        guard !isRecording else { return }

        // 重置静音检测状态
        silenceLock.lock()
        silentPacketCount = 0
        hasSilenceWarned = false
        silenceLock.unlock()

        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else { return }

        inputNode = audioEngine.inputNode
        guard let inputNode = inputNode else {
            print("[AudioRecorder] 错误：无法获取输入节点")
            return
        }
        let inputFormat = inputNode.inputFormat(forBus: 0)

        // 目标格式：16kHz, 16-bit PCM (Linear PCM)
        let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: channels,
            interleaved: false)!

        // 创建转换器
        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            onError?(
                NSError(
                    domain: "AudioRecorder", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "无法创建音频转换器"]))
            return
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) {
            [weak self] (buffer, time) in
            guard let self = self else { return }

            let frameCount = AVAudioFrameCount(
                Double(buffer.frameLength) * self.sampleRate / inputFormat.sampleRate)

            guard frameCount > 0 else { return }

            guard
                let outputBuffer = AVAudioPCMBuffer(
                    pcmFormat: outputFormat, frameCapacity: frameCount)
            else {
                print("[AudioRecorder] 警告：无法创建输出缓冲区 (frameCount: \(frameCount))")
                return
            }

            var error: NSError?
            // consumed 标志位：防止 converter 多次调用 inputBlock 时重复输入同一 buffer
            var consumed = false
            let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
                if consumed {
                    outStatus.pointee = .noDataNow
                    return nil
                }
                consumed = true
                outStatus.pointee = .haveData
                return buffer
            }

            converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)

            if let error = error {
                print("音频转换错误: \(error)")
                return
            }

            // 提取 Data 并检测音量
            if let channelData = outputBuffer.int16ChannelData {
                let data = Data(
                    bytes: channelData[0],
                    count: Int(outputBuffer.frameLength) * MemoryLayout<Int16>.size)

                // 计算音量（取样本的绝对值平均）
                let samples = UnsafeBufferPointer(
                    start: channelData[0], count: Int(outputBuffer.frameLength))
                let avgVolume = samples.reduce(0) { $0 + abs(Float($1)) } / Float(samples.count)

                // 实时推送音量数据用于 UI 动画
                DispatchQueue.main.async {
                    self.onVolumeChanged?(avgVolume)
                }

                // 静音检测（加锁保证音频线程与主线程之间的安全访问）
                self.silenceLock.lock()
                let shouldWarn: Bool
                if avgVolume < self.volumeThreshold {
                    self.silentPacketCount += 1
                    shouldWarn = self.silentPacketCount >= self.silentThreshold && !self.hasSilenceWarned
                    if shouldWarn { self.hasSilenceWarned = true }
                } else {
                    self.silentPacketCount = 0
                    self.hasSilenceWarned = false
                    shouldWarn = false
                }
                self.silenceLock.unlock()

                if shouldWarn {
                    DispatchQueue.main.async {
                        self.onSilenceDetected?()
                    }
                }

                self.onAudioData?(data)
            }
        }

        do {
            try audioEngine.start()
            isRecording = true
            print("[AudioRecorder] 开始录音")
        } catch {
            let error = NSError(
                domain: "AudioRecorder",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "无法启动音频引擎: \(error.localizedDescription)"]
            )
            onError?(error)
            print("[AudioRecorder] 启动录音失败: \(error.localizedDescription)")
        }
    }

    func stop() {
        guard isRecording else { return }

        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine?.reset()  // 彻底释放音频引擎资源
        audioEngine = nil
        inputNode = nil
        isRecording = false
        silenceLock.lock()
        silentPacketCount = 0
        hasSilenceWarned = false
        silenceLock.unlock()
        print("[AudioRecorder] 停止录音")
    }
}
