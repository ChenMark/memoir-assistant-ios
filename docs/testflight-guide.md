# 忆往昔 · TestFlight 内测发布指南

> **版本**: 1.6.0 (Build 1)  
> **准备日期**: 2026-06-17  
> **分发方式**: TestFlight 内部测试 + 公开链接

---

## 一、发布前检查清单

### 1.1 代码与构建

- [x] 代码版本: `1.6.0 (M7)`
- [x] 所有功能模块已完成 (M1-M7)
- [x] 性能优化已实施（全局图片缓存/HTTP缓存/重试/启动监控）
- [x] UI 走查通过（拟物化一致性 100% / Dynamic Type 适配 / 暗黑模式）
- [ ] Xcode Archive 构建成功（需在 macOS + Xcode 16+ 执行）
- [ ] 无编译警告
- [ ] SwiftLint 检查通过

### 1.2 证书与配置

- [ ] Apple Developer 账号已激活 ($99/年)
- [ ] Bundle Identifier 已注册: `com.memoir.assistant.ios`
- [ ] 开发证书 + 发布证书已创建
- [ ] App ID 已配置 Capabilities:
  - Push Notifications (如需)
  - Siri (Intents Extension)
  - App Groups (Widget 共享数据)

### 1.3 App Store Connect 配置

- [ ] App 已在 App Store Connect 创建
- [ ] App 信息已填写（名称、类别、年龄分级）
- [ ] 隐私政策 URL 已设置
- [ ] 截图已上传（见下方截图规格）
- [ ] 审核备注已准备

---

## 二、构建与上传

### 2.1 Archive 命令

```bash
# 清理构建
xcodebuild clean -workspace MemoirAssistant.xcworkspace -scheme MemoirAssistant

# Archive
xcodebuild archive \
  -workspace MemoirAssistant.xcworkspace \
  -scheme MemoirAssistant \
  -archivePath ./build/MemoirAssistant.xcarchive \
  -destination "generic/platform=iOS" \
  CODE_SIGN_STYLE=Manual

# 导出 IPA (App Store)
xcodebuild -exportArchive \
  -archivePath ./build/MemoirAssistant.xcarchive \
  -exportPath ./build/ \
  -exportOptionsPlist ExportOptions.plist
```

### 2.2 ExportOptions.plist

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "...">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>manageAppVersionAndBuildNumber</key>
    <true/>
</dict>
</plist>
```

### 2.3 上传到 App Store Connect

```bash
# 使用 altool 上传
xcrun altool --upload-app \
  -f ./build/MemoirAssistant.ipa \
  -t ios \
  --apiKey YOUR_API_KEY_ID \
  --apiIssuer YOUR_ISSUER_ID

# 或使用 Xcode Organizer → Distribute App → App Store Connect
```

---

## 三、TestFlight 配置

### 3.1 内部测试组

| 配置项 | 值 |
|--------|-----|
| 测试组名称 | 忆往昔内测组 |
| 测试人数 | 20-25 人 |
| 测试类型 | 内部测试 (无需审核) |
| 构建版本 | 1.6.0 (Build 1) |
| 测试期限 | 7-14 天 |

### 3.2 测试者邀请

1. 登录 App Store Connect → My Apps → 忆往昔 → TestFlight
2. 创建 "内部测试组"
3. 添加测试者（Apple ID 邮箱）
4. 选择构建版本 → 开始测试
5. 测试者将收到邮件通知

### 3.3 中老年用户测试群（推荐）

| 年龄段 | 人数 | 测试重点 |
|--------|------|----------|
| 50-59 岁 | 5 人 | 功能完备性、AI 访谈体验 |
| 60-69 岁 | 5 人 | 字号舒适度、操作引导 |
| 70-80 岁 | 3 人 | 大字号模式、语音输入 |

---

## 四、隐私政策

### 4.1 隐私政策URL

部署于 `https://memoir-assistant.vercel.app/privacy`（或 GitHub Pages）

### 4.2 隐私标签（App Store）

| 数据类型 | 用途 | 关联用户 |
|----------|------|----------|
| **联系信息** | | |
| 姓名 | App 功能 | ✅ |
| 邮箱地址 | App 功能 | ✅ |
| 手机号码 | App 功能 | ✅ |
| **用户内容** | | |
| 照片/视频 | App 功能 | ✅ |
| 音频数据 | App 功能 | ✅ |
| **标识符** | | |
| 用户ID | App 功能、分析 | ✅ |
| **诊断** | | |
| 崩溃数据 | App 功能 | ❌ |

---

## 五、截图规格

### 5.1 必需尺寸

| 设备 | 尺寸 | 数量 |
|------|------|------|
| iPhone 6.7" (Pro Max) | 1290 × 2796 | 5-8 张 |
| iPhone 6.5" (Pro/Plus) | 1242 × 2688 | 5-8 张 |
| iPhone 5.5" (SE) | 1242 × 2208 | 5-8 张 |

### 5.2 截图场景建议

1. **首页仪表盘** — 展示温暖欢迎界面
2. **回忆录列表** — 时间线 + 卡片
3. **AI 访谈** — 对话界面
4. **画廊瀑布流** — 照片浏览
5. **家族树** — 可视化展示
6. **语音输入** — 中老年友好的大按钮
7. **大字号模式** — 适老化对比
8. **Widget** — 桌面小组件

---

## 六、审核备注模板

```
# App Review Notes

## 测试账号
- 用户名: test@memoir-assistant.com
- 密码: TestFlight2026!
- 手机号: 13800138000 (如需短信登录)

## 核心功能
本 App 面向中老年用户，核心功能包括：
1. AI 辅助回忆录撰写（语音输入 + AI 访谈）
2. 照片画廊（拍照上传 + 瀑布流浏览）
3. 家族树可视化
4. 大字号无障碍模式

## 演示视频
(如有) 链接: https://...

## 特别说明
- Siri Shortcuts 需要在真实设备上测试
- Widget 功能仅 iOS 17+
- 部分功能依赖后端 API，请确保网络连接正常
```

---

## 七、内测反馈收集

### 7.1 反馈表单

建议使用问卷星/腾讯问卷收集：

1. **功能性**: AI 访谈是否流畅？语音识别准确率如何？
2. **易用性**: 字号是否舒适？按钮是否够大？
3. **稳定性**: 是否有闪退？加载速度如何？
4. **整体评价**: 1-5 分打分 + 文字建议

### 7.2 崩溃收集

TestFlight 自动收集崩溃报告，可在 App Store Connect → Crashes 查看。

---

*准备完毕，可以开始 TestFlight 上传流程。*
