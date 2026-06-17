import Foundation

// MARK: - 本地草稿管理器 — 自动保存 + 离线暂存

@MainActor
final class DraftManager: ObservableObject {
    static let shared = DraftManager()

    @Published var localDrafts: [LocalDraft] = []
    @Published var isSaving = false
    @Published var lastSaveError: String?

    private let storageKey = "memoir_local_drafts"
    private let autoSaveInterval: TimeInterval = 5.0
    private var autoSaveTimer: Timer?
    private var pendingSave: LocalDraft?

    private init() {
        loadFromDisk()
    }

    // MARK: - 本地草稿操作

    /// 创建或更新本地草稿
    func saveLocalDraft(
        id: String? = nil,
        title: String,
        content: String,
        tags: [String] = [],
        mood: String? = nil,
        date: String? = nil,
        media: [String] = [],
        serverDraftId: String? = nil
    ) -> LocalDraft {
        let draftId = id ?? UUID().uuidString
        let draft = LocalDraft(
            id: draftId,
            title: title,
            content: content,
            tags: tags,
            mood: mood,
            date: date,
            media: media,
            savedAt: Date(),
            serverDraftId: serverDraftId
        )

        if let index = localDrafts.firstIndex(where: { $0.id == draftId }) {
            localDrafts[index] = draft
        } else {
            localDrafts.insert(draft, at: 0)
        }

        persistToDisk()
        return draft
    }

    /// 删除本地草稿
    func removeLocalDraft(id: String) {
        localDrafts.removeAll { $0.id == id }
        persistToDisk()
    }

    /// 获取本地草稿
    func getLocalDraft(id: String) -> LocalDraft? {
        localDrafts.first { $0.id == id }
    }

    // MARK: - 自动保存（编辑器防抖）

    func scheduleAutoSave(draft: LocalDraft) {
        pendingSave = draft
        autoSaveTimer?.invalidate()
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: autoSaveInterval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                await self?.performAutoSave()
            }
        }
    }

    func cancelAutoSave() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = nil
        pendingSave = nil
    }

    private func performAutoSave() async {
        guard let draft = pendingSave else { return }
        isSaving = true
        defer { isSaving = false }

        // 1. 先保存到本地
        saveLocalDraft(
            id: draft.id,
            title: draft.title,
            content: draft.content,
            tags: draft.tags,
            mood: draft.mood,
            date: draft.date,
            media: draft.media,
            serverDraftId: draft.serverDraftId
        )

        // 2. 尝试同步到服务端
        do {
            let serverDraft = try await MemoirService.shared.saveDraft(
                SaveDraftRequest(
                    id: draft.serverDraftId,
                    title: draft.title,
                    content: draft.content,
                    tags: draft.tags,
                    mood: draft.mood,
                    date: draft.date,
                    media: draft.media
                )
            )
            // 更新 serverDraftId
            if let index = localDrafts.firstIndex(where: { $0.id == draft.id }) {
                localDrafts[index].serverDraftId = serverDraft.id
                persistToDisk()
            }
            lastSaveError = nil
        } catch {
            lastSaveError = "离线模式：已保存到本地"
        }
    }

    // MARK: - 同步

    /// 将本地草稿同步到服务端（网络恢复时调用）
    func syncToServer() async {
        let unsynced = localDrafts.filter { $0.serverDraftId == nil }
        guard !unsynced.isEmpty else { return }

        for draft in unsynced {
            do {
                let serverDraft = try await MemoirService.shared.saveDraft(
                    SaveDraftRequest(
                        id: nil,
                        title: draft.title,
                        content: draft.content,
                        tags: draft.tags,
                        mood: draft.mood,
                        date: draft.date,
                        media: draft.media
                    )
                )
                if let index = localDrafts.firstIndex(where: { $0.id == draft.id }) {
                    localDrafts[index].serverDraftId = serverDraft.id
                }
            } catch {
                break // 网络不可用，停止同步
            }
        }
        persistToDisk()
    }

    // MARK: - 持久化

    private func persistToDisk() {
        guard let data = try? JSONEncoder().encode(localDrafts) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func loadFromDisk() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let drafts = try? JSONDecoder().decode([LocalDraft].self, from: data)
        else { return }
        localDrafts = drafts.sorted { $0.savedAt > $1.savedAt }
    }
}
