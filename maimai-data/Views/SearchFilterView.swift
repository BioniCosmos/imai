import SwiftUI

struct SearchFilterView: View {
    @Binding var filter: SongFilter
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dataManager: DataManager

    @State private var availableVersions: [String] = []

    var body: some View {
        NavigationStack {
            Form {
                Section("搜索") {
                    TextField("关键词", text: $filter.searchText)
                    Toggle("匹配别名", isOn: $filter.matchAlias)
                    Toggle("匹配谱师", isOn: $filter.matchCharter)
                    Toggle("匹配歌曲ID", isOn: $filter.matchSongId)
                    Toggle("仅收藏", isOn: $filter.favoritesOnly)
                }

                Section("流派") {
                    FlowLayout(spacing: 8) {
                        ForEach(SongFilter.allGenres, id: \.self) { genre in
                            ToggleChip(
                                title: genre,
                                isSelected: filter.selectedGenres.contains(genre)
                            ) {
                                filter.selectedGenres.toggle(genre)
                            }

                        }
                    }
                }

                Section("版本") {
                    FlowLayout(spacing: 8) {
                        ForEach(availableVersions, id: \.self) { version in
                            ToggleChip(
                                title: version,
                                isSelected: filter.selectedVersions.contains(version)
                            ) {
                                filter.selectedVersions.toggle(version)
                            }
                        }
                    }
                }

                Section("难度") {
                    Picker("难度", selection: .init(
                        get: { filter.selectedLevel ?? "全部" },
                        set: { filter.selectedLevel = ($0 == "全部" ? nil : $0) }
                    )) {
                        Text("全部").tag("全部")
                        ForEach(SongFilter.allLevels, id: \.self) { level in
                            Text(level).tag(level)
                        }
                    }
                }

                Section("排序") {
                    Picker("排序", selection: .init(
                        get: { filter.sequencing ?? "默认排序" },
                        set: { filter.sequencing = ($0 == "默认排序" ? nil : $0) }
                    )) {
                        ForEach(SongFilter.sequencingOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                }

                Section("定数") {
                    HStack {
                        TextField("定数", value: $filter.ds, format: .number)
                            .keyboardType(.decimalPad)
                        Button("清除") { filter.ds = nil }
                    }
                }

                Section {
                    Button("重置") {
                        filter = SongFilter()
                    }
                }
            }
            .navigationTitle("筛选")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .task {
                availableVersions = (try? dataManager.distinctVersions()) ?? []
            }
        }
    }
}

struct ToggleChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > maxWidth, x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

private extension Set {
    mutating func toggle(_ element: Element) {
        if contains(element) {
            remove(element)
        } else {
            insert(element)
        }
    }
}

#Preview {
    SearchFilterView(filter: .constant(SongFilter()))
        .environmentObject(DataManager(inMemory: true))
}
