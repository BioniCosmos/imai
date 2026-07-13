import Foundation

struct SongDataDTO: Codable, Identifiable {
    let basicInfo: BasicInfo
    let charts: [ChartDTO]
    let ds: [Double]
    let oldDs: [Double]
    let id: String
    let level: [String]
    let title: String
    let titleKana: String
    let type: String
    let alias: [String]?

    enum CodingKeys: String, CodingKey {
        case basicInfo = "basic_info"
        case charts, ds
        case oldDs = "old_ds"
        case id, level, title
        case titleKana = "title_kana"
        case type, alias
    }
}

struct BasicInfo: Codable {
    let artist: String
    let bpm: Int
    let from: String
    let genre: String
    let catcode: String
    let isNew: Bool
    let title: String
    let imageUrl: String
    let version: String
    let kanji: String?
    let comment: String?
    let buddy: String?

    enum CodingKeys: String, CodingKey {
        case artist, bpm, from, genre, catcode
        case isNew = "is_new"
        case title
        case imageUrl = "image_url"
        case version, kanji, comment, buddy
    }
}

struct ChartDTO: Codable {
    let charter: String
    let notes: [Int]
}
