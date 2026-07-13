import Foundation
import SwiftData

@Model
final class Alias {
    @Attribute(.unique) var id: UUID
    var songId: Int
    var alias: String

    var song: SongData?

    init(id: UUID = UUID(), songId: Int, alias: String) {
        self.id = id
        self.songId = songId
        self.alias = alias
    }
}
