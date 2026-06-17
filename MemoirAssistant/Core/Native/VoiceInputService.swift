import Foundation
import Speech
import AVFoundation

// MARK: - 语音输入服务 — SFSpeechRecognizer 实时转写

@MainActor
final class VoiceInputService: NSObject, ObservableObject, SFSpeechRecognizerDelegate {
    static let shared = VoiceInputService()

    @Published var transcribedText = ""
    @Published var isRecording = false
    @Published var isAuthorized = false
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    @Published var audioLevels: [CGFloat] = Array(repeating: 0, count: 20) // 波形可视化

    private let speechRecognizer: SFSpeechRecognizer?
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var silenceTimer: Timer?
    private var lastTranscription: String = ""

    // MARK: - 初始化

    override init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
        super.init()
        speechRecognizer?.delegate = self
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                self?.authorizationStatus = status
                self?.isAuthorized = status == .authorized
            }
        }
    }

    // MARK: - 请求权限

    func requestAuthorization() async -> Bool {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                Task { @MainActor in
                    self.authorizationStatus = status
                    self.isAuthorized = status == .authorized
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

        // 配置音频输入
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            // 计算音量等级用于波形
            Task { @MainActor in
                self?.updateAudioLevels(from: buffer)
            }
        }

        audioEngine.prepare()
        try audioEngine.start()

        isRecording = true
        transcribedText = ""
        lastTranscription = ""

        // 开始识别
        guard let recognizer = speechRecognizer else {
            throw VoiceError.recognitionUnavailable
        }
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                let transcription = result.bestTranscription.formattedString
                Task { @MainActor in
                    self.transcribedText = transcription
                    self.lastTranscription = transcription
                    self.resetSilenceTimer()
                }
            }

            if let error = error {
                print("[VoiceInput] 识别错误: \(error.localizedDescription)")
                Task { @MainActor in
                    if !self.isRecording { return }
                    self.stopRecording()
                }
            }
        }
    }

    // MARK: - 停止录音

    func stopRecording() {
        silenceTimer?.invalidate()
        silenceTimer = nil

        recognitionTask?.cancel()
        recognitionTask = nil

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        isRecording = false
    }

    // MARK: - 静默自动停止（2.5秒无语音）

    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.isRecording else { return }
                // 不再自动停止，保持监听直到用户手动停止
            }
        }
    }

    // MARK: - 波形计算

    private func updateAudioLevels(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let frameLength = Int(buffer.frameLength)

        var sum: Float = 0
        for i in 0..<frameLength {
            let sample = channelData.pointee[i]
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(frameLength))
        let level = CGFloat(min(max(rms * 5, 0), 1))

        audioLevels.append(level)
        if audioLevels.count > 20 {
            audioLevels.removeFirst(audioLevels.count - 20)
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
