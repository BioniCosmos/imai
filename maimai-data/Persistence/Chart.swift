import Foundation
import SwiftData

@Model
final class Chart {
    @Attribute(.unique) var id: UUID
    var songId: Int
    var difficultyType: DifficultyType
    var type: String
    var ds: Double
    var oldDs: Double?
    var level: String
    var charter: String
    var notesTap: Int
    var notesHold: Int
    var notesSlide: Int
    var notesTouch: Int
    var notesBreak: Int
    var notesTotal: Int

    var song: SongData?

    init(
        id: UUID = UUID(),
        songId: Int,
        difficultyType: DifficultyType,
        type: String,
        ds: Double,
        oldDs: Double? = nil,
        level: String,
        charter: String,
        notesTap: Int,
        notesHold: Int,
        notesSlide: Int,
        notesTouch: Int,
        notesBreak: Int,
        notesTotal: Int
    ) {
        self.id = id
        self.songId = songId
        self.difficultyType = difficultyType
        self.type = type
        self.ds = ds
        self.oldDs = oldDs
        self.level = level
        self.charter = charter
        self.notesTap = notesTap
        self.notesHold = notesHold
        self.notesSlide = notesSlide
        self.notesTouch = notesTouch
        self.notesBreak = notesBreak
        self.notesTotal = notesTotal
    }
}

extension Chart {
    var notes: [Int] {
        [notesTap, notesHold, notesSlide, notesTouch, notesBreak]
    }
}
