import SwiftUI

// MARK: - 画廊瀑布流主视图

struct GalleryView: View {
    @State private var photos: [GalleryPhoto] = []
    @State private var isLoading = true
    @State private var isRefreshing = false
    @State private var currentPage = 1
    @State private var hasMore = true
    @State private var errorMessage: String?

    @State private var showPhotoPicker = false
    @State private var selectedPhoto: GalleryPhoto?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                MemoirColors.background.ignoresSafeArea()

                if isLoading && photos.isEmpty {
                    ProgressView("加载中...")
                        .foregroundColor(MemoirColors.textSecondary)
                } else if let error = errorMessage, photos.isEmpty {
                    errorView(error)
                } else if photos.isEmpty {
                    emptyView
                } else {
                    photoGrid
                }
            }
            .navigationTitle("画廊")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showPhotoPicker = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(MemoirColors.primary)
                    }
                }
            }
            .sheet(isPresented: $showPhotoPicker) {
                PhotoPickerView(onUploadComplete: { photo in
                    photos.insert(photo, at: 0)
                })
            }
            .sheet(item: $selectedPhoto) { photo in
                GalleryDetailView(photo: photo)
            }
            .task { await loadInitial() }
        }
    }

    // MARK: - 照片瀑布流

    private var photoGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(photos) { photo in
                    photoCard(photo)
                        .onAppear {
                            if photo.id == photos.last?.id, hasMore {
                                Task { await loadMore() }
                            }
                        }
                }

                if isLoading && !photos.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding()
                }
            }
            .padding(12)
            .refreshable { await refresh() }
        }
    }

    private func photoCard(_ photo: GalleryPhoto) -> some View {
        Button {
            selectedPhoto = photo
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                // 图片
                AsyncGalleryImage(
                    photo: photo,
                    height: CGFloat.random(in: 140...240)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // 说明
                if !photo.caption.isEmpty {
                    Text(photo.caption)
                        .font(.system(size: DesignTokens.Typography.caption))
                        .foregroundColor(MemoirColors.textSecondary)
                        .lineLimit(2)
                        .padding(.horizontal, 4)
                        .padding(.bottom, 6)
                }

                // 日期
                if let date = photo.date {
                    Text(formatDate(date))
                        .font(.system(size: 11))
                        .foregroundColor(MemoirColors.textTertiary)
                        .padding(.horizontal, 4)
                        .padding(.bottom, 4)
                }
            }
            .background(MemoirColors.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(
                color: DesignTokens.Shadow.card.color,
                radius: DesignTokens.Shadow.card.radius,
                y: DesignTokens.Shadow.card.y
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 空状态

    private var emptyView: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundColor(MemoirColors.textTertiary.opacity(0.5))

            Text("还没有照片")
                .font(.system(size: DesignTokens.Typography.title2, weight: .semibold))
                .foregroundColor(MemoirColors.textSecondary)

            Text("点击右上角 + 按钮\n拍摄或上传你的珍贵瞬间")
                .font(.system(size: DesignTokens.Typography.body))
                .foregroundColor(MemoirColors.textTertiary)
                .multilineTextAlignment(.center)

            Button {
                showPhotoPicker = true
            } label: {
                Label("添加照片", systemImage: "plus.circle.fill")
                    .frame(maxWidth: 200)
                    .frame(height: 48)
            }
            .buttonStyle(.primaryLarge)
        }
        .padding()
    }

    // MARK: - 错误视图

    private func errorView(_ message: String) -> some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(MemoirColors.textTertiary.opacity(0.4))

            Text(message)
                .font(.system(size: DesignTokens.Typography.body))
                .foregroundColor(MemoirColors.textSecondary)
                .multilineTextAlignment(.center)

            Button("重试") {
                Task { await refresh() }
            }
            .buttonStyle(.primaryLarge)
        }
        .padding()
    }

    // MARK: - 数据加载

    private func loadInitial() async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await GalleryService.shared.fetchGallery(page: 1)
            photos = response.data
            hasMore = response.hasMore
            currentPage = 1
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func loadMore() async {
        guard !isLoading else { return }
        isLoading = true
        do {
            let nextPage = currentPage + 1
            let response = try await GalleryService.shared.fetchGallery(page: nextPage)
            photos.append(contentsOf: response.data)
            hasMore = response.hasMore
            currentPage = nextPage
        } catch {}
        isLoading = false
    }

    private func refresh() async {
        isRefreshing = true
        do {
            let response = try await GalleryService.shared.fetchGallery(page: 1)
            photos = response.data
            hasMore = response.hasMore
            currentPage = 1
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isRefreshing = false
    }

    private func formatDate(_ iso: String) -> String {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fmt.date(from: iso) {
            let display = DateFormatter()
            display.dateFormat = "yyyy/MM/dd"
            return display.string(from: date)
        }

        // try simple format
        let simple = ISO8601DateFormatter()
        if let date = simple.date(from: iso) {
            let display = DateFormatter()
            display.dateFormat = "yyyy/MM/dd"
            return display.string(from: date)
        }
        return String(iso.prefix(10))
    }
}

// MARK: - 异步图片加载组件

struct AsyncGalleryImage: View {
    let photo: GalleryPhoto
    let height: CGFloat

    @State private var image: UIImage?
    @State private var isLoading = true

    var body: some View {
        ZStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: height)
                    .clipped()
            } else {
                Rectangle()
                    .fill(MemoirColors.textTertiary.opacity(0.1))
                    .frame(height: height)
                    .overlay {
                        if isLoading {
                            ProgressView()
                        } else {
                            Image(systemName: "photo")
                                .foregroundColor(MemoirColors.textTertiary.opacity(0.4))
                        }
                    }
            }
        }
        .task(id: photo.id) { await loadImage() }
    }

    private func loadImage() async {
        // 优先使用 downloadUrl，否则用 OSS Key 获取签名 URL
        let urlString: String
        if let downloadUrl = photo.downloadUrl, !downloadUrl.isEmpty {
            urlString = downloadUrl
        } else {
            do {
                urlString = try await GalleryService.shared.getOSSDownloadUrl(key: photo.ossKey)
            } catch {
                await MainActor.run { isLoading = false }
                return
            }
        }

        // 使用全局缓存管理器
        if let cached = await ImageCacheManager.shared.loadImage(from: urlString) {
            await MainActor.run {
                image = cached
                isLoading = false
            }
            return
        }

        await MainActor.run { isLoading = false }
    }
}

// MARK: - Preview

#Preview {
    GalleryView()
}
