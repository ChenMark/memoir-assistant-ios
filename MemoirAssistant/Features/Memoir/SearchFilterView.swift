import SwiftUI

// MARK: - 搜索与筛选页

struct SearchFilterView: View {
    @StateObject private var viewModel = SearchFilterViewModel()
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        ZStack {
            MemoirColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // 搜索栏
                searchBar

                // 筛选条件
                filterBar

                // 结果列表
                if viewModel.isSearching {
                    searchingView
                } else if viewModel.results.isEmpty && viewModel.hasSearched {
                    noResultsView
                } else {
                    resultsList
                }
            }
        }
        .navigationTitle("搜索")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 搜索栏

    private var searchBar: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(MemoirColors.textTertiary)

                TextField("搜索标题或内容...", text: $viewModel.keyword)
                    .font(.system(size: DesignTokens.Typography.body))
                    .focused($isSearchFocused)
                    .submitLabel(.search)
                    .onSubmit {
                        Task { await viewModel.search() }
                    }

                if !viewModel.keyword.isEmpty {
                    Button {
                        viewModel.keyword = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(MemoirColors.textTertiary)
                    }
                }
            }
            .padding(DesignTokens.Spacing.sm)
            .background(MemoirColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
                    .stroke(MemoirColors.border, lineWidth: 0.5)
            )

            Button("搜索") {
                Task { await viewModel.search() }
            }
            .font(.system(size: DesignTokens.Typography.bodySmall, weight: .medium))
            .foregroundColor(MemoirColors.primary)
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.sm)
    }

    // MARK: - 筛选栏

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                // 日期范围
                DateRangeFilterChip(
                    dateFrom: $viewModel.dateFrom,
                    dateTo: $viewModel.dateTo
                )

                // 心情筛选
                ForEach(Memoir.moodOptions, id: \.value) { option in
                    FilterChip(
                        label: "\(option.emoji) \(option.label)",
                        isSelected: viewModel.selectedMood == option.value
                    ) {
                        viewModel.selectedMood = viewModel.selectedMood == option.value ? nil : option.value
                    }
                }

                // 重置
                if viewModel.hasActiveFilters {
                    Button {
                        viewModel.resetFilters()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 12))
                            Text("重置")
                                .font(.system(size: DesignTokens.Typography.badge))
                        }
                        .foregroundColor(MemoirColors.danger)
                        .padding(.horizontal, DesignTokens.Spacing.sm)
                        .padding(.vertical, 8)
                        .background(MemoirColors.danger.opacity(0.08))
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.bottom, DesignTokens.Spacing.sm)
        }
    }

    // MARK: - 搜索结果列表

    private var resultsList: some View {
        List {
            ForEach(viewModel.results) { memoir in
                NavigationLink(destination: MemoirDetailView(memoirId: memoir.id)) {
                    searchResultRow(memoir)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(MemoirColors.background)
    }

    private func searchResultRow(_ memoir: Memoir) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(memoir.title)
                .font(.system(size: DesignTokens.Typography.body, weight: .medium))
                .foregroundColor(MemoirColors.textPrimary)

            Text(memoir.content)
                .font(.system(size: DesignTokens.Typography.bodySmall))
                .foregroundColor(MemoirColors.textSecondary)
                .lineLimit(2)

            HStack(spacing: DesignTokens.Spacing.sm) {
                Text(memoir.date)
                    .font(.system(size: DesignTokens.Typography.caption))
                    .foregroundColor(MemoirColors.textTertiary)

                if let mood = memoir.mood,
                   let option = Memoir.moodOptions.first(where: { $0.value == mood }) {
                    Text(option.emoji)
                        .font(.system(size: DesignTokens.Typography.caption))
                }

                ForEach(memoir.tags.prefix(2), id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.system(size: DesignTokens.Typography.caption))
                        .foregroundColor(MemoirColors.primary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - 空状态

    private var noResultsView: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(MemoirColors.textTertiary)
            Text("没有找到相关回忆录")
                .font(.system(size: DesignTokens.Typography.title2, weight: .medium))
                .foregroundColor(MemoirColors.textSecondary)
            Text("试试其他关键词或筛选条件")
                .font(.system(size: DesignTokens.Typography.body))
                .foregroundColor(MemoirColors.textTertiary)
            Spacer()
        }
    }

    private var searchingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Spacer()
        }
    }
}

// MARK: - 筛选标签组件

struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: DesignTokens.Typography.badge))
                .foregroundColor(isSelected ? .white : MemoirColors.textSecondary)
                .padding(.horizontal, DesignTokens.Spacing.sm)
                .padding(.vertical, 8)
                .background(isSelected ? MemoirColors.primary : MemoirColors.surface)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : MemoirColors.border, lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 日期范围筛选

struct DateRangeFilterChip: View {
    @Binding var dateFrom: Date?
    @Binding var dateTo: Date?
    @State private var showPicker = false
    @State private var pickerMode: PickerMode = .from

    enum PickerMode { case from, to }

    var body: some View {
        Menu {
            Button {
                pickerMode = .from
                showPicker = true
            } label: {
                Label(dateFrom == nil ? "选择起始日期" : "从: \(formatDate(dateFrom!))",
                      systemImage: "calendar")
            }

            Button {
                pickerMode = .to
                showPicker = true
            } label: {
                Label(dateTo == nil ? "选择结束日期" : "至: \(formatDate(dateTo!))",
                      systemImage: "calendar")
            }

            if dateFrom != nil || dateTo != nil {
                Divider()
                Button(role: .destructive) {
                    dateFrom = nil
                    dateTo = nil
                } label: {
                    Label("清除日期范围", systemImage: "xmark")
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.system(size: 12))
                if let from = dateFrom, let to = dateTo {
                    Text("\(formatShortDate(from)) – \(formatShortDate(to))")
                } else if let from = dateFrom {
                    Text("\(formatShortDate(from)) 起")
                } else if let to = dateTo {
                    Text("至 \(formatShortDate(to))")
                } else {
                    Text("日期范围")
                }
            }
            .font(.system(size: DesignTokens.Typography.badge))
            .foregroundColor(dateFrom != nil || dateTo != nil ? .white : MemoirColors.textSecondary)
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, 8)
            .background(dateFrom != nil || dateTo != nil ? MemoirColors.primary : MemoirColors.surface)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(
                        dateFrom != nil || dateTo != nil ? Color.clear : MemoirColors.border,
                        lineWidth: 0.5
                    )
            )
        }
        .sheet(isPresented: $showPicker) {
            datePickerSheet
        }
    }

    private var datePickerSheet: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    pickerMode == .from ? "起始日期" : "结束日期",
                    selection: Binding(
                        get: {
                            pickerMode == .from ? (dateFrom ?? Date()) : (dateTo ?? Date())
                        },
                        set: { newDate in
                            if pickerMode == .from {
                                dateFrom = newDate
                            } else {
                                dateTo = newDate
                            }
                        }
                    ),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .environment(\.locale, Locale(identifier: "zh_CN"))
                .padding()

                Spacer()
            }
            .navigationTitle(pickerMode == .from ? "选择起始日期" : "选择结束日期")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("确定") {
                        showPicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func formatDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "yyyy年 M月 d日"
        return fmt.string(from: date)
    }

    private func formatShortDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: date)
    }
}

// MARK: - ViewModel

@MainActor
final class SearchFilterViewModel: ObservableObject {
    @Published var keyword = ""
    @Published var selectedMood: String?
    @Published var dateFrom: Date?
    @Published var dateTo: Date?
    @Published var results: [Memoir] = []
    @Published var isSearching = false
    @Published var hasSearched = false

    var hasActiveFilters: Bool {
        selectedMood != nil || dateFrom != nil || dateTo != nil
    }

    func search() async {
        guard !keyword.isEmpty || hasActiveFilters else { return }

        isSearching = true
        defer { isSearching = false; hasSearched = true }

        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"

        do {
            let response = try await MemoirService.shared.searchMemoirs(
                keyword: keyword.isEmpty ? nil : keyword,
                mood: selectedMood,
                tag: nil,
                dateFrom: dateFrom.map { dateFmt.string(from: $0) },
                dateTo: dateTo.map { dateFmt.string(from: $0) }
            )
            results = response.data
        } catch {
            results = []
        }
    }

    func resetFilters() {
        selectedMood = nil
        dateFrom = nil
        dateTo = nil
    }
}

#Preview {
    NavigationStack {
        SearchFilterView()
    }
}
