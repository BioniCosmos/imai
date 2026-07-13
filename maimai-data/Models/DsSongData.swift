import Foundation

struct DsSongData: Identifiable {
    let id = UUID()
    let songId: Int
    let title: String
    let type: String
    let imageUrl: String?
    let levelIndex: Int
    let ds: Double
}
