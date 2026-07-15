import Foundation

/// Pre-fetched chart info for one song, used to filter by level / ds /
/// charter without re-querying SwiftData from inside the closure.
struct ChartSummary {
    let level: String
    let ds: Double
    let difficultyType: DifficultyType
    let charter: String
}

enum SongSearcher {
    /// Filter the given songs by the filter, using `aliasesBySong` and
    /// `chartsBySong` for alias / level / ds / charter matching.
    ///
    /// SwiftData does not auto-load to-many inverse relationships on every
    /// song during a `@Query` fetch, so `song.aliases` and `song.charts`
    /// may be empty even when the data exists. The caller is expected to
    /// pre-fetch these once and pass them in.
    static func filter(
        songs: [SongData],
        filter: SongFilter,
        aliasesBySong: [Int: [String]] = [:],
        chartsBySong: [Int: [ChartSummary]] = [:]
    ) -> [SongData] {
        let text = filter.searchText.trimmingCharacters(in: .whitespaces)
        let isSearchEmpty = text.isEmpty

        let result = songs.filter { song in
            // Genre: exact membership (Android: genre IN genreList).
            if !filter.selectedGenres.isEmpty, !filter.selectedGenres.contains(song.genre) {
                return false
            }

            // Version: `from` must be in the selected version list. The list
            // contains actual `from` values (e.g. "maimai GreeN", "maimai
            // GreeN PLUS", "舞萌DX 2026"), so no expansion is needed.
            if !filter.selectedVersions.isEmpty, !filter.selectedVersions.contains(song.from) {
                return false
            }

            // Favorites.
            if filter.favoritesOnly, !AppPreferences.isFavorite(id: String(song.id)) {
                return false
            }

            // Level: at least one chart has this level (optionally restricted
            // to the sequencing difficulty type).
            if let level = filter.selectedLevel {
                let sequencingType = filter.sequencing.flatMap(difficultyPrefix)
                let charts = chartsBySong[song.id] ?? []
                let hasLevel = charts.contains { chart in
                    if level != "ALL", chart.level != level { return false }
                    if let seq = sequencingType, chart.difficultyType != seq { return false }
                    return true
                }
                if !hasLevel { return false }
            }

            // DS: at least one chart has this ds.
            if let ds = filter.ds {
                let charts = chartsBySong[song.id] ?? []
                if !charts.contains(where: { abs($0.ds - ds) < 0.001 }) {
                    return false
                }
            }

            // Text search.
            if isSearchEmpty { return true }

            let lower = text.lowercased()

            if song.title.lowercased().contains(lower) || song.titleKana.lowercased().contains(lower) {
                return true
            }

            if filter.matchSongId, String(song.id) == text {
                return true
            }

            if filter.matchAlias, let aliases = aliasesBySong[song.id] {
                if aliases.contains(where: { $0.lowercased().contains(lower) }) {
                    return true
                }
            }

            if filter.matchCharter, let charts = chartsBySong[song.id] {
                if charts.contains(where: { $0.charter.lowercased().contains(lower) }) {
                    return true
                }
            }

            return false
        }

        // Sorting
        guard let sequencing = filter.sequencing, sequencing != "默认排序" else {
            return result.sorted { $0.id > $1.id }
        }

        let ascending = sequencing.hasSuffix("升序")
        let value: (SongData) -> Double = {
            if sequencing.hasPrefix("RE:MASTER") {
                return remasterValue($0, chartsBySong)
            }
            return dsFor($0, difficultyPrefix(for: sequencing) ?? .unknown, chartsBySong)
        }
        return result.sorted { ascending ? value($0) < value($1) : value($0) > value($1) }
    }

    private static func difficultyPrefix(for sequencing: String) -> DifficultyType? {
        if sequencing.hasPrefix("EXPERT") { return .expert }
        if sequencing.hasPrefix("MASTER") { return .master }
        if sequencing.hasPrefix("RE:MASTER") { return .remaster }
        return nil
    }

    private static func dsFor(_ song: SongData, _ type: DifficultyType, _ chartsBySong: [Int: [ChartSummary]]) -> Double {
        chartsBySong[song.id]?.first { $0.difficultyType == type }?.ds ?? 0
    }

    private static func remasterValue(_ song: SongData, _ chartsBySong: [Int: [ChartSummary]]) -> Double {
        chartsBySong[song.id]?.first { $0.difficultyType == .remaster }?.ds ?? -1
    }
}