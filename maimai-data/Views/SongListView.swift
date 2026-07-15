import SwiftUI
import SwiftData

struct SongListView: View {
    @EnvironmentObject private var dataManager: DataManager
    @Query(sort: \SongData.id, order: .reverse) private var songs: [SongData]

    @State private var filter = SongFilter()
    @State private var showingFilter = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var aliasesBySong: [Int: [String]] = [:]
    @State private var chartsBySong: [Int: [ChartSummary]] = [:]

    private var filteredSongs: [SongData] {
        SongSearcher.filter(
            songs: songs,
            filter: filter,
            aliasesBySong: aliasesBySong,
            chartsBySong: chartsBySong
        )
    }

    var body: some View {
        NavigationStack {
            List(filteredSongs) { song in
                NavigationLink(value: song) {
                    SongRow(song: song)
                }
            }
            .navigationTitle("歌曲列表")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: SongData.self) { song in
                SongDetailView(song: song)
            }
            .searchable(text: $filter.searchText, prompt: "搜索歌曲/别名/谱师/ID")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingFilter = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(filter.isActive ? .blue : .primary)
                    }
                }
            }
            .sheet(isPresented: $showingFilter) {
                SearchFilterView(filter: $filter)
            }
            .overlay {
                if isLoading {
                    ProgressView("加载数据中...")
                } else if filteredSongs.isEmpty && !songs.isEmpty {
                    ContentUnavailableView("无结果", systemImage: "magnifyingglass")
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .task {
                await checkData()
            }
            .refreshable {
                await checkData(force: true)
            }
            .onChange(of: songs.count) { _, _ in
                loadLookups()
            }
        }
    }

    private func loadLookups() {
        do {
            let (a, c) = try dataManager.aliasesAndCharts()
            aliasesBySong = a
            chartsBySong = c
        } catch {
            print("Failed to load lookups: \(error)")
        }
    }

    private func checkData(force: Bool = false) async {
        guard songs.isEmpty || force else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            if AppPreferences.dataVersion == "0" || force {
                let update = try await MaimaiDataService.updateInfo()
                if let url = update.dataUrl4 {
                    try await dataManager.importSongData(from: url)
                    AppPreferences.dataVersion = update.dataVersion4 ?? AppPreferences.dataVersion
                }
            }
            await dataManager.checkAndUpdateChartStatsIfNeeded()
            dataManager.maxNotesStats = try dataManager.maxNotes()
            loadLookups()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct SongRow: View {
    let song: SongData

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(song.bgColorName))
                .frame(width: 6, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(.subheadline)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(song.type)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(Capsule())

                    Text(song.genre)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(song.id))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(AppPreferences.isFavorite(id: String(song.id)) ? "★" : "")")
                    .font(.caption)
                    .foregroundStyle(.yellow)
            }
        }
        .padding(.vertical, 4)
    }
}

extension SongFilter {
    var isActive: Bool {
        !searchText.isEmpty || !selectedGenres.isEmpty || !selectedVersions.isEmpty
            || selectedLevel != nil || sequencing != nil || ds != nil || favoritesOnly
            || !matchAlias || matchCharter || !matchSongId
    }
}

#Preview {
    SongListView()
        .environmentObject(DataManager(inMemory: true))
}
