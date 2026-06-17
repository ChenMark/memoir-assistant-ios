# 忆往昔 iOS — 第二轮代码审视报告
**审查日期**: 2026-06-17  
**审查范围**: 全量 iOS 代码 (12030 行) + 后端代码  
**审查重点**: 修复后复查 + 深层并发/内存/安全问题

---

## 一、审查结论

| 维度 | 上次评级 | 本次评级 | 变化 |
|------|-----------|-----------|------|
| 架构分层 | A- | **A** | ↑ 修复 P0 后显著提升 |
| 网络安全 | B+ | **A-** | ↑ 重试机制完善 |
| 并发安全 | C+ | **B-** | ↑ 有提升，仍有隐患 |
| 内存管理 | B | **B-** | ↓ VoiceInput 高频 Task 新建 |
| 错误处理 | B- | **B** | ↑ 全局捕获已实现 |
| **综合评级** | **B+** | **A-** | **↑ 半级提升** |

**整体评价**: 代码质量显著提升，P0 编译问题已全部修复。但**信号处理器**和 **VoiceInput 音频线程**两个深层问题需要紧急处理。

---

## 二、🔴 P0 关键问题（必须修复）

### P0-1: `CrashReportService.swift` — 信号处理器调用非异步信号安全函数

**位置**: 第 33-37 行  
**问题**: `signal()` 注册的处理器只能调用异步信号安全函数（man 7 signal-safety）。调用 Swift 方法（`logger.critical`）可能导致**死锁或二次崩溃**。

```swift
// ❌ 危险代码
signal(SIGABRT) { _ in CrashReportService.shared.handleSignal("SIGABRT") }
```

**风险**:
- 信号处理器中调用 `os_log` → 可能内部加锁 → 死锁
- 二次崩溃会触发 `SIGABRT` → 无限递归

**修复方案**:
```swift
// ✅ 正确方案：仅写文件描述符
private func setupSignalHandlers() {
    let fd = crashLogFileDescriptor()
    signal(SIGABRT) { _ in
        let msg = "SIGABRT at \(Date())\n"
        write(fd, msg, msg.utf8.count)
        exit(1)  // 强制退出，不返回
    }
}
```

---

### P0-2: `VoiceInputService.swift` — 音频回调线程高频创建 Task

**位置**: 第 78-84 行  
**问题**: `installTap` 的回调在**音频实时线程**执行，每 1024 帧（~21ms @ 48kHz）创建一个 `Task { @MainActor in }`。这会导致：
- 音频线程阻塞（Task 创建有开销）
- MainActor 队列风暴（每 21ms 一个 Task）
- 可能导致音频卡顿

```swift
// ❌ 危险代码（每 21ms 执行一次）
inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
    self?.recognitionRequest?.append(buffer)
    Task { @MainActor in      // ← 每 21ms 创建一个 Task！
        self?.updateAudioLevels(from: buffer)
    }
}
```

**修复方案**:
```swift
// ✅ 方案 1：降低更新频率（每 200ms 一次）
private var lastLevelUpdate = Date()
inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
    self?.recognitionRequest?.append(buffer)
    
    let now = Date()
    if now.timeIntervalSince(lastLevelUpdate) > 0.2 {  // 限流 5Hz
        lastLevelUpdate = now
        DispatchQueue.main.async {
            self?.updateAudioLevels(from: buffer)
        }
    }
}

// ✅ 方案 2：用 DispatchQueue 替代 Task（更低开销）
inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
    self?.recognitionRequest?.append(buffer)
    self?.audioBufferQueue.async {
        let levels = self?.calculateAudioLevels(buffer) ?? []
        DispatchQueue.main.async {
            self?.audioLevels = levels
        }
    }
}
private let audioBufferQueue = DispatchQueue(label: "memoir.voice.buffer", qos: .userInteractive)
```

---

## 三、🟠 P1 高风险问题

### P1-1: `PerformanceMonitor.swift` — Timer 强引用循环

**位置**: 第 65 行  
**问题**: `Timer.scheduledTimer` 闭包未声明 `[weak self]`，导致 `self` 无法释放。

```swift
// ❌ 内存泄漏
memoryTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
    let memMB = self.memoryUsageMB  // ← 强引用
    if memMB > 200 {
        self.logger.warning(...)  // ← 强引用
    }
}
```

**修复**:
```swift
// ✅ 修复后
memoryTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
    guard let self = self else { return }
    let memMB = self.memoryUsageMB
    if memMB > 200 {
        self.logger.warning("⚠️ 内存使用过高: \(memMB)MB")
    }
}
```

---

### P1-2: `ImageCacheManager.swift` — 磁盘 I/O 阻塞主线程风险

**位置**: 第 110-126 行、128-142 行  
**问题**: `withCheckedContinuation` 内部调用 `Data(contentsOf:)` 和 `try? Data.write(to:)` 是**同步磁盘 I/O**，在 utility 队列执行但continuation 未正确处理错误。

**修复方案**:
```swift
// ✅ 改进版：用 async/await 磁盘 I/O
private func loadFromDisk(key: String) async -> UIImage? {
    await withCheckedContinuation { continuation in
        diskCacheQueue.async {
            let fileURL = self.diskCacheURL.appendingPathComponent(key)
            do {
                let data = try Data(contentsOf: fileURL)
                continuation.resume(returning: UIImage(data: data))
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }
}
```

---

### P1-3: `WidgetDataWriter.swift` — 日期格式化性能问题

**位置**: 第 21-28 行  
**问题**: 每次调用 `refreshWidgetData()` 都创建 `DateFormatter()`，应该复用实例。

```swift
// ❌ 每次创建 DateFormatter（昂贵操作）
let fmt = DateFormatter()
fmt.dateFormat = "yyyy-MM-dd"
```

**修复**:
```swift
// ✅ 复用实例
private let dateFormatter: DateFormatter = {
    let fmt = DateFormatter()
    fmt.dateFormat = "yyyy-MM-dd"
    return fmt
}()

private func findDailyMemoir() -> Memoir? {
    let today = Calendar.current.dateComponents([.month, .day], from: Date())
    return memoirs.first { memoir in
        let dateStr = dateFormatter.string(from: memoir.date)
        let comps = Calendar.current.dateComponents([.month, .day], from: DateFormatter().date(from: dateStr) ?? Date())
        return comps.month == today.month && comps.day == today.day
    }
}
```

---

## 四、🟡 P2 中风险问题

### P2-1: `IPadMemoirListView.swift` — 分页加载可能重复触发

**位置**: 第 195 行  
**问题**: `.onAppear` 在 ScrollView 滚动时会**反复触发**，导致重复加载同一页。

**修复方案**:
```swift
// ✅ 添加加载状态锁
@State private var isLoadingMore = false

ProgressView()
    .frame(maxWidth: .infinity)
    .padding()
    .task {
        guard !isLoadingMore, currentPage < totalPages else { return }
        isLoadingMore = true
        await loadPage(currentPage + 1)
        isLoadingMore = false
    }
```

---

### P2-2: `APIClient.swift` — 重试逻辑对 401 不友好

**位置**: 第 106-118 行  
**问题**: 401 错误会触发 `sessionExpired` 通知，但如果重试逻辑意外重试 401 请求，会导致多次登出通知。

**建议**: 在 `shouldRetry()` 中排除 401：
```swift
private func shouldRetry(_ error: APIError) -> Bool {
    switch error {
    case .serverError(let code): return code >= 500  // 排除 401/429
    case .networkError: return true
    default: return false
    }
}
```

---

### P2-3: 后端 `agent.ts` — 缺少 conversationId 格式校验

**位置**: 第 89 行  
**问题**: `conversationId` 来自客户端，未校验格式。恶意用户可传入超长字符串导致 DoS。

**修复方案**:
```typescript
// ✅ 添加校验
const { messages, conversationId } = req.body as {
  messages: ChatMessage[];
  conversationId?: string;
};

if (conversationId && (typeof conversationId !== 'string' || conversationId.length > 100)) {
  return res.status(400).json({ error: 'conversationId 格式错误' });
}
```

---

## 五、🟢 P3 低风险评估

| 位置 | 问题 | 影响 |
|------|------|------|
| `KeychainManager.swift:60-77` | `save(key:value:)` 和 `saveToken()` 使用相同 `service` | 理论上可能 key 冲突，但实际不会（tokenKey 固定） |
| `GalleryService.swift:16` | 用字符串拼接 URL（非 URLComponents） | `page`/`limit` 含特殊字符时会崩溃 |
| `IPadGalleryView.swift:319-326` | 每张缩略图都创建 `Task { await loadThumb() }` | 快速滚动时可能创建大量并发 Task |
| `MemoirAssistantApp.swift:143` | `performaceMonitor` 未持久化到文件 | 无法事后分析用户性能问题 |

---

## 六、架构优点（值得保持）

✅ **MVVM 分层清晰**：View 不含业务逻辑，Service 不含 UI 代码  
✅ **Keychain 安全策略**：`kSecAttrAccessibleWhenUnlockedThisDeviceOnly` 正确  
✅ **DesignToken 全覆盖**：统一字体/颜色/间距，修改主题只需改一处  
✅ **无障碍基础扎实**：Dynamic Type 支持、VoiceOver label 完整  
✅ **OSLog 结构化日志**：9 个分类，支持按级别过滤  

---

## 七、修复优先级建议

```
立即修复 (本周):
  🔴 P0-1: 信号处理器改为只写文件描述符
  🔴 P0-2: VoiceInput 音频回调限流（5Hz）

TestFlight 前修复 (2 周内):
  🟠 P1-1: PerformanceMonitor Timer 强引用修复
  🟠 P1-2: ImageCacheManager 错误处
```

---

## 八、总结

**代码质量**: A- 级（修复 P0 后可达 A 级）  
**可发布状态**: ⚠️ **不建议直接上架**，需先修复 P0-1 和 P0-2  
**下一步行动**:
1. 立即修复 P0-1（信号处理器）
2. 立即修复 P0-2（VoiceInput 限流）
3. TestFlight 前修复所有 P1
4. 上架后优化 P2/P3

**整体评价**: 代码架构优秀，设计系统完善，但**底层系统编程**（信号处理、音频线程、内存管理）需要更谨慎的处理。修复 P0 后可安全发布。
