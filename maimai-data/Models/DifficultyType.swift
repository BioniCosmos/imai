import SwiftUI

enum DifficultyType: String, Codable, CaseIterable, Identifiable {
    case basic = "BASIC"
    case advanced = "ADVANCED"
    case expert = "EXPERT"
    case master = "MASTER"
    case remaster = "REMASTER"
    case utage = "UTAGE"
    case utagePlayer2 = "UTAGE_PLAYER2"
    case unknown = "UNKNOWN"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .basic: return "BAS"
        case .advanced: return "ADV"
        case .expert: return "EXP"
        case .master: return "MAS"
        case .remaster: return "Re:MAS"
        case .utage: return "宴会場"
        case .utagePlayer2: return "2p"
        case .unknown: return "?"
        }
    }

    var index: Int {
        switch self {
        case .basic: return 0
        case .advanced: return 1
        case .expert: return 2
        case .master: return 3
        case .remaster: return 4
        case .utage: return 0
        case .utagePlayer2: return 1
        case .unknown: return -1
        }
    }

    var color: Color {
        switch self {
        case .basic: return .basic
        case .advanced: return .advanced
        case .expert: return .expert
        case .master: return .master
        case .remaster: return .remaster
        case .utage, .utagePlayer2: return .levelUtage
        case .unknown: return .gray
        }
    }
}
