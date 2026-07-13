import Foundation

struct SongFilter {
    var searchText: String = ""
    var selectedGenres: Set<String> = []
    var selectedVersions: Set<String> = []
    var selectedLevel: String? = nil
    var sequencing: String? = nil
    var ds: Double? = nil
    var favoritesOnly: Bool = false
    var matchAlias: Bool = true
    var matchCharter: Bool = false
    var matchSongId: Bool = true
}

extension SongFilter {
    /// Genre checkbox labels — these equal the `genre` values stored in the
    /// song data.
    static let allGenres = [
        "流行&动漫",
        "niconico & VOCALOID",
        "东方Project",
        "其他游戏",
        "舞萌",
        "音击&中二节奏",
        "宴会場"
    ]

    static let allLevels = [
        "1", "2", "3", "4", "5", "6", "7", "7+", "8", "8+",
        "9", "9+", "10", "10+", "11", "11+", "12", "12+", "13", "13+", "14", "14+", "15"
    ]

    static let sequencingOptions = [
        "默认排序",
        "EXPERT-升序", "EXPERT-降序",
        "MASTER-升序", "MASTER-降序",
        "RE:MASTER-升序", "RE:MASTER-降序"
    ]
}