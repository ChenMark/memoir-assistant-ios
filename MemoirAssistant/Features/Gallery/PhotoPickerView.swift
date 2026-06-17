import SwiftUI
import PhotosUI
import UIKit

// MARK: - 照片选择器（相册 + 相机）

struct PhotoPickerView: View {
    let onUploadComplete: (GalleryPhoto) -> Void

    @Environment(\.dismiss) private var dismiss

    // 相册选择
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []

    // 相机
    @State private var showCamera = false
    @State private var capturedImage: UIImage?

    // 上传状态
    @State private var caption = ""
    @State private var tagsText = ""
    @State private var selectedDate = Date()
    @State private var useCustomDate = false
    @State private var selectedMemoirId: String?

    @State private var isUploading = false
    @State private var uploadProgress: Double = 0
    @State private var uploadError: String?
    @State private var uploadedCount = 0
    @State private var totalCount = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    if !selectedImages.isEmpty {
                        previewSection
                        detailForm
                    } else {
                        sourceSelection
                    }
                }
                .padding(DesignTokens.Spacing.lg)
            }
            .background(MemoirColors.background)
            .navigationTitle("添加照片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !selectedImages.isEmpty {
                        Button("上传") {
                            Task { await startUpload() }
                        }
                        .font(.system(size: DesignTokens.Typography.body, weight: .semibold))
                        .disabled(isUploading || selectedImages.isEmpty)
                    }
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraPickerView(image: $capturedImage)
            }
            .onChange(of: capturedImage) { _, newImage in
                if let img = newImage {
                    selectedImages.append(img)
                    capturedImage = nil
                }
            }
            .overlay {
                if isUploading {
                    uploadOverlay
                }
            }
        }
    }

    // MARK: - 来源选择

    private var sourceSelection: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            Spacer().frame(height: 40)

            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundColor(MemoirColors.textTertiary.opacity(0.5))

            Text("选择照片来源")
                .font(.system(size: DesignTokens.Typography.title2, weight: .semibold))
                .foregroundColor(MemoirColors.textPrimary)

            VStack(spacing: DesignTokens.Spacing.md) {
                // 相册
                PhotosPicker(
                    selection: $selectedItems,
                    maxSelectionCount: 9,
                    matching: .images
                ) {
                    sourceButton(icon: "photo.stack.fill", title: "从相册选择", color: MemoirColors.primary)
                }
                .onChange(of: selectedItems) { _, _ in
                    loadSelectedImages()
                }

                // 相机
                Button {
                    showCamera = true
                } label: {
                    sourceButton(icon: "camera.fill", title: "拍照", color: Color(red: 0.3, green: 0.6, blue: 0.4))
                }

                // 最近回忆录关联
                NavigationLink {
                    MemoirPickerView(selectedMemoirId: $selectedMemoirId)
                } label: {
                    sourceButton(
                        icon: "book.fill",
                        title: selectedMemoirId == nil ? "关联回忆录（可选）" : "已关联回忆录",
                        color: Color(red: 0.6, green: 0.36, blue: 0.1)
                    )
                }
            }
        }
    }

    private func sourceButton(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(title)
                .font(.system(size: DesignTokens.Typography.body, weight: .medium))
                .foregroundColor(MemoirColors.textPrimary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(MemoirColors.textTertiary)
        }
        .padding(DesignTokens.Spacing.md)
        .background(MemoirColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - 预览区域

    private var previewSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(selectedImages.indices, id: \.self) { index in
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: selectedImages[index])
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        Button {
                            selectedImages.remove(at: index)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                        .offset(x: 6, y: -6)
                    }
                }

                // 继续添加按钮
                PhotosPicker(
                    selection: $selectedItems,
                    maxSelectionCount: 9 - selectedImages.count,
                    matching: .images
                ) {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(MemoirColors.textTertiary.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 100, height: 100)
                        .overlay {
                            Image(systemName: "plus")
                                .font(.title2)
                                .foregroundColor(MemoirColors.textTertiary)
                        }
                }
                .onChange(of: selectedItems) { _, _ in
                    loadSelectedImages()
                }
            }
            .padding(.bottom, 4)
        }
    }

    // MARK: - 详情表单

    private var detailForm: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            // 说明
            VStack(alignment: .leading, spacing: 6) {
                Text("照片说明")
                    .font(.system(size: DesignTokens.Typography.bodySmall, weight: .medium))
                    .foregroundColor(MemoirColors.textSecondary)
                TextField("记录这个瞬间...", text: $caption, axis: .vertical)
                    .font(.system(size: DesignTokens.Typography.body))
                    .lineLimit(2...5)
                    .padding(12)
                    .background(MemoirColors.background)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(MemoirColors.textTertiary.opacity(0.2))
                    }
            }

            // 标签
            VStack(alignment: .leading, spacing: 6) {
                Text("标签（用逗号分隔）")
                    .font(.system(size: DesignTokens.Typography.bodySmall, weight: .medium))
                    .foregroundColor(MemoirColors.textSecondary)
                TextField("家庭, 聚会, 旅行...", text: $tagsText)
                    .font(.system(size: DesignTokens.Typography.body))
                    .padding(12)
                    .background(MemoirColors.background)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(MemoirColors.textTertiary.opacity(0.2))
                    }
            }

            // 自定义日期
            Toggle("自定义拍摄日期", isOn: $useCustomDate)
                .font(.system(size: DesignTokens.Typography.bodySmall, weight: .medium))
                .foregroundColor(MemoirColors.textSecondary)

            if useCustomDate {
                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .frame(maxHeight: 100)
            }

            // 照片数量提示
            HStack {
                Image(systemName: "photo.stack")
                    .font(.caption)
                    .foregroundColor(MemoirColors.textTertiary)
                Text("已选择 \(selectedImages.count) 张照片")
                    .font(.system(size: DesignTokens.Typography.caption))
                    .foregroundColor(MemoirColors.textTertiary)
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .background(MemoirColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - 上传遮罩

    private var uploadOverlay: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()

            VStack(spacing: DesignTokens.Spacing.lg) {
                ProgressView(value: uploadProgress) {
                    Text("上传中... (\(uploadedCount)/\(totalCount))")
                        .font(.system(size: DesignTokens.Typography.body, weight: .medium))
                        .foregroundColor(.white)
                }
                .progressViewStyle(.linear)
                .frame(width: 250)

                Text("\(Int(uploadProgress * 100))%")
                    .font(.system(size: DesignTokens.Typography.title, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
            .padding(DesignTokens.Spacing.xl)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }

    // MARK: - 方法

    private func loadSelectedImages() {
        guard !selectedItems.isEmpty else { return }

        Task {
            var images: [UIImage] = []
            for item in selectedItems {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    images.append(img)
                }
            }
            await MainActor.run {
                selectedImages.append(contentsOf: images)
                selectedItems = []
            }
        }
    }

    private func startUpload() async {
        isUploading = true
        uploadProgress = 0
        uploadedCount = 0
        totalCount = selectedImages.count

        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        for (index, image) in selectedImages.enumerated() {
            do {
                let photo = try await OSSUploadService.shared.upload(
                    image: image,
                    caption: index == 0 ? caption : "",
                    tags: tags,
                    date: useCustomDate ? selectedDate : nil,
                    memoirId: selectedMemoirId,
                    progress: { fraction in
                        let perItem = 1.0 / Double(totalCount)
                        uploadProgress = (Double(index) + fraction) * perItem
                    }
                )
                uploadedCount += 1
                onUploadComplete(photo)
            } catch {
                uploadError = error.localizedDescription
            }
        }

        isUploading = false
        dismiss()
    }
}

// MARK: - 回忆录选择器

struct MemoirPickerView: View {
    @Binding var selectedMemoirId: String?
    @Environment(\.dismiss) private var dismiss
    @State private var memoirs: [Memoir] = []
    @State private var isLoading = true

    var body: some View {
        List {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }

            // 不关联选项
            Section {
                Button {
                    selectedMemoirId = nil
                    dismiss()
                } label: {
                    HStack {
                        Text("不关联")
                            .foregroundColor(MemoirColors.textSecondary)
                        Spacer()
                        if selectedMemoirId == nil {
                            Image(systemName: "checkmark")
                                .foregroundColor(MemoirColors.primary)
                        }
                    }
                }
            }

            // 最近回忆录
            Section("最近回忆录") {
                ForEach(memoirs) { memoir in
                    Button {
                        selectedMemoirId = memoir.id
                        dismiss()
                    } label: {
                        HStack {
                            Text(memoir.title)
                                .foregroundColor(MemoirColors.textPrimary)
                                .lineLimit(1)
                            Spacer()
                            if selectedMemoirId == memoir.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(MemoirColors.primary)
                            }
                            Text(memoir.date)
                                .font(.system(size: DesignTokens.Typography.caption))
                                .foregroundColor(MemoirColors.textTertiary)
                        }
                    }
                }
            }
        }
        .navigationTitle("关联回忆录")
        .task {
            do {
                let resp = try await MemoirService.shared.fetchMemoirs(page: 1, limit: 50)
                memoirs = resp.data
            } catch {}
            isLoading = false
        }
    }
}

// MARK: - 相机选择器（UIKit 桥接）

struct CameraPickerView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPickerView

        init(_ parent: CameraPickerView) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Preview

#Preview {
    PhotoPickerView { _ in }
}
