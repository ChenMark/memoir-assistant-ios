import SwiftUI

// MARK: - 照片详情 + 评论互动

struct GalleryDetailView: View {
    let photo: GalleryPhoto

    @Environment(\.dismiss) private var dismiss
    @State private var downloadUrl: String?
    @State private var comments: [PhotoComment] = []
    @State private var commentText = ""
    @State private var isLoadingComments = true
    @State private var isSubmittingComment = false
    @State private var showShareSheet = false
    @State private var showDeleteAlert = false
    @State private var shareCardImage: UIImage?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 大图区域
                ScrollView {
                    VStack(spacing: 0) {
                        // 图片
                        fullImageView

                        // 拍摄信息
                        infoSection

                        // 标签
                        if !photo.tags.isEmpty {
                            tagsRow
                        }

                        Divider()
                            .padding(.horizontal, DesignTokens.Spacing.lg)

                        // 评论区域
                        commentsSection
                    }
                }

                // 底部评论输入栏
                commentInputBar
            }
            .background(MemoirColors.background)
            .navigationTitle("照片详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            generateShareCard()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }

                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .alert("删除照片", isPresented: $showDeleteAlert) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    Task {
                        try? await GalleryService.shared.deletePhoto(id: photo.id)
                        dismiss()
                    }
                }
            } message: {
                Text("确定要删除这张照片吗？此操作不可撤销。")
            }
            .sheet(isPresented: $showShareSheet) {
                if let image = shareCardImage {
                    ShareCardView(image: image)
                }
            }
            .task { await loadDetail() }
        }
    }

    // MARK: - 大图

    private var fullImageView: some View {
        Group {
            if let url = downloadUrl, let imageUrl = URL(string: url) {
                AsyncImage(url: imageUrl) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                    case .failure:
                        placeholderImage
                    case .empty:
                        ProgressView()
                            .frame(height: 300)
                    @unknown default:
                        placeholderImage
                    }
                }
            } else {
                placeholderImage
            }
        }
    }

    private var placeholderImage: some View {
        Rectangle()
            .fill(MemoirColors.textTertiary.opacity(0.1))
            .frame(height: 300)
            .overlay {
                Image(systemName: "photo")
                    .font(.system(size: 48))
                    .foregroundColor(MemoirColors.textTertiary.opacity(0.4))
            }
    }

    // MARK: - 信息区域

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            if !photo.caption.isEmpty {
                Text(photo.caption)
                    .font(.system(size: DesignTokens.Typography.title2, weight: .semibold))
                    .foregroundColor(MemoirColors.textPrimary)
            }

            if let date = photo.date {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                    Text(formatDate(date))
                }
                .font(.system(size: DesignTokens.Typography.bodySmall))
                .foregroundColor(MemoirColors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignTokens.Spacing.lg)
    }

    // MARK: - 标签行

    private var tagsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(photo.tags, id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(MemoirColors.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(MemoirColors.primary.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.bottom, DesignTokens.Spacing.md)
        }
    }

    // MARK: - 评论区域

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack {
                Text("评论")
                    .font(.system(size: DesignTokens.Typography.headline, weight: .semibold))
                    .foregroundColor(MemoirColors.textPrimary)
                Spacer()
                if !comments.isEmpty {
                    Text("\(comments.count)")
                        .font(.system(size: DesignTokens.Typography.bodySmall))
                        .foregroundColor(MemoirColors.textTertiary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(MemoirColors.textTertiary.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.top, DesignTokens.Spacing.md)

            if isLoadingComments {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding()
            } else if comments.isEmpty {
                Text("暂无评论，来说点什么吧")
                    .font(.system(size: DesignTokens.Typography.bodySmall))
                    .foregroundColor(MemoirColors.textTertiary)
                    .padding(.horizontal, DesignTokens.Spacing.lg)
            } else {
                VStack(spacing: 0) {
                    ForEach(comments) { comment in
                        CommentRowView(comment: comment, photoId: photo.id) {
                            await deleteComment(comment)
                        }
                    }
                }
            }
        }
    }

    // MARK: - 评论输入栏

    private var commentInputBar: some View {
        HStack(spacing: 12) {
            TextField("添加评论...", text: $commentText, axis: .vertical)
                .font(.system(size: DesignTokens.Typography.body))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(MemoirColors.textTertiary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .lineLimit(1...4)

            Button {
                guard !commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                Task { await submitComment() }
            } label: {
                if isSubmittingComment {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(
                            commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? MemoirColors.textTertiary.opacity(0.4)
                                : MemoirColors.primary
                        )
                }
            }
            .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmittingComment)
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }

    // MARK: - 方法

    private func loadDetail() async {
        // 获取下载 URL
        do {
            downloadUrl = try await GalleryService.shared.getOSSDownloadUrl(key: photo.ossKey)
        } catch {}

        // 获取评论
        isLoadingComments = true
        do {
            let response = try await GalleryService.shared.fetchComments(photoId: photo.id)
            comments = response.data
        } catch {}
        isLoadingComments = false
    }

    private func submitComment() async {
        let text = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isSubmittingComment = true
        do {
            let comment = try await GalleryService.shared.addComment(photoId: photo.id, content: text)
            comments.append(comment)
            commentText = ""
        } catch {}
        isSubmittingComment = false
    }

    private func deleteComment(_ comment: PhotoComment) async {
        do {
            try await GalleryService.shared.deleteComment(commentId: comment.id)
            comments.removeAll { $0.id == comment.id }
        } catch {}
    }

    private func generateShareCard() {
        // 生成分享卡片图片
        let renderer = ImageRenderer(content: ShareCardContent(
            imageUrl: downloadUrl,
            caption: photo.caption,
            date: photo.date
        ))
        renderer.scale = UIScreen.main.scale

        if let image = renderer.uiImage {
            shareCardImage = image
            showShareSheet = true
        }
    }

    private func formatDate(_ iso: String) -> String {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fmt.date(from: iso) {
            let display = DateFormatter()
            display.dateFormat = "yyyy 年 M 月 d 日"
            return display.string(from: date)
        }
        let simple = ISO8601DateFormatter()
        if let date = simple.date(from: iso) {
            let display = DateFormatter()
            display.dateFormat = "yyyy 年 M 月 d 日"
            return display.string(from: date)
        }
        return String(iso.prefix(10))
    }
}

// MARK: - 评论行视图

struct CommentRowView: View {
    let comment: PhotoComment
    let photoId: String
    let onDelete: () async -> Void

    @State private var showDeleteConfirm = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 头像
            AvatarView(
                avatarUrl: comment.user.avatar,
                username: comment.user.username,
                size: 32
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(comment.user.username)
                        .font(.system(size: DesignTokens.Typography.bodySmall, weight: .semibold))
                        .foregroundColor(MemoirColors.textPrimary)
                    Text(timeAgo(comment.createdAt))
                        .font(.system(size: 11))
                        .foregroundColor(MemoirColors.textTertiary)
                }
                Text(comment.content)
                    .font(.system(size: DesignTokens.Typography.body))
                    .foregroundColor(MemoirColors.textSecondary)
            }

            Spacer()

            // 删除按钮
            Button {
                showDeleteConfirm = true
            } label: {
                Image(systemName: "ellipsis")
                    .font(.caption)
                    .foregroundColor(MemoirColors.textTertiary)
            }
            .alert("删除评论", isPresented: $showDeleteConfirm) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    Task { await onDelete() }
                }
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, 10)
        Divider()
            .padding(.leading, 56)
    }

    private func timeAgo(_ iso: String) -> String {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = fmt.date(from: iso) else {
            let simple = ISO8601DateFormatter()
            guard let d = simple.date(from: iso) else { return "" }
            return relativeTime(from: d)
        }
        return relativeTime(from: date)
    }

    private func relativeTime(from date: Date) -> String {
        let diff = Int(Date().timeIntervalSince(date))
        if diff < 60 { return "刚刚" }
        if diff < 3600 { return "\(diff / 60)分钟前" }
        if diff < 86400 { return "\(diff / 3600)小时前" }
        if diff < 604800 { return "\(diff / 86400)天前" }
        let df = DateFormatter()
        df.dateFormat = "MM/dd"
        return df.string(from: date)
    }
}

// MARK: - 头像组件

struct AvatarView: View {
    let avatarUrl: String?
    let username: String
    let size: CGFloat

    var body: some View {
        Group {
            if let url = avatarUrl, let imageUrl = URL(string: url) {
                AsyncImage(url: imageUrl) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().aspectRatio(contentMode: .fill)
                    default:
                        fallbackAvatar
                    }
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
            } else {
                fallbackAvatar
            }
        }
    }

    private var fallbackAvatar: some View {
        ZStack {
            Circle()
                .fill(MemoirColors.primary.opacity(0.2))
                .frame(width: size, height: size)
            Text(String(username.prefix(1)).uppercased())
                .font(.system(size: size * 0.45, weight: .bold))
                .foregroundColor(MemoirColors.primary)
        }
    }
}

// MARK: - Preview

#Preview {
    GalleryDetailView(photo: GalleryPhoto(
        id: "1",
        userId: "u1",
        memoirId: nil,
        ossKey: "test.jpg",
        caption: "周末家庭聚会",
        tags: ["家庭", "聚会"],
        date: "2026-06-17T10:00:00Z",
        createdAt: "2026-06-17T10:00:00Z",
        downloadUrl: nil,
        commentCount: 0
    ))
}
