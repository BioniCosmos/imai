import Foundation
import SwiftData

@MainActor
final class DataManager: ObservableObject {
    static let shared = DataManager()

    let container: ModelContainer
    private let databaseActor: DatabaseActor

    @Published var maxNotesStats: MaxNotesStats?

    init(inMemory: Bool = false) {
        let schema = Schema([
            SongData.self,
            Chart.self,
            Alias.self,
            Record.self,
            ChartStats.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            container = try ModelContainer(for: schema, configurations: [config])
            databaseActor = DatabaseActor(container: container)
        } catch {
            fatalError("Failed to create model container: \(error)")
        }
    }

    var mainContext: ModelContext {
        container.mainContext
    }

    // MARK: - Import

    func importSongData(from urlString: String) async throws {
        let data = try await MaimaiDataService.downloadSongData(from: urlString)
        let dtos = try JSONDecoder().decode([SongDataDTO].self, from: data)
        try await databaseActor.replaceAllSongsAndCharts(with: dtos)
    }

    func replaceAllRecords(with records: [Record]) async throws {
        try await databaseActor.replaceAllRecords(with: records)
    }

    func replaceAllChartStats(with stats: [ChartStats]) async throws {
        try await databaseActor.replaceAllChartStats(with: stats)
    }

    // MARK: - Queries

    func allSongs(includeUtage: Bool = false) throws -> [SongData] {
        var descriptor = FetchDescriptor<SongData>(
            sortBy: [SortDescriptor(\.id, order: .reverse)]
        )
        if !includeUtage {
            let utage = Constants.genreUtage
            descriptor.predicate = #Predicate { $0.genre != utage }
        }
        return try mainContext.fetch(descriptor)
    }

    func song(withId id: Int) throws -> SongData? {
        let descriptor = FetchDescriptor<SongData>(
            predicate: #Predicate { $0.id == id }
        )
        return try mainContext.fetch(descriptor).first
    }

    func charts(for songId: Int) throws -> [Chart] {
        let descriptor = FetchDescriptor<Chart>(
            predicate: #Predicate { $0.songId == songId }
        )
        return try mainContext.fetch(descriptor)
            .sorted { $0.difficultyType.index < $1.difficultyType.index }
    }

    func aliases(for songId: Int) throws -> [Alias] {
        let descriptor = FetchDescriptor<Alias>(
            predicate: #Predicate { $0.songId == songId }
        )
        return try mainContext.fetch(descriptor)    }

    func records(for songId: Int) throws -> [Record] {
        let descriptor = FetchDescriptor<Record>(
            predicate: #Predicate { $0.songId == songId }
        )
        return try mainContext.fetch(descriptor)
    }

    func allRecords() throws -> [Record] {
        let descriptor = FetchDescriptor<Record>()
        return try mainContext.fetch(descriptor)
    }

    func chartStats(for songId: Int, levelIndex: Int) throws -> ChartStats? {
        let descriptor = FetchDescriptor<ChartStats>(
            predicate: #Predicate { $0.songId == songId && $0.levelIndex == levelIndex }
        )
        return try mainContext.fetch(descriptor).first
    }

    func maxNotes() throws -> MaxNotesStats? {
        let charts = try mainContext.fetch(FetchDescriptor<Chart>())
        let maxes = charts.reduce(into: (tap: 0, hold: 0, slide: 0, touch: 0, break_: 0)) { result, chart in
            result.tap = max(result.tap, chart.notesTap)
            result.hold = max(result.hold, chart.notesHold)
            result.slide = max(result.slide, chart.notesSlide)
            result.touch = max(result.touch, chart.notesTouch)
            result.break_ = max(result.break_, chart.notesBreak)
        }
        return MaxNotesStats(
            tap: maxes.tap,
            hold: maxes.hold,
            slide: maxes.slide,
            touch: maxes.touch,
            break_: maxes.break_,
            total: maxes.tap + maxes.hold + maxes.slide + maxes.touch + maxes.break_
        )
    }

    /// Returns every distinct `from` value present in the database, sorted
    /// in the same order as the Android checkbox list (oldest version first,
    /// newest last).
    func distinctVersions() throws -> [String] {
        let songs = try mainContext.fetch(FetchDescriptor<SongData>())
        let set = Set(songs.map { $0.from })
        return Self.orderedVersions(from: set)
    }

    static let versionOrder: [String] = [
        "maimai",
        "maimai PLUS",
        "maimai GreeN",
        "maimai GreeN PLUS",
        "maimai ORANGE",
        "maimai ORANGE PLUS",
        "maimai PiNK",
        "maimai PiNK PLUS",
        "maimai MURASAKi",
        "maimai MURASAKi PLUS",
        "maimai MiLK",
        "maimai MiLK PLUS",
        "maimai FiNALE",
        "舞萌DX",
        "舞萌DX 2021",
        "舞萌DX 2022",
        "舞萌DX 2023",
        "舞萌DX 2024",
        "舞萌DX 2025",
        "舞萌DX 2026"
    ]

    /// Returns pre-built lookup maps: `songId → [alias]` and
    /// `songId → [ChartSummary]`. Used by `SongSearcher` for level / ds /
    /// alias / charter matching, since SwiftData does not auto-load
    /// to-many inverse relationships during `@Query` fetches.
    func aliasesAndCharts() throws -> (aliases: [Int: [String]], charts: [Int: [ChartSummary]]) {
        let aliases = try mainContext.fetch(FetchDescriptor<Alias>())
        let aliasMap = aliases.reduce(into: [Int: [String]]()) { $0[$1.songId, default: []].append($1.alias) }

        let charts = try mainContext.fetch(FetchDescriptor<Chart>())
        let chartMap = charts.reduce(into: [Int: [ChartSummary]]()) {
            $0[$1.songId, default: []].append(ChartSummary(
                level: $1.level,
                ds: $1.ds,
                difficultyType: $1.difficultyType,
                charter: $1.charter
            ))
        }

        return (aliasMap, chartMap)
    }

    /// Returns a map of `songId → isNew` for the local song database, used
    /// by `ProberView` to split records into old (B35) and new (B15) sets.
    func isNewMap() throws -> [Int: Bool] {
        let songs = try mainContext.fetch(FetchDescriptor<SongData>())
        return songs.reduce(into: [Int: Bool]()) { $0[$1.id] = $1.isNew }
    }

    static func orderedVersions(from set: Set<String>) -> [String] {
        let known = versionOrder.filter { set.contains($0) }
        let unknown = set.subtracting(versionOrder).sorted()
        return known + unknown
    }

    // MARK: - Update checks

    func checkAndUpdateDataIfNeeded() async {
        do {
            let update = try await MaimaiDataService.updateInfo()
            guard let remoteVersion = update.dataVersion4,
                  remoteVersion > AppPreferences.dataVersion,
                  let url = update.dataUrl4 else { return }
            try await importSongData(from: url)
            AppPreferences.dataVersion = remoteVersion
        } catch {
            print("Data update failed: \(error)")
        }
    }

    func checkAndUpdateChartStatsIfNeeded() async {
        let last = AppPreferences.lastChartStatsUpdate
        let now = Date().timeIntervalSince1970 * 1000
        let fiveDays: TimeInterval = 5 * 24 * 60 * 60 * 1000
        guard now - last >= fiveDays else { return }

        do {
            let response = try await MaimaiDataService.chartStats()
            let stats = JsonConvertToDb.convertChartStats(response)
            try await databaseActor.replaceAllChartStats(with: stats)
            AppPreferences.lastChartStatsUpdate = now
        } catch {
            print("Chart stats update failed: \(error)")
        }
    }
}
