import Foundation

enum JsonConvertToDb {
    static func convertRecord(from json: Data) throws -> [Record] {
        let decoder = JSONDecoder()
        let dtos = try decoder.decode([RecordDTO].self, from: json)
        return dtos.map { $0.toRecord() }
    }

    static func convertChartStats(_ response: ChartsResponse) -> [ChartStats] {
        response.charts.flatMap { songId, charts in
            charts.enumerated().map { index, data in
                ChartStats(
                    songId: Int(songId) ?? 0,
                    cnt: data.cnt,
                    diff: data.diff,
                    levelIndex: index,
                    fitDiff: data.fitDiff,
                    avg: data.avg,
                    avgDx: data.avgDx,
                    stdDev: data.stdDev,
                    dist: data.dist,
                    fcDist: data.fcDist
                )
            }
        }
    }
}