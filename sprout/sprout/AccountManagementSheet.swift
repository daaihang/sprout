import SwiftUI

struct AccountManagementSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var pushTime = Date()
    @State private var showTimePicker = false
    @State private var reminderInterval = 30
    @State private var showReminderPicker = false

    var body: some View {
        NavigationStack {
            List {
                // MARK: - 用户信息头部
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 72))
                            .foregroundStyle(.blue)

                        VStack(spacing: 4) {
                            Text("用户名")
                                .font(.system(size: 20, weight: .semibold))

                            Text("user@example.com")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }

                        Text("Pro 订阅")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.orange)
                            .clipShape(Capsule())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
                .listRowBackground(Color.clear)

                // MARK: - 个人设置
                Section("个人设置") {
                    HStack {
                        SettingsRow(icon: "bell", iconColor: .red, title: "每日一问推送", detail: pushTimeString)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showTimePicker = true
                    }

                    HStack {
                        SettingsRow(icon: "person.2", iconColor: .orange, title: "关系提醒间隔", detail: "\(reminderInterval)天")
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showReminderPicker = true
                    }

                    SettingsRow(icon: "globe", iconColor: .blue, title: "记录语言", detail: "中文")
                    SettingsRow(icon: "moon", iconColor: .indigo, title: "深色模式", detail: "跟随系统")
                }

                // MARK: - 隐私与安全
                Section("隐私与安全") {
                    SettingsRow(icon: "faceid", iconColor: .green, title: "Face ID / Touch ID 锁")
                    SettingsRow(icon: "square.and.arrow.up", iconColor: .gray, title: "数据导出 (JSON)")
                }

                // MARK: - 订阅
                Section("订阅") {
                    HStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.green.opacity(0.15))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: "leaf.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.green)
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Grow 计划")
                                .font(.system(size: 15, weight: .medium))
                            Text("到期日：2025年12月31日")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Text("活跃中")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                    }
                    .padding(.vertical, 4)
                }

                // MARK: - 关于 + 反馈
                Section("关于 + 反馈") {
                    SettingsRow(icon: "info.circle", iconColor: .gray, title: "版本号", detail: "1.0.5")
                    NavigationLink(destination: Text("评分页面")) {
                        SettingsRow(icon: "star", iconColor: .yellow, title: "给 Mory 评分")
                    }
                    NavigationLink(destination: Text("反馈页面")) {
                        SettingsRow(icon: "envelope", iconColor: .orange, title: "发送反馈")
                    }
                }

                // MARK: - Debug
                Section {
                    NavigationLink(destination: DebugPage()) {
                        HStack(spacing: 12) {
                            Image(systemName: "ant")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .frame(width: 28, height: 28)
                                .background(Color.purple)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            Text("Debug")
                        }
                    }
                }

                // MARK: - 退出登录
                Section {
                    Button("退出登录") {
                        // logout action
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("账户")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .sheet(isPresented: $showTimePicker) {
                NavigationStack {
                    VStack {
                        DatePicker("选择时间", selection: $pushTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                    }
                    .navigationTitle("每日一问推送时间")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("完成") { showTimePicker = false }
                        }
                    }
                }
                .presentationDetents([.height(300)])
            }
            .confirmationDialog("关系提醒间隔", isPresented: $showReminderPicker) {
                Button("7 天") { reminderInterval = 7 }
                Button("14 天") { reminderInterval = 14 }
                Button("30 天") { reminderInterval = 30 }
                Button("取消", role: .cancel) { }
            }
        }
    }

    private var pushTimeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: pushTime)
    }
}

// MARK: - MemoryOverviewSection

struct MemoryOverviewSection: View {
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                // 标题
                HStack {
                    Text("我的记忆概览")
                        .font(.system(size: 18, weight: .semibold))
                    Spacer()
                    Text("你已经用 Mory 记录了 128 天")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                // 统计数字
                HStack(spacing: 12) {
                    StatCard(value: "128", label: "记录天数", icon: "calendar")
                    StatCard(value: "365", label: "总记录数", icon: "doc.text")
                    StatCard(value: "12", label: "人物数", icon: "person.2")
                    StatCard(value: "8", label: "决策数", icon: "flag")
                }

                // Year in Pixels 热力图
                YearInPixelsGrid()

                // 成就徽章墙
                BadgeWallView()

                // Top 人物
                TopPeopleRowView()
            }
            .padding(.vertical, 8)
        }
    }
}

// MARK: - StatCard

struct StatCard: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.blue.opacity(0.70))

            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)

            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - YearInPixelsGrid

struct YearInPixelsGrid: View {
    private let columns = 52 // 52 weeks
    private let rows = 7 // 7 days

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("今年的热力图")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHGrid(rows: Array(repeating: SwiftUI.GridItem(.fixed(6)), count: rows), spacing: 2) {
                    ForEach(0..<365, id: \.self) { index in
                        let intensity = Double.random(in: 0...1)
                        RoundedRectangle(cornerRadius: 1)
                            .fill(intensity > 0.7 ? Color.green : (intensity > 0.3 ? Color.green.opacity(0.5) : Color.gray.opacity(0.2)))
                            .frame(width: 6, height: 6)
                    }
                }
            }
            .frame(height: 20)
        }
    }
}

// MARK: - BadgeWallView

struct BadgeWallView: View {
    private let badges = [
        ("🎯", "第一次记录", true),
        ("🔥", "连续30天", true),
        ("👥", "记住10个人", true),
        ("⭐", "完成100条记录", false),
        ("🏆", "年度用户", false),
        ("🌟", "里程碑达成", false),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("成就徽章")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(badges, id: \.0) { badge in
                        VStack(spacing: 4) {
                            Text(badge.0)
                                .font(.system(size: 28))
                                .opacity(badge.2 ? 1.0 : 0.35)

                            Text(badge.1)
                                .font(.system(size: 10))
                                .foregroundColor(badge.2 ? .primary : .secondary)
                        }
                        .frame(width: 60, height: 60)
                        .background(badge.2 ? Color.blue.opacity(0.10) : Color.gray.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }
}

// MARK: - TopPeopleRowView

struct TopPeopleRowView: View {
    private let topPeople = ["A", "B", "C", "D", "E"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("最常提到的人")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)

            HStack(spacing: -8) {
                ForEach(topPeople.prefix(5), id: \.self) { name in
                    Circle()
                        .fill(Color.blue.opacity(0.20 + Double.random(in: 0...0.3)))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Text(String(name.prefix(1)))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.blue)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                }

                Spacer()

                Text("查看全部")
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
            }
        }
    }
}

// MARK: - SettingsRow

struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    var detail: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(iconColor)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            Text(title)

            Spacer()

            if let detail = detail {
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    AccountManagementSheet()
}