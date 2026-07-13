import Foundation
import SwiftData

@Model
final class Record {
    @Attribute(.unique) var id: UUID
    var achievements: Double
    var ds: Double
    var dxScore: Int
    var fc: String
    var fs: String
    var level: String
    var levelIndex: Int
    var levelLabel: String
    var ra: Int
    var rate: String
    var songId: Int
    var title: String
    var type: String

    init(
        id: UUID = UUID(),
        achievements: Double,
        ds: Double,
        dxScore: Int,
        fc: String,
        fs: String,
        level: String,
        levelIndex: Int,
        levelLabel: String,
        ra: Int,
        rate: String,
        songId: Int,
        title: String,
        type: String
    ) {
        self.id = id
        self.achievements = achievements
        self.ds = ds
        self.dxScore = dxScore
        self.fc = fc
        self.fs = fs
        self.level = level
        self.levelIndex = levelIndex
        self.levelLabel = levelLabel
        self.ra = ra
        self.rate = rate
        self.songId = songId
        self.title = title
        self.type = type
    }
}
