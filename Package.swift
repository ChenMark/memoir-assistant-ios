// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MemoirAssistant",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "MemoirAssistant",
            targets: ["MemoirAssistant"]),
    ],
    dependencies: [
        // 网络层 — Alamofire 替代方案使用原生 URLSession
        // 图片加载 — 使用 AsyncImage（iOS 15+ 内置）
        // 数据库 — Core Data（iOS 原生）
    ],
    targets: [
        .target(
            name: "MemoirAssistant",
            path: "MemoirAssistant",
            exclude: ["Resources/Info.plist"]
        ),
    ]
)
