import Foundation

/// Diving-Fish's record JSON occasionally omits some fields (e.g. `dx_score`,
/// `level_label`, `level`) for individual records, so every property is
/// optional and decoded with a safe fallback.
struct RecordDTO: Codable {
    let achievements: Double?
    let ds: Double?
    let dxScore: Int?
    let fc: String?
    let fs: String?
    let level: String?
    let levelIndex: Int?
    let levelLabel: String?
    let ra: Int?
    let rate: String?
    let songId: Int?
    let title: String?
    let type: String?

    enum CodingKeys: String, CodingKey {
        case achievements, ds
        case dxScore = "dx_score"
        case fc, fs, level
        case levelIndex = "level_index"
        case levelLabel = "level_label"
        case ra, rate
        case songId = "song_id"
        case title, type
    }
}

extension RecordDTO {
    func toRecord() -> Record {
        Record(
            achievements: achievements ?? 0,
            ds: ds ?? 0,
            dxScore: dxScore ?? 0,
            fc: fc ?? "",
            fs: fs ?? "",
            level: level ?? "",
            levelIndex: levelIndex ?? 0,
            levelLabel: levelLabel ?? "",
            ra: ra ?? 0,
            rate: rate ?? "",
            songId: songId ?? 0,
            title: title ?? "",
            type: type ?? ""
        )
    }
}