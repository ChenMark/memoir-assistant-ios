import SwiftUI

// MARK: - 家族树可视化（核心亮点功能）

struct FamilyTreeView: View {
    @State private var allFriends: [Friend] = []
    @State private var isLoading = true

    // 手势状态
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero

    @State private var selectedFriend: Friend?
    @State private var showDetail = false

    private let nodeSize: CGFloat = 90
    private let hSpacing: CGFloat = 40
    private let vSpacing: CGFloat = 100

    var body: some View {
        GeometryReader { geo in
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView("加载家族树...")
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if allFriends.isEmpty {
                emptyView
            } else {
                let layout = buildTreeLayout(width: geo.size.width)

                ScrollView([.horizontal, .vertical], showsIndicators: false) {
                    ZStack(alignment: .topLeading) {
                        // 连线层
                        ForEach(layout.edges) { edge in
                            familyEdge(edge, layout: layout)
                        }

                        // 节点层
                        ForEach(layout.nodes) { node in
                            familyNodeView(node: node)
                                .position(x: node.x, y: node.y)
                                .onTapGesture {
                                    selectedFriend = node.friend
                                    showDetail = true
                                }
                        }
                    }
                    .frame(width: layout.totalWidth, height: layout.totalHeight)
                    .padding(60)
                }
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    SimultaneousGesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = min(max(lastScale * value, 0.3), 3.0)
                            }
                            .onEnded { _ in
                                lastScale = scale
                            },
                        DragGesture()
                            .onChanged { value in
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            }
                    )
                )
                .animation(.interactiveSpring(), value: scale)
            }
        }
        .background(MemoirColors.background)
        .navigationTitle("家族树")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button {
                        withAnimation { resetZoom() }
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }

                    Menu {
                        Button { scale = min(scale * 1.5, 3.0); lastScale = scale } label: {
                            Label("放大", systemImage: "plus.magnifyingglass")
                        }
                        Button { scale = max(scale / 1.5, 0.3); lastScale = scale } label: {
                            Label("缩小", systemImage: "minus.magnifyingglass")
                        }
                        Divider()
                        Button { resetZoom() } label: {
                            Label("重置", systemImage: "arrow.counterclockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                .foregroundColor(MemoirColors.primary)
            }
        }
        .sheet(isPresented: $showDetail) {
            if let friend = selectedFriend {
                FriendDetailView(friend: friend, category: .family) { _ in
                    Task { await loadFamilyData() }
                }
            }
        }
        .task { await loadFamilyData() }
    }

    // MARK: - 空态

    private var emptyView: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Spacer()
            Text("👨‍👩‍👧‍👦")
                .font(.system(size: 60))
            Text("还没有家族成员")
                .font(.system(size: DesignTokens.Typography.headline, weight: .semibold))
                .foregroundColor(MemoirColors.textPrimary)
            Text("先在亲友中添加「家人」分类的成员\n设置父子关系和配偶关系，即可生成家族树")
                .font(.system(size: DesignTokens.Typography.bodySmall))
                .foregroundColor(MemoirColors.textTertiary)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    // MARK: - 节点视图

    private func familyNodeView(node: TreeNode) -> some View {
        VStack(spacing: 4) {
            // 头像
            ZStack {
                Circle()
                    .fill(backgroundColor(for: node.friend))
                    .frame(width: 52, height: 52)

                Text(String(node.friend.name.prefix(1)))
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
            }
            .overlay(
                Circle().stroke(MemoirColors.border, lineWidth: 2)
            )

            // 姓名
            Text(node.friend.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(MemoirColors.textPrimary)
                .lineLimit(1)
                .frame(width: 80)

            // 关系
            if let rel = node.friend.relationship {
                Text(rel)
                    .font(.system(size: 11))
                    .foregroundColor(MemoirColors.textTertiary)
                    .lineLimit(1)
            }
        }
        .frame(width: nodeSize)
    }

    private func backgroundColor(for friend: Friend) -> Color {
        let gen = friend.generation ?? 0
        switch gen {
        case 3, 2: return Color(red: 0.6, green: 0.4, blue: 0.2)   // 祖辈 — 古铜
        case 1: return Color(red: 0.3, green: 0.5, blue: 0.7)       // 父辈 — 蓝
        case 0: return MemoirColors.primary                          // 同辈 — 主题色
        default: return Color(red: 0.4, green: 0.65, blue: 0.4)     // 子辈 — 绿
        }
    }

    // MARK: - 连线

    private func familyEdge(_ edge: TreeEdge, layout: TreeLayout) -> some View {
        Path { path in
            let from = position(of: edge.from, in: layout)
            let to = position(of: edge.to, in: layout)

            if edge.type == .parent {
                // 垂直向下 + 水平折线
                let midY = (from.y + to.y) / 2
                path.move(to: CGPoint(x: from.x, y: from.y + nodeSize / 2))
                path.addLine(to: CGPoint(x: from.x, y: midY))
                path.addLine(to: CGPoint(x: to.x, y: midY))
                path.addLine(to: CGPoint(x: to.x, y: to.y - nodeSize / 2))
            } else {
                // 水平连接（配偶）
                path.move(to: CGPoint(x: from.x + nodeSize / 2, y: from.y))
                path.addLine(to: CGPoint(x: to.x - nodeSize / 2, y: to.y))
            }
        }
        .stroke(
            edge.type == .spouse ? MemoirColors.accent.opacity(0.5) : MemoirColors.border,
            style: StrokeStyle(
                lineWidth: edge.type == .spouse ? 1.5 : 2,
                dash: edge.type == .spouse ? [6, 3] : []
            )
        )
    }

    private func position(of nodeId: String, in layout: TreeLayout) -> CGPoint {
        if let node = layout.nodes.first(where: { $0.id == nodeId }) {
            return CGPoint(x: node.x, y: node.y)
        }
        return .zero
    }

    // MARK: - 数据加载与树构建

    private func loadFamilyData() async {
        do {
            let response = try await FriendService.shared.fetchAllFriends()
            allFriends = response.data.filter { $0.category == .family }
        } catch {
            allFriends = []
        }
        isLoading = false
    }

    private func resetZoom() {
        withAnimation(.spring()) {
            scale = 1.0
            lastScale = 1.0
            offset = .zero
            lastOffset = .zero
        }
    }

    // MARK: - 树布局算法

    private func buildTreeLayout(width: CGFloat) -> TreeLayout {
        let friendMap = Dictionary(uniqueKeysWithValues: allFriends.map { ($0.id, $0) })

        // 按 generation 分组，generation 越大越靠上
        let grouped = Dictionary(grouping: allFriends) { $0.generation ?? 0 }
        let generations = grouped.keys.sorted(by: >) // 祖辈在上

        var nodes: [TreeNode] = []
        var edges: [TreeEdge] = []
        var yOffset: CGFloat = 20

        var prevGenNodes: [TreeNode] = []

        for gen in generations {
            let genFriends = grouped[gen] ?? []

            // 布局同一辈分的节点
            let totalWidth = CGFloat(genFriends.count) * (nodeSize + hSpacing) - hSpacing
            let startX = max((totalWidth) / 2 + 40, 0)

            var genNodes: [TreeNode] = []

            for (index, friend) in genFriends.enumerated() {
                let x = startX + CGFloat(index) * (nodeSize + hSpacing)
                let node = TreeNode(
                    id: friend.id,
                    friend: friend,
                    x: x,
                    y: yOffset,
                    generation: gen
                )
                genNodes.append(node)
                nodes.append(node)

                // 配偶连线
                if let spouseId = friend.spouseId,
                   let spouse = friendMap[spouseId],
                   !genNodes.contains(where: { $0.id == spouseId }) {
                    let spouseNode = TreeNode(
                        id: spouseId,
                        friend: spouse,
                        x: x + nodeSize + hSpacing * 0.5,
                        y: yOffset,
                        generation: gen
                    )
                    nodes.append(spouseNode)
                    edges.append(TreeEdge(from: friend.id, to: spouseId, type: .spouse))
                }
            }

            // 父子连线
            for parentNode in prevGenNodes {
                // 找到该 parent 的子节点
                let children = genFriends.filter { $0.parentId == parentNode.id }
                for child in children {
                    edges.append(TreeEdge(from: parentNode.id, to: child.id, type: .parent))
                }
            }

            prevGenNodes = genNodes
            yOffset += nodeSize + vSpacing
        }

        let maxX = (nodes.map(\.x).max() ?? 0) + nodeSize + 40
        let maxY = yOffset + 40

        return TreeLayout(nodes: nodes, edges: edges, totalWidth: max(maxX, width), totalHeight: maxY)
    }
}

// MARK: - Layout Data Types

struct TreeNode: Identifiable {
    let id: String
    let friend: Friend
    let x: CGFloat
    let y: CGFloat
    let generation: Int
}

struct TreeEdge: Identifiable {
    let id = UUID()
    let from: String
    let to: String
    let type: EdgeType

    enum EdgeType {
        case parent
        case spouse
    }
}

struct TreeLayout {
    let nodes: [TreeNode]
    let edges: [TreeEdge]
    let totalWidth: CGFloat
    let totalHeight: CGFloat
}

// MARK: - Preview

#Preview {
    NavigationStack {
        FamilyTreeView()
    }
}
