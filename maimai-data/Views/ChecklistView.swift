import SwiftUI
import SwiftData

/// Port of `LevelCheckActivity` — shows song completion progress for a selected
/// difficulty level, grouped by chart constant (ds).
struct ChecklistView: View {
    @EnvironmentObject private var dataManager: DataManager

    @State private var selectedLevel: String = {
        let saved = String(format: "%.0f", AppPreferences.lastQueryLevel)
        return SongFilter.allLevels.contains(saved) ? saved : (SongFilter.allLevels.first ?? "1")
    }()
    @State private var displayMode: Int = 0  // 0=rank, 1=fc, 2=fs
    @State private var songs: [SongData] = []
    @State private var records: [Record] = []
    @State private var groupedData: [(ds: Double, items: [DsSongData])] = []
    @State private var selectedSong: SongData?

    private let allLevels = SongFilter.allLevels

    var body: some View {
        VStack(spacing: 0) {
            // Level picker (same style as version progress)
            if !allLevels.isEmpty {
                Picker("等级", selection: $selectedLevel) {
                    ForEach(allLevels, id: \.self) { level in
                        Text("Level \(level)").tag(level)
                    }
                }
                .pickerStyle(.menu)
                .padding()
                .onChange(of: selectedLevel) { _, _ in
                    AppPreferences.lastQueryLevel = Float(selectedLevel) ?? 1
                    updateGroupedData()
                }
            }

            if !groupedData.isEmpty {
                statsHeader
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }

            if !groupedData.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12, pinnedViews: .sectionHeaders) {
                        ForEach(groupedData, id: \.ds) { group in
                            Section {
                                LazyVGrid(
                                    columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 6),
                                    spacing: 3
                                ) {
                                    ForEach(group.items) { item in
                                        songCell(for: item)
                                    }
                                }
                            } header: {
                                Text(String(format: "定数 %.1f", group.ds))
                                    .font(.subheadline.bold())
                                    .padding(.horizontal)
                                    .padding(.vertical, 4)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(.regularMaterial)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                }
            } else {
                Spacer()
                Text("暂无数据")
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .navigationTitle("等级进度")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    displayMode = (displayMode + 1) % 3
                } label: {
                    Image(systemName: displayModeIcon(displayMode))
                }
            }
        }
        .navigationDestination(item: $selectedSong) { song in
            SongDetailView(song: song)
        }
        .task {
            await loadData()
        }
    }

    // MARK: - Stats Header

    private var statsHeader: some View {
        let allItems = groupedData.flatMap(\.items)
        let totalCount = allItems.count
        let itemKeySet = Set(allItems.map { "\($0.songId):\($0.levelIndex)" })
        let tripleSCount = records.filter { r in
            r.achievements >= 100 && r.level == selectedLevel && itemKeySet.contains("\(r.songId):\(r.levelIndex)")
        }.count
        let fcCount = records.filter { r in
            !r.fc.isEmpty && r.level == selectedLevel && itemKeySet.contains("\(r.songId):\(r.levelIndex)")
        }.count
        let apCount = records.filter { r in
            (r.fc == "ap" || r.fc == "app") && r.level == selectedLevel && itemKeySet.contains("\(r.songId):\(r.levelIndex)")
        }.count
        let fsdCount = records.filter { r in
            (r.fs == "fsd" || r.fs == "fsdp") && r.level == selectedLevel && itemKeySet.contains("\(r.songId):\(r.levelIndex)")
        }.count

        return HStack(spacing: 12) {
            statBadge(label: "SSS", count: tripleSCount, total: totalCount, color: .yellow)
            statBadge(label: "FC", count: fcCount, total: totalCount, color: .green)
            statBadge(label: "AP", count: apCount, total: totalCount, color: .red)
            statBadge(label: "FSD", count: fsdCount, total: totalCount, color: .purple)
        }
        .font(.caption)
    }

    private func statBadge(label: String, count: Int, total: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(count)/\(total)")
                .font(.caption.bold())
            Text(label)
                .font(.caption2)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    // MARK: - Song Cell

    private func songCell(for item: DsSongData) -> some View {
        let record = records.first { $0.songId == item.songId && $0.levelIndex == item.levelIndex }
        let hasRecord = record != nil

        return Button {
            if let song = songs.first(where: { $0.id == item.songId }) {
                selectedSong = song
            }
        } label: {
            CachedJacketView(imageUrl: item.imageUrl ?? "")
                .aspectRatio(1, contentMode: .fit)
                .overlay(alignment: .bottomTrailing) {
                    if hasRecord, let record {
                        recordMark(for: record)
                            .padding(2)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if item.type == Constants.chartTypeDX {
                        Text("DX")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 2)
                            .background(Color.orange)
                            .cornerRadius(2)
                            .padding(2)
                    }
                }
                .opacity(hasRecord ? 1.0 : 0.4)
        }
        .buttonStyle(.plain)
    }

    private func recordMark(for record: Record) -> some View {
        RecordMark(record: record, displayMode: displayMode)
    }

    // MARK: - Data

    private func loadData() async {
        songs = (try? dataManager.allSongs(includeUtage: false)) ?? []
        records = (try? dataManager.allRecords()) ?? []
        // Only set initial level on first load; preserve user's selection on
        // subsequent appearances (e.g. returning from SongDetailView).
        if selectedLevel.isEmpty {
            let saved = String(format: "%.0f", AppPreferences.lastQueryLevel)
            selectedLevel = allLevels.contains(saved) ? saved : (allLevels.first ?? "1")
        }
        updateGroupedData()
    }

    private func updateGroupedData() {
        let items = songs.flatMap { song in
            (try? dataManager.charts(for: song.id))?
                .enumerated()
                .filter { $0.element.level == selectedLevel }
                .map { index, chart in
                    DsSongData(
                        songId: song.id,
                        title: song.title,
                        type: song.type,
                        imageUrl: song.imageUrl,
                        levelIndex: index,
                        ds: chart.ds
                    )
                } ?? []
        }
        groupedData = Dictionary(grouping: items, by: { $0.ds })
            .map { (ds: $0.key, items: $0.value) }
            .sorted { $0.ds > $1.ds }
    }
}

#Preview {
    NavigationStack {
        ChecklistView()
            .environmentObject(DataManager(inMemory: true))
    }
}
