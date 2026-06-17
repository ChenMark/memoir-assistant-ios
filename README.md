# 忆往昔 iOS 版本

## 项目信息

| 项目 | 详情 |
|------|------|
| **名称** | 忆往昔 (MemoirAssistant) |
| **最低版本** | iOS 17.0+ |
| **语言** | Swift 5.9+ |
| **UI 框架** | SwiftUI |
| **架构** | MVVM + Clean Architecture |
| **依赖管理** | Swift Package Manager |
| **后端** | memoir-assistant v1.1.0 API (`/api/v1/`) |

## 项目结构

```
MemoirAssistant/
├── App/
│   └── MemoirAssistantApp.swift    # 入口 + TabView + 占位页
├── Core/
│   ├── Network/
│   │   ├── APIClient.swift         # HTTP 客户端 (JWT + 分页)
│   │   └── AuthService.swift       # 认证状态管理
│   ├── Storage/
│   │   ├── KeychainManager.swift   # JWT Token 安全存储
│   │   └── UserDefaultsManager.swift # 用户偏好
│   └── Extensions/
│       └── Extensions.swift        # View/Date/String/Color 扩展
├── DesignSystem/
│   ├── Tokens/
│   │   └── DesignTokens.swift      # 设计令牌（间距/字体/颜色）
│   └── Styles/
│       └── PrimaryButtonStyle.swift # 按钮样式
├── Models/
│   ├── User.swift                  # 用户 + 认证模型
│   ├── Memoir.swift                # 回忆录 + 草稿模型
│   ├── Friend.swift                # 好友 + 家族树模型
│   ├── Hobby.swift                 # 爱好模型
│   └── Gallery.swift               # 画廊 + 评论模型
├── Features/                       # (M2-M7 逐步实现)
│   ├── Auth/
│   ├── Memoir/
│   ├── Gallery/
│   ├── Friends/
│   ├── Hobbies/
│   ├── AIInterview/
│   └── Settings/
└── Resources/
    ├── Assets.xcassets/
    ├── Info.plist
    └── Localizations/              # zh-Hans 中文本地化
```

## 快速开始

### 1. 用 Xcode 打开项目

```bash
# 方法 A: 直接打开目录（Xcode 15+ 支持 Swift Package）
open MemoirAssistant/

# 方法 B: 创建 Xcode 项目
# File → New → Project → iOS → App
# 然后将现有文件拖入项目
```

### 2. 配置后端地址

`Core/Network/APIClient.swift`:
```swift
// DEBUG 模式自动连接本地
// RELEASE 模式连接 Vercel 生产环境
```

### 3. 运行

- 选择 iPhone 15 / iOS 17 模拟器
- ⌘+R 运行

## 开发路线图映射

| 里程碑 | 模块 | 状态 |
|--------|------|------|
| M1 | 项目骨架 + 设计系统 + 网络层 | ✅ 已完成 |
| M2 | 登录/注册 + Face ID | 🔜 Features/Auth/ |
| M3 | 回忆录 CRUD + AI 访谈 | 🔜 Features/Memoir/ |
| M4 | 画廊 + 相机上传 | 🔜 Features/Gallery/ |
| M5 | 亲友 + 家族树 | 🔜 Features/Friends/ |
| M6 | 语音输入 + Widget | 🔜 App Extension |
| M7 | 打磨 + TestFlight | 🔜 全模块 |

## 设计原则

- **适老化优先**: 最小字号 18pt，高对比度
- **怀旧写实**: 暖棕/琥珀色调，泛黄纸张背景
- **触觉反馈**: 关键操作配 Haptic Feedback
- **离线优先**: Core Data 本地缓存
- **60fps**: 所有动画保持流畅
