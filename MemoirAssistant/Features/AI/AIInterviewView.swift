import SwiftUI

// MARK: - AI 访谈模式 (对话流 UI)

struct AIInterviewView: View {
    @StateObject private var viewModel = AIInterviewViewModel()
    @FocusState private var isInputFocused: Bool

    var body: some View {
        ZStack {
            MemoirColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // 对话列表
                if viewModel.messages.isEmpty && !viewModel.isThinking {
                    welcomeView
                } else {
                    chatListView
                }

                // 输入栏
                inputBar
            }
        }
        .navigationTitle("AI 访谈")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !viewModel.messages.isEmpty {
                    Menu {
                        if let story = viewModel.generatedStory {
                            Button {
                                viewModel.saveStoryAsMemoir()
                            } label: {
                                Label("保存为回忆录", systemImage: "bookmark.fill")
                            }
                        }

                        Button(role: .destructive) {
                            viewModel.reset()
                        } label: {
                            Label("重新开始", systemImage: "arrow.counterclockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(MemoirColors.primary)
                    }
                }
            }
        }
        .task {
            await viewModel.loadDimensions()
        }
    }

    // MARK: - 欢迎页

    private var welcomeView: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.xl) {
                Spacer(minLength: 40)

                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 56))
                    .foregroundColor(MemoirColors.primary)

                Text("AI 回忆访谈")
                    .font(.system(size: DesignTokens.Typography.title, weight: .bold))
                    .foregroundColor(MemoirColors.textPrimary)

                Text("选择一个人生维度，AI 会像老朋友一样\n陪你聊聊那些珍贵的回忆")
                    .font(.system(size: DesignTokens.Typography.body))
                    .foregroundColor(MemoirColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal)

                // 维度选择
                if viewModel.isLoadingDimensions {
                    ProgressView()
                        .padding()
                } else {
                    VStack(spacing: DesignTokens.Spacing.sm) {
                        ForEach(viewModel.dimensions) { dim in
                            dimensionCard(dim)
                        }
                    }
                    .padding(.horizontal)
                }

                Spacer(minLength: 100)
            }
        }
    }

    private func dimensionCard(_ dim: AIInterviewService.AIDimension) -> some View {
        Button {
            viewModel.selectedDimension = dim
        } label: {
            HStack(spacing: DesignTokens.Spacing.md) {
                Text(dim.icon)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(dim.name)
                        .font(.system(size: DesignTokens.Typography.headline, weight: .semibold))
                        .foregroundColor(MemoirColors.textPrimary)

                    Text(dim.description)
                        .font(.system(size: DesignTokens.Typography.bodySmall))
                        .foregroundColor(MemoirColors.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(MemoirColors.textTertiary)
            }
            .padding(DesignTokens.Spacing.md)
            .background(MemoirColors.card)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
            .shadow(
                color: DesignTokens.Shadow.card.color,
                radius: DesignTokens.Shadow.card.radius,
                y: DesignTokens.Shadow.card.y
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 对话列表

    private var chatListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: DesignTokens.Spacing.md) {
                    // 维度标题
                    if let dim = viewModel.selectedDimension {
                        HStack {
                            Spacer()
                            Text("\(dim.icon) \(dim.name)")
                                .font(.system(size: DesignTokens.Typography.caption, weight: .medium))
                                .foregroundColor(MemoirColors.primary)
                                .padding(.horizontal, DesignTokens.Spacing.md)
                                .padding(.vertical, 6)
                                .background(MemoirColors.primary.opacity(0.1))
                                .clipShape(Capsule())
                            Spacer()
                        }
                        .padding(.top, DesignTokens.Spacing.sm)
                    }

                    ForEach(viewModel.messages) { msg in
                        chatBubble(msg)
                            .id(msg.id)
                    }

                    // 正在输入指示器
                    if viewModel.isThinking {
                        thinkingIndicator
                    }

                    // 故事脉络
                    if let story = viewModel.generatedStory {
                        storyOutlineCard(story)
                    }

                    // 锚点
                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .padding(.vertical, DesignTokens.Spacing.md)
            }
            .onChange(of: viewModel.messages.count) { _ in
                withAnimation {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onChange(of: viewModel.isThinking) { _ in
                withAnimation {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    // MARK: - 聊天气泡

    private func chatBubble(_ msg: AIInterviewService.ChatMessage) -> some View {
        HStack(alignment: .top) {
            if msg.role == "assistant" {
                // AI 头像
                Image(systemName: "brain.head.profile")
                    .font(.title3)
                    .foregroundColor(MemoirColors.primary)
                    .frame(width: 32, height: 32)
                    .background(MemoirColors.primary.opacity(0.1))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 0) {
                    Text(msg.content)
                        .font(.system(size: DesignTokens.Typography.body))
                        .foregroundColor(MemoirColors.textPrimary)
                        .padding(DesignTokens.Spacing.md)
                        .background(MemoirColors.surface)
                        .clipShape(
                            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
                                .stroke(MemoirColors.border, lineWidth: 0.5)
                        )

                    if msg.isStreaming {
                        HStack(spacing: 2) {
                            Circle()
                                .fill(MemoirColors.primary)
                                .frame(width: 4, height: 4)
                                .opacity(0.3)
                            Circle()
                                .fill(MemoirColors.primary)
                                .frame(width: 4, height: 4)
                                .opacity(0.6)
                            Circle()
                                .fill(MemoirColors.primary)
                                .frame(width: 4, height: 4)
                        }
                        .padding(.leading, 4)
                        .padding(.top, 4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 40)
            } else {
                Spacer(minLength: 40)

                VStack(alignment: .trailing) {
                    Text(msg.content)
                        .font(.system(size: DesignTokens.Typography.body))
                        .foregroundColor(.white)
                        .padding(DesignTokens.Spacing.md)
                        .background(MemoirColors.primary)
                        .clipShape(
                            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
                        )
                }
            }
        }
    }

    // MARK: - 正在输入指示器

    private var thinkingIndicator: some View {
        HStack(alignment: .top) {
            Image(systemName: "brain.head.profile")
                .font(.title3)
                .foregroundColor(MemoirColors.primary)
                .frame(width: 32, height: 32)
                .background(MemoirColors.primary.opacity(0.1))
                .clipShape(Circle())

            HStack(spacing: 4) {
                Circle()
                    .fill(MemoirColors.primary.opacity(0.4))
                    .frame(width: 6, height: 6)
                    .scaleEffect(viewModel.thinkingDotScale ? 1.3 : 0.7)
                Circle()
                    .fill(MemoirColors.primary.opacity(0.6))
                    .frame(width: 6, height: 6)
                    .scaleEffect(viewModel.thinkingDotScale ? 1.3 : 0.7)
                    .animation(.easeInOut(duration: 0.3).delay(0.15), value: viewModel.thinkingDotScale)
                Circle()
                    .fill(MemoirColors.primary.opacity(0.8))
                    .frame(width: 6, height: 6)
                    .scaleEffect(viewModel.thinkingDotScale ? 1.3 : 0.7)
                    .animation(.easeInOut(duration: 0.3).delay(0.3), value: viewModel.thinkingDotScale)
            }
            .padding(DesignTokens.Spacing.md)
            .background(MemoirColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
                    .stroke(MemoirColors.border, lineWidth: 0.5)
            )

            Spacer(minLength: 40)
        }
    }

    // MARK: - 故事脉络卡片

    private func storyOutlineCard(_ story: String) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(MemoirColors.primary)
                Text("AI 为你整理的故事脉络")
                    .font(.system(size: DesignTokens.Typography.bodySmall, weight: .semibold))
                    .foregroundColor(MemoirColors.primary)
            }

            Text(story)
                .font(.system(size: DesignTokens.Typography.bodySmall))
                .foregroundColor(MemoirColors.textPrimary)
                .lineSpacing(6)

            Button {
                viewModel.saveStoryAsMemoir()
            } label: {
                Label("保存为回忆录草稿", systemImage: "square.and.arrow.down")
                    .font(.system(size: DesignTokens.Typography.bodySmall, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
            }
            .buttonStyle(.borderedProminent)
            .tint(MemoirColors.primary)
        }
        .padding(DesignTokens.Spacing.md)
        .background(MemoirColors.card)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
                .stroke(MemoirColors.primary.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - 输入栏

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider()
                .background(MemoirColors.border)

            HStack(spacing: DesignTokens.Spacing.sm) {
                // 生成故事按钮
                if viewModel.messages.count >= 4 {
                    Button {
                        Task { await viewModel.generateStoryOutline() }
                    } label: {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16))
                            .foregroundColor(viewModel.isThinking ? MemoirColors.textTertiary : MemoirColors.primary)
                    }
                    .disabled(viewModel.isThinking)
                }

                TextField("说说你的回忆...", text: $viewModel.inputText, axis: .vertical)
                    .font(.system(size: DesignTokens.Typography.body))
                    .focused($isInputFocused)
                    .lineLimit(1...4)
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .background(MemoirColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
                            .stroke(MemoirColors.border, lineWidth: 0.5)
                    )
                    .disabled(viewModel.isThinking)
                    .onSubmit {
                        Task { await viewModel.sendMessage() }
                    }

                Button {
                    Task { await viewModel.sendMessage() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(
                            viewModel.inputText.trimmingCharacters(in: .whitespaces).isEmpty
                                ? MemoirColors.textTertiary
                                : MemoirColors.primary
                        )
                }
                .disabled(viewModel.inputText.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isThinking)
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
        }
        .background(MemoirColors.background)
    }
}

// MARK: - ViewModel

@MainActor
final class AIInterviewViewModel: ObservableObject {
    @Published var dimensions: [AIInterviewService.AIDimension] = []
    @Published var selectedDimension: AIInterviewService.AIDimension? {
        didSet {
            if selectedDimension != nil, messages.isEmpty {
                addSystemGreeting()
            }
        }
    }
    @Published var messages: [AIInterviewService.ChatMessage] = []
    @Published var inputText = ""
    @Published var isThinking = false
    @Published var thinkingDotScale = false
    @Published var generatedStory: String?
    @Published var isLoadingDimensions = false

    private let service = AIInterviewService.shared
    private var thinkingTimer: Timer?

    func loadDimensions() async {
        isLoadingDimensions = true
        defer { isLoadingDimensions = false }

        do {
            dimensions = try await service.fetchDimensions()
        } catch {
            // 使用预设维度
            dimensions = [
                AIInterviewService.AIDimension(
                    id: "childhood", name: "童年时光", description: "聊聊小时候的故事",
                    icon: "🧸", prompt: "陪我聊聊童年"
                ),
                AIInterviewService.AIDimension(
                    id: "education", name: "求学之路", description: "读书时代的记忆",
                    icon: "📚", prompt: "陪我聊聊上学"
                ),
                AIInterviewService.AIDimension(
                    id: "work", name: "职场生涯", description: "工作中的故事",
                    icon: "💼", prompt: "陪我聊聊工作"
                ),
                AIInterviewService.AIDimension(
                    id: "family", name: "家庭生活", description: "家人和家庭回忆",
                    icon: "👨‍👩‍👧‍👦", prompt: "陪我聊聊家庭"
                ),
                AIInterviewService.AIDimension(
                    id: "love", name: "爱情故事", description: "爱情和婚姻的回忆",
                    icon: "💕", prompt: "陪我聊聊爱情"
                ),
                AIInterviewService.AIDimension(
                    id: "travel", name: "旅途记忆", description: "旅行中的见闻",
                    icon: "✈️", prompt: "陪我聊聊旅行"
                ),
            ]
        }
    }

    private func addSystemGreeting() {
        guard let dim = selectedDimension else { return }
        let greeting = AIInterviewService.ChatMessage(
            role: "assistant",
            content: "你好！我是「忆往昔」AI 助手。关于**\(dim.name)**，我们先从哪聊起呢？你可以像和老朋友聊天一样，想到什么就说什么。"
        )
        messages.append(greeting)
    }

    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !isThinking else { return }

        let userMsg = AIInterviewService.ChatMessage(role: "user", content: text)
        messages.append(userMsg)
        inputText = ""

        startThinking()
        defer { stopThinking() }

        do {
            let payloads: [AIInterviewService.ChatMessagePayload] = messages.map {
                AIInterviewService.ChatMessagePayload(role: $0.role, content: $0.content)
            }

            let data = try await service.sendMessage(
                messages: payloads,
                dimensionId: selectedDimension?.id
            )

            let aiMsg = AIInterviewService.ChatMessage(role: "assistant", content: data.message)
            messages.append(aiMsg)
        } catch {
            let errorMsg = AIInterviewService.ChatMessage(
                role: "assistant",
                content: "抱歉，我暂时无法回应。请稍后再试，或换一种方式聊聊？"
            )
            messages.append(errorMsg)
        }
    }

    func generateStoryOutline() async {
        guard messages.count >= 4, !isThinking else { return }

        startThinking()
        defer { stopThinking() }

        do {
            let payloads: [AIInterviewService.ChatMessagePayload] = messages.map {
                AIInterviewService.ChatMessagePayload(role: $0.role, content: $0.content)
            }

            generatedStory = try await service.generateStory(messages: payloads)
        } catch {
            // 静默失败
        }
    }

    func saveStoryAsMemoir() {
        let displayMessages = messages.filter { $0.role == "user" }
        let storyContent = generatedStory ?? displayMessages.map { $0.content }.joined(separator: "\n\n")

        let draft = DraftManager.shared.saveLocalDraft(
            title: selectedDimension.map { "关于\($0.name)的回忆" } ?? "AI 访谈回忆",
            content: storyContent,
            tags: selectedDimension.map { [$0.name] } ?? [],
            date: DateFormatter.yyyyMMdd.string(from: Date())
        )
        // 尝试同步到服务端
        Task {
            await DraftManager.shared.syncToServer()
        }
    }

    func reset() {
        messages = []
        generatedStory = nil
        selectedDimension = nil
        inputText = ""
    }

    private func startThinking() {
        isThinking = true
        thinkingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                withAnimation(.easeInOut(duration: 0.3)) {
                    self?.thinkingDotScale.toggle()
                }
            }
        }
    }

    private func stopThinking() {
        isThinking = false
        thinkingDotScale = false
        thinkingTimer?.invalidate()
        thinkingTimer = nil
    }
}

extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

#Preview {
    NavigationStack {
        AIInterviewView()
    }
}
