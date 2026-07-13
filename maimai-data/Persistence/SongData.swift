import Foundation
import SwiftData

@Model
final class SongData {
    @Attribute(.unique) var id: Int
    var title: String
    var titleKana: String
    var artist: String
    var imageUrl: String
    var genre: String
    var catCode: String
    var bpm: Int
    var from: String
    var type: String
    var version: String
    var isNew: Bool
    var kanji: String?
    var comment: String?
    var buddy: String?

    @Relationship(deleteRule: .cascade, inverse: \Chart.song)
    var charts: [Chart]?

    @Relationship(deleteRule: .cascade, inverse: \Alias.song)
    var aliases: [Alias]?

    init(
        id: Int,
        title: String,
        titleKana: String,
        artist: String,
        imageUrl: String,
        genre: String,
        catCode: String,
        bpm: Int,
        from: String,
        type: String,
        version: String,
        isNew: Bool,
        kanji: String? = nil,
        comment: String? = nil,
        buddy: String? = nil
    ) {
        self.id = id
        self.title = title
        self.titleKana = titleKana
        self.artist = artist
        self.imageUrl = imageUrl
        self.genre = genre
        self.catCode = catCode
        self.bpm = bpm
        self.from = from
        self.type = type
        self.version = version
        self.isNew = isNew
        self.kanji = kanji
        self.comment = comment
        self.buddy = buddy
    }
}

extension SongData {
    var bgColorName: String {
        switch genre {
        case "流行&动漫": return "pop"
        case "niconico & VOCALOID": return "vocal"
        case "东方Project": return "touhou"
        case "其他游戏": return "variety"
        case "舞萌": return "maimai"
        case Constants.genreUtage: return "utage"
        default: return "gekichuni"
        }
    }

    var strokeColorName: String {
        switch genre {
        case "流行&动漫": return "pop_stroke"
        case "niconico & VOCALOID": return "vocal_stroke"
        case "东方Project": return "touhou_stroke"
        case "其他游戏": return "variety_stroke"
        case "舞萌": return "maimai_stroke"
        case Constants.genreUtage: return "utage_stroke"
        default: return "gekichuni_stroke"
        }
    }

    var jacketURL: URL? {
        URL(string: Constants.imageBaseURL + imageUrl)
    }

    var coverURL: URL? {
        URL(string: Constants.divingFishCoverURL + "\(id).png")
    }
}
