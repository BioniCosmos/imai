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
                let sequencingType = difficultyPrefix(for: filter.sequencing)
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
        if let sequencing = filter.sequencing, sequencing != "默认排序" {
            switch sequencing {
            case "EXPERT-升序":
                return result.sorted { dsFor($0, .expert, chartsBySong) < dsFor($1, .expert, chartsBySong) }
            case "EXPERT-降序":
                return result.sorted { dsFor($0, .expert, chartsBySong) > dsFor($1, .expert, chartsBySong) }
            case "MASTER-升序":
                return result.sorted { dsFor($0, .master, chartsBySong) < dsFor($1, .master, chartsBySong) }
            case "MASTER-降序":
                return result.sorted { dsFor($0, .master, chartsBySong) > dsFor($1, .master, chartsBySong) }
            case "RE:MASTER-升序":
                return result.sorted { remasterValue($0, chartsBySong) < remasterValue($1, chartsBySong) }
            case "RE:MASTER-降序":
                return result.sorted { remasterValue($0, chartsBySong) > remasterValue($1, chartsBySong) }
            default:
                return result.sorted { $0.id > $1.id }
            }
        } else {
            return result.sorted { $0.id > $1.id }
        }
    }

    private static func difficultyPrefix(for sequencing: String?) -> DifficultyType? {
        guard let sequencing else { return nil }
        if sequencing.hasPrefix("EXPERT") { return .expert }
        if sequencing.hasPrefix("MASTER") { return .master }
        if sequencing.hasPrefix("RE:MASTER") { return .remaster }
        return nil
    }

    private static func dsFor(_ song: SongData, _ type: DifficultyType, _ chartsBySong: [Int: [ChartSummary]]) -> Double {
        chartsBySong[song.id]?.first { $0.difficultyType == type }?.ds ?? 0
    }

    private static func remasterValue(_ song: SongData, _ chartsBySong: [Int: [ChartSummary]]) -> Double {
        let charts = chartsBySong[song.id] ?? []
        guard let remaster = charts.first(where: { $0.difficultyType == .remaster }) else {
            return -1
        }
        return remaster.ds
    }
}