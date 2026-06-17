import SwiftUI

// MARK: - 语音输入视图 — 中老年友好大按钮设计

struct VoiceInputView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var voiceService = VoiceInputService.shared
    @State private var showPermissionAlert = false
    @State private var floatingLevels: [CGFloat] = Array(repeating: 0.3, count: 5)
    var onInsert: (String) -> Void

    var body: some View {
        ZStack {
            // 仿羊皮纸渐变背景
            LinearGradient(
                colors: [MemoirColors.background, MemoirColors.surface],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: DesignTokens.Spacing.xl) {
                // 顶部关闭
                HStack {
                    Spacer()
                    Button {
                        voiceService.stopRecording()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(MemoirColors.textTertiary)
                    }
                }
                .padding(.horizontal)

                Spacer()

                // 标题
                Text("语音输入")
                    .font(.system(size: DesignTokens.Typography.title, weight: .bold))
                    .foregroundColor(MemoirColors.textPrimary)

                Text(voiceService.isRecording ? "正在聆听..." : "点击下方按钮开始说话")
                    .font(.system(size: DesignTokens.Typography.body))
                    .foregroundColor(MemoirColors.textSecondary)
                    .multilineTextAlignment(.center)

                // 转写文本展示
                if !voiceService.transcribedText.isEmpty {
                    ScrollView {
                        Text(voiceService.transcribedText)
                            .font(.system(size: DesignTokens.Typography.title2))
                            .foregroundColor(MemoirColors.textPrimary)
                            .padding(DesignTokens.Spacing.lg)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(MemoirColors.card)
                            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.xl))
                            .shadow(
                                color: DesignTokens.Shadow.card.color,
                                radius: DesignTokens.Shadow.card.radius,
                                y: DesignTokens.Shadow.card.y
                            )
                            .padding(.horizontal)
                    }
                    .frame(maxHeight: 200)
                }

                // 波形动画
                if voiceService.isRecording {
                    waveformView
                        .frame(height: 80)
                        .padding(.horizontal, DesignTokens.Spacing.xl)
                }

                Spacer()

                // 录制按钮 — 大尺寸中老年友好
                recordButton

                // 操作按钮
                if !voiceService.transcribedText.isEmpty {
                    HStack(spacing: DesignTokens.Spacing.lg) {
                        Button {
                            voiceService.transcribedText = ""
                        } label: {
                            Label("清除", systemImage: "trash")
                                .frame(width: 100, height: 48)
                        }
                        .buttonStyle(.secondary)

                        Button {
                            voiceService.stopRecording()
                            onInsert(voiceService.transcribedText)
                            dismiss()
                        } label: {
                            Label("插入正文", systemImage: "text.insert")
                                .frame(width: 140, height: 48)
                        }
                        .buttonStyle(.primary)
                    }
                }

                Spacer()
            }
        }
        .alert("需要语音识别权限", isPresented: $showPermissionAlert) {
            Button("去设置") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("请在设置中开启语音识别权限，才能使用语音输入功能")
        }
    }

    // MARK: - 录制按钮

    private var recordButton: some View {
        Button {
            handleRecordButton()
        } label: {
            ZStack {
                // 外层脉冲环
                if voiceService.isRecording {
                    Circle()
                        .stroke(MemoirColors.danger.opacity(0.3), lineWidth: 3)
                        .frame(width: 110, height: 110)
                        .scaleEffect(voiceService.isRecording ? 1.2 : 1.0)
                        .opacity(voiceService.isRecording ? 0 : 0.5)
                        .animation(
                            .easeInOut(duration: 1.0).repeatForever(autoreverses: false),
                            value: voiceService.isRecording
                        )
                }

                // 按钮主体
                ZStack {
                    Circle()
                        .fill(voiceService.isRecording ? MemoirColors.danger : MemoirColors.primary)
                        .frame(width: 88, height: 88)
                        .shadow(
                            color: (voiceService.isRecording ? MemoirColors.danger : MemoirColors.primary).opacity(0.4),
                            radius: 16,
                            y: 8
                        )

                    Image(systemName: voiceService.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.white)
                }
                .scaleEffect(voiceService.isRecording ? 0.95 : 1.0)
                .animation(DesignTokens.Animation.pressDown, value: voiceService.isRecording)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - 波形视图

    private var waveformView: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(0..<min(voiceService.audioLevels.count, 20), id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [MemoirColors.primary, MemoirColors.primaryLight],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 4)
                    .frame(height: max(8, voiceService.audioLevels[i] * 70))
                    .animation(.easeInOut(duration: 0.15), value: voiceService.audioLevels[i])
            }
        }
    }

    // MARK: - 处理录制按钮点击

    private func handleRecordButton() {
        if voiceService.isRecording {
            voiceService.stopRecording()
        } else {
            Task {
                do {
                    try await voiceService.startRecording()
                } catch {
                    if case VoiceError.notAuthorized = error {
                        showPermissionAlert = true
                    }
                }
            }
        }
    }
}

#Preview {
    VoiceInputView(onInsert: { _ in })
}
