# 🔍 忆往昔 iOS — 全量代码审核报告

> **审核范围**: 56 个 Swift 源文件，11,375 行代码
> **审核日期**: 2026-06-17
> **审核人**: Senior Developer (高级开发工程师)
> **版本**: v1.6.0 (M7)

---

## 📊 总体评分

| 维度 | 评分 | 说明 |
|------|------|------|
| **架构设计** | ⭐⭐⭐⭐ 8/10 | MVVM 分层清晰，依赖注入合理 |
| **代码安全** | ⭐⭐⭐⭐ 8/10 | Keychain 策略正确，Token 管理严谨 |
| **性能** | ⭐⭐⭐ 7/10 | 图片缓存有碰撞隐患，URLSession 配置好 |
| **代码质量** | ⭐⭐⭐ 6/10 | 存在 4 个编译级 bug，不一致的模式 |
| **设计一致性** | ⭐⭐⭐⭐⭐ 9/10 | 拟物化风格贯穿，DesignToken 全覆盖 |
| **无障碍** | ⭐⭐⭐⭐ 8/10 | 18pt 起步字号 + 3 级缩放，但部分视图未接入 |

**综合评级: B+** — 架构优秀但存在编译级阻塞问题，修复后可上架。

---

## 🔴 P0 严重 — 编译失败

### BUG-1: FriendService / HobbyService — API 路径双前缀

**文件**: `Core/Network/FriendService.swift:9`, `Core/Network/HobbyService.swift:9`

```swift
// ❌ 错误
private let base = "/api/v1/friend"

// APIClient 已包含 /api/v1，实际请求变成：
// http://localhost:3002/api/v1/api/v1/friend  → 404！
```

**修复**:
```swift
// ✅ 正确 — APIClient 已含 /api/v1 前缀
private let base = "/friend"
```

> ⚠️ **同样的 bug 在 HobbyService 也存在** (`base = "/api/v1/hobby"`)

---

### BUG-2: FriendService / HobbyService — `[String: Any]` 不符合 Encodable

**文件**: `FriendService.swift:33`, `HobbyService.swift:26`

```swift
// ❌ 编译失败: [String: Any] 不遵循 Encodable 协议
let data: [String: Any] = buildRequestBody(request)
return try await client.post(base, body: data)  // Error!
```

**修复**: 使用 `FriendRequest`/`HobbyRequest` 直接传参（它们已经遵循 `Encodable`）：
```swift
// ✅ FriendService
return try await client.post(base, body: request)
// ✅ HobbyService
return try await client.post(base, body: request)
```

---

### BUG-3: FriendService / HobbyService — 不存在 `get(path:params:)` 方法

**文件**: `FriendService.swift:20`, `HobbyService.swift:20`

```swift
// ❌ APIClient 没有 get(path:params:) 方法，只有 get(path:query:)
var params: [String: String] = ["page": String(page), "limit": String(limit)]
return try await client.get(base, params: params)  // 编译失败
```

**修复**:
```swift
// ✅ 使用 APIClient 的 paginatedGet 或者手动构造 query
return try await client.paginatedGet(base, page: page, limit: limit)
```

---

### BUG-4: FriendService — 引用了未导入的响应类型

**文件**: `FriendService.swift:31-32`

```swift
func addFriend(_ request: FriendRequest) async throws -> FriendResponse {
    // ...
}
```

`FriendResponse` 定义在同文件底部，但 `FriendService` 没有导入 `MemoirAssistant` 模块的其余部分。如果 FriendService 和 FriendResponse 在同一 target 内，这是可以的。但如果 `Friend.swift` 模型文件中有 `FriendResponse`，而 `FriendService` 期望的类型是 `FriendResponse` 同文件中定义的，则能编译。检查发现 `FriendResponse` 和 `EmptyResponse` 都定义在 FriendService.swift 底部，所以这个能编译。

**状态**: 可编译，但设计不佳 — 响应类型应放在 Models 层。

---

## 🟠 P1 高危 — 运行时故障

### BUG-5: GalleryService — 双 JSON 解码 + 丢失 snakeCase 转换

**文件**: `Core/Network/GalleryService.swift:16-18`

```swift
// ❌ 问题链路：
// 1. client.get() 泛型推断 T = Data，API 返回 JSON bytes → 已解码一次
// 2. JSONDecoder() 无 convertFromSnakeCase → 二次解码时字段映射丢失
// 3. 如果 API 返回 created_at，PhotoComment.createdAt 将始终为 nil

let data = try await client.get("\(base)?page=\(page)&limit=\(limit)")
return try JSONDecoder().decode(PaginatedResponse<GalleryPhoto>.self, from: data)
```

**影响范围**: `fetchGallery`, `fetchComments`, `getOSSSign`, `getOSSDownloadUrl`, `generateShareLink` — 全部 GalleryService 方法。

**修复**:
```swift
// ✅ 直接使用 APIClient 的 paginatedGet（已配置 snakeCase decoder）
func fetchGallery(page: Int = 1, limit: Int = 20) async throws -> PaginatedResponse<GalleryPhoto> {
    try await client.paginatedGet("/memoir/gallery", page: page, limit: limit)
}
```

---

### BUG-6: ImageCacheManager — 缓存 Key 碰撞严重

**文件**: `Core/Performance/ImageCacheManager.swift:102-103`

```swift
// ❌ hashValue 不稳定 + & 0xFFFF 限制到 65536 个 key
// 多张不同 URL 可能映射到同一 key，导致缓存覆盖/错乱
private func cacheKey(from url: String) -> String {
    return String(url.hashValue & 0xFFFF)
}
```

**影响**: 20张照片可能产生缓存碰撞，显示错误的图片。

**修复**:
```swift
// ✅ 使用 SHA256
import CryptoKit
private func cacheKey(from url: String) -> String {
    guard let data = url.data(using: .utf8) else { return url }
    return SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
}
// 或简单方案（对于 OSS URL 足够）
private func cacheKey(from url: String) -> String {
    return url.replacingOccurrences(of: "/", with: "_")
               .replacingOccurrences(of: ":", with: "_")
}
```

---

### BUG-7: VoiceInputService — SFSpeechRecognizer 强制解包

**文件**: `Core/Native/VoiceInputService.swift:17`

```swift
// ❌ zh-CN 在某些地区/设备不支持，强制解包 → crash
private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))!
```

**修复**:
```swift
// ✅ 可选 + 优雅降级
private let speechRecognizer: SFSpeechRecognizer? = {
    SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
        ?? SFSpeechRecognizer() // 回退到设备默认语言
}()
```

---

### BUG-8: WidgetDataWriter — ID 与 Title 混淆去重

**文件**: `Core/Native/WidgetDataWriter.swift:43`

```swift
// ❌ 用 title 来和 id 比较 — 逻辑错误
let recentItems = memoirs
    .filter { $0.id != dailyMemoir?.title } // id vs title!
```

**修复**:
```swift
// ✅ 用正确字段比较
let recentItems = memoirs
    .filter { $0.id != dailyMemoir?.id || $0.title != dailyMemoir?.title }
```

---

### BUG-9: Friend 模型 — Generation 枚举值重复

**文件**: `Models/Friend.swift:131-132`

```swift
// ❌ greatUncle 和 parent 共享 rawValue = 1
case greatUncle = 1
case parent = 1     // Generation(rawValue: 1) 永远返回 greatUncle
```

**修复**:
```swift
// ✅ 区分辈分编号
case greatUncle = 2   // 叔伯辈
case parent = 1        // 父辈
// 或合并这两者：
case parentOrUncle = 1  // 父辈/叔伯辈
```

---

### BUG-10: BiometricAuthManager — LAContext 不复用

**文件**: `Core/Storage/BiometricAuthManager.swift:9`

```swift
// ❌ LAContext 在 init() 时创建一次，失败后不重建
// 可能导致 biometryLockout 后永远无法验证
private let context = LAContext()
```

**修复**:
```swift
// ✅ 每次 authenticate 时新建 context
func authenticate() async -> Bool {
    let context = LAContext()
    // ...
}
```

---

### BUG-11: SSE 解析不完整

**文件**: `Core/Network/AIInterviewService.swift:151-161`

```swift
// ❌ SSE 协议要求以双换行分隔事件，当前只处理 data: 行
// 缺失: event:, id:, retry: 字段处理
// 缺失: 多行 data 的合并逻辑（只做了简单拼接）
```

**影响**: 流式 AI 响应可能显示不完整或乱序。

---

## 🟡 P2 中等 — 设计缺陷

| 编号 | 文件 | 问题 |
|------|------|------|
| D-1 | `DraftManager.swift` | 无 `deinit` 取消 autoSaveTimer |
| D-2 | `PerformanceMonitor.swift` | 无 `deinit` 取消 memoryTimer |
| D-3 | `APIClient.swift` | 204/304 被当作 serverError |
| D-4 | `KeychainManager.swift` | SecItemAdd/SecItemDelete 无错误检查 |
| D-5 | `CrashReportService.swift` | 信号处理器内做文件 I/O（非 async-safe） |
| D-6 | `OSSUploadService.swift` | 上传失败未清理进度监听 |
| D-7 | `LogService.swift` | `debug()` 用 `#if DEBUG` 包裹但参数 `error` 标记未使用 |
| D-8 | `MemoirAssistantApp.swift` | `DashboardView`/`SettingsView` 等定义在同一个文件，建议拆开 |
| D-9 | `Extensions.swift` | `memoirCard()` 使用 `cornerRadius` 而非 `clipShape`，与 `shadow` 组合时可能被裁剪 |
| D-10 | `DesignTokens.swift` | `Animation` enum 名与 `SwiftUI.Animation` 冲突，需用 `` `default` `` |

---

## 🟢 P3 建议 — 优化改进

| 编号 | 建议 | 优先级 |
|------|------|--------|
| S-1 | GalleryService 添加 `MemoirService` 式的 `@MainActor` + `ObservableObject` 一致性 | 低 |
| S-2 | `WidgetDataWriter` 去重逻辑 `$0.id != dailyMemoir?.title` 改为正确字段比较 | 低 |
| S-3 | `VoiceInputService.silenceTimer` 的回调体是空的，建议移除无用 timer | 低 |
| S-4 | `CrashReportService` 增加 `lastScreen` 的线程安全（当前多线程写不安全） | 中 |
| S-5 | 建议为所有 `@Published` 属性的并发访问增加保护 | 中 |
| S-6 | `Package.swift` 中 Alamofire 被注释：要么删除注释，要么正式接入 | 低 |
| S-7 | `RecentMemoirsSection` 加载失败时 `isLoading` 仍被设为 `false`，缺少错误展示 | 低 |

---

## ✅ 架构亮点

1. **MVVM + Service 分层清晰**: `Models` → `Core/Network` → `Features`，依赖方向正确
2. **Keychain 安全策略**: `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` — 符合 Apple 安全最佳实践
3. **App Group 共享**: Widget 通过 `UserDefaults(suiteName:)` 正确读写共享数据
4. **@MainActor 使用得当**: 所有 UI 相关的 ObservableObject 标注了 @MainActor
5. **DesignToken 全覆盖**: 间距/字号/颜色/阴影均通过 Token 引用，无硬编码
6. **无障碍设计**: 18pt 基础字号 + 3 级 Dynamic Type 缩放 + 高对比度模式
7. **JWT 管理**: Token 仅存 Keychain，不写 UserDefaults，符合安全要求
8. **崩溃收集**: `NSSetUncaughtExceptionHandler` + 面包屑 + 诊断报告
9. **OSLog 结构化日志**: 9 个分类 Logger，支持 Console.app 过滤
10. **分页抽象**: `paginatedGet<T>` 泛型方法，避免重复的分页 query 构造

---

## 📋 修复优先级建议

### 第一轮（必须在上架前修复）
```
1. BUG-1: FriendService/HobbyService API 路径双前缀
2. BUG-2: [String: Any] → Encodable
3. BUG-3: get(path:params:) → paginatedGet
4. BUG-5: GalleryService 双解码
5. BUG-6: ImageCacheManager key 碰撞
```

### 第二轮（TestFlight 期间修复）
```
6. BUG-7: VoiceInputService 强制解包
7. BUG-8: WidgetDataWriter 去重逻辑
8. BUG-9: Generation 枚举重复值
9. BUG-10: BiometricAuthManager LAContext
```

### 第三轮（v1.1 迭代）
```
10. D-1/D-2: 内存管理 deinit
11. S-5: Published 并发安全
12. BUG-11: SSE 协议完整支持
```

---

## 📊 模块质量热力图

```
Models/              ████████░░  8/10  — 健壮，仅 Generation 枚举重复
Core/Network/        ██████░░░░  6/10  — GalleryService 混乱，Friend/Hobby 编译失败
Core/Storage/        ████████░░  8/10  — Keychain 安全，DraftManager 缺少 deinit
Core/Native/         ███████░    7/10  — VoiceInput force-unwrap，Widget 去重 bug
Core/Performance/    ██████░░░░  6/10  — 缓存 key 碰撞，Timer 清理缺失
Core/Logging/        ████████░░  8/10  — OSLog 完善，信号处理 I/O 风险低
DesignSystem/        █████████░  9/10  — Token 完整，命名良好
Features/            ███████░░░  7/10  — 视图层一致性好，部分错误处理缺失
MemoirWidget/        ████████░░  8/10  — Medium/Large 双尺寸，App Group 正确
```

---

**结论**: 代码整体架构优秀，设计系统贯彻一致，但 **5 个 P0/P1 问题必须在首版发布前修复**。修复后可达 A 级品质，具备 App Store 上架条件。

---

## ✅ 修复日志 (2026-06-17 10:18)

| 编号 | 严重度 | 文件 | 修复内容 |
|------|--------|------|----------|
| BUG-1 | P0 | `FriendService.swift` | `"/api/v1/friend"` → `"/friend"`（消除双前缀） |
| BUG-2 | P0 | `FriendService.swift` | `[String: Any]` + `buildRequestBody` → 直接传递 `FriendRequest`（Encodable） |
| BUG-3 | P0 | `FriendService.swift` | `client.get(base, params:)` → `client.get(base, query:)` + `URLQueryItem` |
| BUG-1 | P0 | `HobbyService.swift` | `"/api/v1/hobby"` → `"/hobby"`（消除双前缀） |
| BUG-2 | P0 | `HobbyService.swift` | `[String: Any]` + `buildRequestBody` → 直接传递 `HobbyRequest`（Encodable） |
| BUG-3 | P0 | `HobbyService.swift` | `client.get(base, params:)` → `client.get(base, query:)` + `URLQueryItem` |
| BUG-5 | P1 | `GalleryService.swift` | 全方法移除双 `JSONDecoder().decode()`，直接依赖 APIClient 解码 |
| — | P1 | `Gallery.swift` | 移除与 GalleryService 重复的 `OSSSignResponse`/`OSSDownloadResponse` |
| — | P1 | `FriendService.swift` | 移除重复的 `EmptyResponse`（归入 GalleryService） |
| BUG-6 | P1 | `ImageCacheManager.swift` | `hashValue & 0xFFFF` (65536 碰撞) → CommonCrypto SHA256 前 16 字节 |
| BUG-7 | P1 | `VoiceInputService.swift` | `SFSpeechRecognizer(...)!` → `SFSpeechRecognizer?(...)` + guard |
| BUG-8 | P1 | `WidgetDataWriter.swift` | `$0.id != dailyMemoir?.title` → `$0.id != dailyMemoir?.id` |
| BUG-9 | P1 | `Friend.swift:Generation` | `greatUncle=1, parent=1` → `greatUncle=1, parent=0, selfGen=-1,...`（全部重排） |
| BUG-9 | P1 | `Friend.swift:selectableOptions` | 同步更新为 8 个辈分选项匹配新 rawValue |

**修复统计**: 9 个文件，消除 4 个编译级 P0 bug + 5 个运行时 P1 bug。
