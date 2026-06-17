import Foundation
import Speech
import AVFoundation
import Darwin // for memset

// MARK: - 语音输入服务 — SFSpeechRecognizer 实时转写
// 设计要点：
// 1. 音频回调在实时线程，不做任何 UI 操作，只计算 RMS 存入原子变量
// 2. 用 MainActor 的 Timer 以 5Hz（200ms）轮询最新 RMS，更新 audioLevels
// 3. 识别结果在主线程回调，直接更新 @Published 属性

@MainActor
final class VoiceInputService: NSObject, ObservableObject, SFSpeechRecognizerDelegate {
    static let shared = VoiceInputService()

    @Published var transcribedText = ""
    @Published var isRecording = false
    @Published var isAuthorized = false
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    @Published var audioLevels: [CGFloat] = Array(repeating: 0, count: 20) // 波形可视化

    // 语音识别组件
    private let speechRecognizer: SFSpeechRecognizer?
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    // 波形更新定时器（MainActor，5Hz）
    private var waveformTimer: Timer?

    // 音频电平（原子访问，音频回调线程 → MainActor 定时器）
    // 使用 Darwin 原子操作或简单的 unprotected write（单写者 + 主线程读 可以接受）
    private var latestRMS: Float = 0

    // MARK: - 初始化

    override init() {
        // SFSpeechRecognizer 在不支持的设备上为 nil，必须 optional 绑定
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
        self.speechRecognizer = recognizer
        super.init()
        recognizer?.delegate = self

        // 请求权限（非阻塞）
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                self?.authorizationStatus = status
                self?.isAuthorized = (status == .authorized)
            }
        }
    }

    // MARK: - 请求权限

    func requestAuthorization() async -> Bool {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                Task { @MainActor in
                    self.authorizationStatus = status
                    self?.isAuthorized = (status == .authorized)
                }
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    // MARK: - 开始录音

    func startRecording() async throws {
        guard isAuthorized else {
            let granted = await requestAuthorization()
            guard granted else { throw VoiceError.notAuthorized }
            // 重新检查（权限请求是异步的）
            guard isAuthorized else { throw VoiceError.notAuthorized }
        }

        // 停止之前的会话
        stopRecording()

        // 配置音频会话
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw VoiceError.recognitionUnavailable
        }
        recognitionRequest.shouldReportPartialResults = true

        // 配置音频输入回调（在实时线程，不做 UI）
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            // 1. 将音频帧送入识别器
            self?.recognitionRequest?.append(buffer)
            // 2. 计算音量 RMS（纯计算，不碰 UI）
            self?.computeRMS(from: buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        isRecording = true
        transcribedText = ""
        latestRMS = 0

        // 启动波形更新定时器（5Hz = 200ms，MainActor）
        startWaveformTimer()

        // 开始识别
        guard let recognizer = speechRecognizer else {
            throw VoiceError.recognitionUnavailable
        }

        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                let transcription = result.bestTranscription.formattedString
                // 此回调在主线程（SFSpeechRecognizer 保证）
                self.transcribedText = transcription
            }

            if let error = error {
                print("[VoiceInput] 识别错误: \(error.localizedDescription)")
                Task { @MainActor in
                    self.stopRecording()
                }
            }
        }
    }

    // MARK: - 停止录音

    func stopRecording() {
        waveformTimer?.invalidate()
        waveformTimer = nil

        recognitionTask?.cancel()
        recognitionTask = nil

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        isRecording = false
        latestRMS = 0
    }

    // MARK: - 波形计算（音频回调线程）

    /// 在音频实时线程计算 RMS，结果存入 latestRMS
    private func computeRMS(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }

        var sum: Float = 0
        let data = channelData.pointee
        for i in 0..<frameLength {
            let sample = data[i]
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(frameLength))
        // 直接写入（单写者，MainActor 定时器稍后读，短暂过时可接受）
        latestRMS = rms
    }

    // MARK: - 波形定时器（MainActor，5Hz）

    private func startWaveformTimer() {
        waveformTimer?.invalidate()
        // 每 200ms（5Hz）更新一次波形，远低于音频帧率
        waveformTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self = self, self.isRecording else { return }
            let rms = self.latestRMS
            let level = CGFloat(min(max(rms * 5, 0), 1))

            // 平滑衰减（比裸值更自然）
            if let last = self.audioLevels.last {
                let smoothed = last * 0.6 + level * 0.4
                self.audioLevels.append(smoothed)
            } else {
                self.audioLevels.append(level)
            }
            if self.audioLevels.count > 20 {
                self.audioLevels.removeFirst(self.audioLevels.count - 20)
            }
        }
    }

    // MARK: - SFSpeechRecognizerDelegate

    nonisolated func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        Task { @MainActor in
            if !available {
                self.isAuthorized = false
            }
        }
    }

    deinit {
        stopRecording()
    }
}

// MARK: - 错误类型

enum VoiceError: LocalizedError {
    case notAuthorized
    case recognitionUnavailable

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "请在设置中开启语音识别权限"
        case .recognitionUnavailable:
            return "语音识别暂不可用，请稍后再试"
        }
    }
}
