import SwiftUI

// MARK: - 无障碍设置页 — 大字号/高对比度/减少动效

struct AccessibilitySettingsView: View {
    @StateObject private var am = AccessibilityManager.shared
    @State private var previewText = "这是正文预览文字，可以帮助您选择最舒适的字号和显示效果。"
    @State private var previewTitle = "标题预览"

    var body: some View {
        List {
            // 预览区
            Section {
                previewSection
            }

            // 字号调节
            Section {
                fontSizeSelector
            } header: {
                Text("字号设置")
            } footer: {
                Text("适合阅读的字号能让回忆更加轻松愉快")
            }

            // 显示增强
            Section {
                highContrastToggle
                boldTextToggle
            } header: {
                Text("显示增强")
            }

            // 触控与交互
            Section {
                largeTouchTargetsToggle
                reduceMotionToggle
            } header: {
                Text("交互辅助")
            } footer: {
                Text("开启大触控区域后，按钮和列表项的最小高度将增加到56pt，方便点击")
            }

            // 重置
            Section {
                Button("恢复默认设置") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        am.fontScale = 0
                        am.highContrast = false
                        am.boldText = false
                        am.largeTouchTargets = false
                        am.reduceMotion = false
                    }
                }
                .foregroundColor(MemoirColors.primary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(MemoirColors.background)
        .navigationTitle("无障碍设置")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - 预览区

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("预览")
                .font(.system(size: DesignTokens.Typography.caption, weight: .medium))
                .foregroundColor(MemoirColors.textTertiary)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                Text(previewTitle)
                    .font(am.scaledFont(DesignTokens.Typography.title, weight: .bold))
                    .foregroundColor(MemoirColors.textPrimary)

                Text(previewText)
                    .font(am.scaledFont(DesignTokens.Typography.body))
                    .foregroundColor(MemoirColors.textSecondary)
                    .lineSpacing(am.scaledSpacing(6))

                HStack(spacing: 8) {
                    Text("按钮 1")
                        .font(am.scaledFont(DesignTokens.Typography.button, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .frame(height: am.scaledButtonHeight(40))
                        .background(MemoirColors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    Text("按钮 2")
                        .font(am.scaledFont(DesignTokens.Typography.button, weight: .medium))
                        .foregroundColor(MemoirColors.primary)
                        .padding(.horizontal, 16)
                        .frame(height: am.scaledButtonHeight(40))
                        .background(MemoirColors.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(MemoirColors.primary, lineWidth: 1.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(DesignTokens.Spacing.lg)
            .background(MemoirColors.card)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
            .shadow(
                color: DesignTokens.Shadow.card.color,
                radius: DesignTokens.Shadow.card.radius,
                y: DesignTokens.Shadow.card.y
            )
        }
    }

    // MARK: - 字号滑杆

    private var fontSizeSelector: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            HStack {
                Text("标准")
                    .font(.system(size: 13))
                    .foregroundColor(MemoirColors.textTertiary)
                Slider(value: $am.fontScale, in: 0...2, step: 1)
                    .tint(MemoirColors.primary)
                Text("超大")
                    .font(.system(size: 13))
                    .foregroundColor(MemoirColors.textTertiary)
            }

            HStack(spacing: 0) {
                ForEach(["标准", "大号", "超大"], id: \.self) { label in
                    Text(label)
                        .font(.system(size: 13, weight: am.fontScale == Double(
                            ["标准", "大号", "超大"].firstIndex(of: label) ?? 0
                        ) ? .bold : .regular))
                        .foregroundColor(
                            am.fontScale == Double(["标准", "大号", "超大"].firstIndex(of: label) ?? 0)
                                ? MemoirColors.primary
                                : MemoirColors.textTertiary
                        )
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: - 显示增强开关

    private var highContrastToggle: some View {
        Toggle(isOn: $am.highContrast) {
            VStack(alignment: .leading, spacing: 2) {
                Text("高对比度")
                    .font(.system(size: DesignTokens.Typography.body))
                Text("增强文字与背景的对比度，适合视力较弱的用户")
                    .font(.system(size: DesignTokens.Typography.caption))
                    .foregroundColor(MemoirColors.textTertiary)
            }
        }
    }

    private var boldTextToggle: some View {
        Toggle(isOn: $am.boldText) {
            VStack(alignment: .leading, spacing: 2) {
                Text("粗体文本")
                    .font(.system(size: DesignTokens.Typography.body))
                Text("所有文字使用粗体显示")
                    .font(.system(size: DesignTokens.Typography.caption))
                    .foregroundColor(MemoirColors.textTertiary)
            }
        }
    }

    // MARK: - 交互辅助开关

    private var largeTouchTargetsToggle: some View {
        Toggle(isOn: $am.largeTouchTargets) {
            VStack(alignment: .leading, spacing: 2) {
                Text("大触控区域")
                    .font(.system(size: DesignTokens.Typography.body))
                Text("增大按钮和列表项的最小点击区域至56pt")
                    .font(.system(size: DesignTokens.Typography.caption))
                    .foregroundColor(MemoirColors.textTertiary)
            }
        }
    }

    private var reduceMotionToggle: some View {
        Toggle(isOn: $am.reduceMotion) {
            VStack(alignment: .leading, spacing: 2) {
                Text("减少动效")
                    .font(.system(size: DesignTokens.Typography.body))
                Text("关闭页面切换和组件动画效果")
                    .font(.system(size: DesignTokens.Typography.caption))
                    .foregroundColor(MemoirColors.textTertiary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        AccessibilitySettingsView()
    }
}
