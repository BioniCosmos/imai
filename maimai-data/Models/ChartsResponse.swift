import Foundation

struct ChartsResponse: Codable {
    let charts: [String: [ChartData]]
}

struct ChartData: Codable {
    let cnt: Double?
    let diff: String?
    let fitDiff: Double?
    let avg: Double?
    let avgDx: Double?
    let stdDev: Double?
    let dist: [Int]?
    let fcDist: [Int]?

    enum CodingKeys: String, CodingKey {
        case cnt, diff, avg
        case fitDiff = "fit_diff"
        case avgDx = "avg_dx"
        case stdDev = "std_dev"
        case dist
        case fcDist = "fc_dist"
    }
}
