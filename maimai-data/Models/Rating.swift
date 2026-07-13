import Foundation

struct Rating: Identifiable {
    let id = UUID()
    let innerLevel: Float
    let achievement: String
    let rating: Int
    let total: Int
}
