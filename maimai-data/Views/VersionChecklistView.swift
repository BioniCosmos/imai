import SwiftUI
import SwiftData

/// Port of `VersionCheckActivity` — shows song completion progress grouped by
/// version, filtered to MASTER difficulty charts.
struct VersionChecklistView: View {
    @EnvironmentObject private var dataManager: DataManager

    @State private var versions: [String] = []
    @State private var selectedVersion: String = ""
    @State private var displayMode: Int = 0  // 0=rank, 1=fc, 2=fs
    @State private var songs: [SongData] = []
    @State private var records: [Record] = []
    @State private var groupedSongs: [(level: String, songs: [SongData])] = []
    @State private var selectedSong: SongData?

    var body: some View {
        VStack(spacing: 0) {
            if !versions.isEmpty {
                Picker("版本", selection: $selectedVersion) {
                    ForEach(versions, id: \.self) { version in
                        Text(version).tag(version)
                    }
                }
                .pickerStyle(.menu)
                .padding()
                .onChange(of: selectedVersion) { _, _ in
                    updateGroupedData()
                }
            }

            if !groupedSongs.isEmpty {
                statsHeader
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }

            if !groupedSongs.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12, pinnedViews: .sectionHeaders) {
                        ForEach(groupedSongs, id: \.level) { group in
                            Section {
                                LazyVGrid(
                                    columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 6),
                                    spacing: 3
                                ) {
                                    ForEach(group.songs, id: \.id) { song in
                                        songCell(for: song)
                                    }
                                }
                            } header: {
                                Text("Level \(group.level)")
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
        .navigationTitle("版本进度")
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
        let allSongs = groupedSongs.flatMap(\.songs)
        let totalCount = allSongs.count
        let songIdSet = Set(allSongs.map(\.id))
        let tripleSCount = records.filter { r in
            r.achievements >= 100 && songIdSet.contains(r.songId)
        }.count
        let fcCount = records.filter { r in
            !r.fc.isEmpty && songIdSet.contains(r.songId)
        }.count
        let apCount = records.filter { r in
            (r.fc == "ap" || r.fc == "app") && songIdSet.contains(r.songId)
        }.count
        let fsdCount = records.filter { r in
            (r.fs == "fsd" || r.fs == "fsdp") && songIdSet.contains(r.songId)
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

    private func songCell(for song: SongData) -> some View {
        let record = records.first { $0.songId == song.id }
        let hasRecord = record != nil

        return Button {
            selectedSong = song
        } label: {
            CachedJacketView(imageUrl: song.imageUrl)
                .aspectRatio(1, contentMode: .fit)
                .overlay(alignment: .bottomTrailing) {
                    if hasRecord, let record {
                        recordMark(for: record)
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
        let allVersions = (try? dataManager.distinctVersions()) ?? []
        songs = (try? dataManager.allSongs(includeUtage: false)) ?? []
        records = (try? dataManager.allRecords()) ?? []
        // Set selected version BEFORE versions array to avoid Picker rendering with "".
        if selectedVersion.isEmpty, let last = allVersions.last {
            selectedVersion = last
        } else if !allVersions.contains(selectedVersion), let last = allVersions.last {
            selectedVersion = last
        }
        versions = allVersions
        updateGroupedData()
    }

    private func updateGroupedData() {
        let versionSongs = songs.filter { $0.from == selectedVersion }
        let songWithMasterLevel: [(song: SongData, level: String, ds: Double)] = versionSongs.compactMap { song in
            guard let masterChart = (try? dataManager.charts(for: song.id))?
                .first(where: { $0.difficultyType.index == 3 }) else { return nil }
            return (song: song, level: masterChart.level, ds: masterChart.ds)
        }
        let sorted = songWithMasterLevel.sorted { $0.ds > $1.ds }
        let grouped = Dictionary(grouping: sorted, by: { $0.level })
        let levelOrder = SongFilter.allLevels
        groupedSongs = grouped.map { (level: $0.key, songs: $0.value.map(\.song)) }
            .sorted { a, b in
                (levelOrder.firstIndex(of: a.level) ?? 99) < (levelOrder.firstIndex(of: b.level) ?? 99)
            }
    }
}

#Preview {
    NavigationStack {
        VersionChecklistView()
            .environmentObject(DataManager(inMemory: true))
    }
}
