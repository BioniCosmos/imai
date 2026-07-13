import Foundation

struct MaxNotesStats: Codable {
    let tap: Int
    let hold: Int
    let slide: Int
    let touch: Int
    let break_: Int
    let total: Int

    enum CodingKeys: String, CodingKey {
        case tap, hold, slide, touch
        case break_ = "break"
        case total
    }
}
