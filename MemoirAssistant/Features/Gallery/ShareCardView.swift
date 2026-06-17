import SwiftUI

// MARK: - 分享卡片生成与展示

struct ShareCardView: View {
    let image: UIImage

    @Environment(\.dismiss) private var dismiss
    @State private var showSystemShare = false

    var body: some View {
        NavigationStack {
            VStack(spacing: DesignTokens.Spacing.lg) {
                Spacer()

                // 预览卡片
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(radius: 10)
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.vertical, DesignTokens.Spacing.sm)

                Text("分享这张照片给你的亲友")
                    .font(.system(size: DesignTokens.Typography.body))
                    .foregroundColor(MemoirColors.textSecondary)

                // 分享按钮
                Button {
                    showSystemShare = true
                } label: {
                    Label("分享", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                }
                .buttonStyle(.primaryLarge)
                .padding(.horizontal, DesignTokens.Spacing.xl)

                // 保存到相册
                Button {
                    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                } label: {
                    Label("保存到相册", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .font(.system(size: DesignTokens.Typography.body))
                }
                .buttonStyle(.bordered)
                .tint(MemoirColors.primary)
                .padding(.horizontal, DesignTokens.Spacing.xl)

                Spacer()
            }
            .background(MemoirColors.background)
            .navigationTitle("分享")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .sheet(isPresented: $showSystemShare) {
                ActivityViewController(activityItems: [image])
                    .presentationDetents([.medium, .large])
            }
        }
    }
}

// MARK: - 分享卡片内容（用于 ImageRenderer 渲染）

struct ShareCardContent: View {
    let imageUrl: String?
    let caption: String
    let date: String?

    var body: some View {
        ZStack {
            // 背景 — 仿泛黄纸张
            LinearGradient(
                colors: [
                    Color(red: 0.976, green: 0.953, blue: 0.898),
                    Color(red: 0.965, green: 0.937, blue: 0.875),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 0) {
                // 顶部装饰
                VStack(spacing: 4) {
                    Text("忆往昔 / Memoir")
                        .font(.system(size: 14, weight: .medium, design: .serif))
                        .foregroundColor(Color(red: 0.55, green: 0.4, blue: 0.25))
                    Rectangle()
                        .fill(Color(red: 0.65, green: 0.5, blue: 0.35).opacity(0.3))
                        .frame(height: 1)
                        .padding(.horizontal, 40)
                }
                .padding(.top, 24)

                // 图片区域
                if let url = imageUrl, let imageUrl = URL(string: url) {
                    AsyncImage(url: imageUrl) { phase in
                        switch phase {
                        case .success(let img):
                            img
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                        default:
                            photoPlaceholder
                        }
                    }
                } else {
                    photoPlaceholder
                }

                // 说明文字
                if !caption.isEmpty {
                    Text(caption)
                        .font(.system(size: 20, weight: .medium, design: .serif))
                        .foregroundColor(Color(red: 0.25, green: 0.18, blue: 0.1))
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 8)
                }

                // 日期
                if let date = date {
                    Text(formattedDate(date))
                        .font(.system(size: 14, design: .serif))
                        .foregroundColor(Color(red: 0.5, green: 0.35, blue: 0.22))
                        .padding(.bottom, 12)
                }

                // 底部水印
                VStack(spacing: 4) {
                    Rectangle()
                        .fill(Color(red: 0.65, green: 0.5, blue: 0.35).opacity(0.3))
                        .frame(height: 1)
                        .padding(.horizontal, 40)
                    Text("来自「忆往昔」— AI 回忆录助手")
                        .font(.system(size: 11, design: .serif))
                        .foregroundColor(Color(red: 0.55, green: 0.4, blue: 0.25).opacity(0.7))
                }
                .padding(.bottom, 20)
            }
        }
        .frame(width: 390, height: 520)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            // 照片边框
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 0.7, green: 0.55, blue: 0.35).opacity(0.6),
                            Color(red: 0.6, green: 0.45, blue: 0.3).opacity(0.3),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        }
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    }

    private var photoPlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(red: 0.85, green: 0.8, blue: 0.7).opacity(0.5))
            .frame(height: 200)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .overlay {
                Image(systemName: "photo")
                    .font(.system(size: 40))
                    .foregroundColor(Color(red: 0.6, green: 0.5, blue: 0.35).opacity(0.6))
            }
    }

    private func formattedDate(_ iso: String) -> String {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fmt.date(from: iso) {
            let df = DateFormatter()
            df.dateFormat = "yyyy 年 M 月 d 日"
            return df.string(from: date)
        }
        let simple = ISO8601DateFormatter()
        if let d = simple.date(from: iso) {
            let df = DateFormatter()
            df.dateFormat = "yyyy 年 M 月 d 日"
            return df.string(from: d)
        }
        return String(iso.prefix(10))
    }
}

// MARK: - UIActivityViewController 桥接

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    ShareCardView(image: UIImage(systemName: "photo")!)
}
