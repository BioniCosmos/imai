import Foundation
import SwiftData

@Model
final class ChartStats {
    @Attribute(.unique) var id: UUID
    var songId: Int
    var cnt: Double?
    var diff: String?
    var levelIndex: Int
    var fitDiff: Double?
    var avg: Double?
    var avgDx: Double?
    var stdDev: Double?
    var dist: [Int]?
    var fcDist: [Int]?

    init(
        id: UUID = UUID(),
        songId: Int,
        cnt: Double? = nil,
        diff: String? = nil,
        levelIndex: Int,
        fitDiff: Double? = nil,
        avg: Double? = nil,
        avgDx: Double? = nil,
        stdDev: Double? = nil,
        dist: [Int]? = nil,
        fcDist: [Int]? = nil
    ) {
        self.id = id
        self.songId = songId
        self.cnt = cnt
        self.diff = diff
        self.levelIndex = levelIndex
        self.fitDiff = fitDiff
        self.avg = avg
        self.avgDx = avgDx
        self.stdDev = stdDev
        self.dist = dist
        self.fcDist = fcDist
    }
}
