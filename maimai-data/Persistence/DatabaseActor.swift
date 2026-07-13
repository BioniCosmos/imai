import Foundation
import SwiftData

@ModelActor
actor DatabaseActor {
    init(container: ModelContainer) {
        let context = ModelContext(container)
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: context)
        self.modelContainer = container
    }

    /// Builds the SwiftData models inside this actor's context (so the
    /// relationship graphs resolve correctly), then replaces the store.
    func replaceAllSongsAndCharts(with dtos: [SongDataDTO]) async throws {
        let existingSongs = try modelContext.fetch(FetchDescriptor<SongData>())
        existingSongs.forEach { modelContext.delete($0) }

        for dto in dtos {
            let songId = Int(dto.id) ?? 0

            let song = SongData(
                id: songId,
                title: dto.title,
                titleKana: dto.titleKana,
                artist: dto.basicInfo.artist,
                imageUrl: dto.basicInfo.imageUrl,
                genre: dto.basicInfo.genre,
                catCode: dto.basicInfo.catcode,
                bpm: dto.basicInfo.bpm,
                from: dto.basicInfo.from,
                type: dto.type,
                version: dto.basicInfo.version,
                isNew: dto.basicInfo.isNew,
                kanji: dto.basicInfo.kanji,
                comment: dto.basicInfo.comment,
                buddy: dto.basicInfo.buddy
            )
            modelContext.insert(song)

            let charts: [Chart] = dto.charts.enumerated().map { index, chart in
                let difficultyType = DifficultyType.difficultyType(for: dto.basicInfo.genre, index: index)
                let notes = chart.notes
                let (tap, hold, slide, touch, breakNote) = dto.type == Constants.chartTypeSD
                    ? (notes[safe: 0] ?? 0, notes[safe: 1] ?? 0, notes[safe: 2] ?? 0, 0, notes[safe: 3] ?? 0)
                    : (notes[safe: 0] ?? 0, notes[safe: 1] ?? 0, notes[safe: 2] ?? 0, notes[safe: 3] ?? 0, notes[safe: 4] ?? 0)

                let chartModel = Chart(
                    songId: songId,
                    difficultyType: difficultyType,
                    type: dto.type,
                    ds: dto.ds[safe: index] ?? 0,
                    oldDs: dto.oldDs[safe: index],
                    level: dto.level[safe: index] ?? "",
                    charter: chart.charter,
                    notesTap: tap,
                    notesHold: hold,
                    notesSlide: slide,
                    notesTouch: touch,
                    notesBreak: breakNote,
                    notesTotal: notes.reduce(0, +)
                )
                chartModel.song = song
                modelContext.insert(chartModel)
                return chartModel
            }
            song.charts = charts

            let aliases: [Alias] = (dto.alias ?? []).map { alias in
                let aliasModel = Alias(songId: songId, alias: alias)
                aliasModel.song = song
                modelContext.insert(aliasModel)
                return aliasModel
            }
            song.aliases = aliases
        }

        try modelContext.save()
    }

    func replaceAllRecords(with records: [Record]) async throws {
        let existing = try modelContext.fetch(FetchDescriptor<Record>())
        existing.forEach { modelContext.delete($0) }
        records.forEach { modelContext.insert($0) }
        try modelContext.save()
    }

    func replaceAllChartStats(with stats: [ChartStats]) async throws {
        let existing = try modelContext.fetch(FetchDescriptor<ChartStats>())
        existing.forEach { modelContext.delete($0) }
        stats.forEach { modelContext.insert($0) }
        try modelContext.save()
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private extension DifficultyType {
    static func difficultyType(for genre: String, index: Int) -> DifficultyType {
        if genre == Constants.genreUtage {
            switch index {
            case 0: return .utage
            case 1: return .utagePlayer2
            default: return .unknown
            }
        } else {
            switch index {
            case 0: return .basic
            case 1: return .advanced
            case 2: return .expert
            case 3: return .master
            case 4: return .remaster
            default: return .unknown
            }
        }
    }
}