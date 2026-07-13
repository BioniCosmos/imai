import Foundation

enum ConvertUtils {
    /// 通过定数和达成率计算单曲rating
    static func achievementToRating(level: Int, achievement: Int) -> Int {
        let multiplier: Double
        switch achievement {
        case 1_005_000...:
            multiplier = 22.4
        case 1_004_999:
            multiplier = 22.2
        case 1_000_000...:
            multiplier = 21.6
        case 999_999:
            multiplier = 21.4
        case 995_000...:
            multiplier = 21.1
        case 990_000...:
            multiplier = 20.8
        case 980_000...:
            multiplier = 20.3
        case 970_000...:
            multiplier = 20.0
        case 940_000...:
            multiplier = 16.8
        case 900_000...:
            multiplier = 15.2
        case 800_000...:
            multiplier = 13.6
        case 750_000...:
            multiplier = 12.0
        case 700_000...:
            multiplier = 11.2
        case 600_000...:
            multiplier = 9.6
        case 500_000...:
            multiplier = 8.0
        default:
            multiplier = 0.0
        }

        let temp = Double(min(achievement, 1_005_000)) * Double(level) * multiplier
        return Int(temp / 10_000_000)
    }

    static func levelText(from level: String) -> String {
        switch level {
        case "LEVEL 1": return "1"
        case "LEVEL 2": return "2"
        case "LEVEL 3": return "3"
        case "LEVEL 4": return "4"
        case "LEVEL 5": return "5"
        case "LEVEL 6": return "6"
        case "LEVEL 7": return "7"
        case "LEVEL 7+": return "7+"
        case "LEVEL 8": return "8"
        case "LEVEL 8+": return "8+"
        case "LEVEL 9": return "9"
        case "LEVEL 9+": return "9+"
        case "LEVEL 10": return "10"
        case "LEVEL 10+": return "10+"
        case "LEVEL 11": return "11"
        case "LEVEL 11+": return "11+"
        case "LEVEL 12": return "12"
        case "LEVEL 12+": return "12+"
        case "LEVEL 13": return "13"
        case "LEVEL 13+": return "13+"
        case "LEVEL 14": return "14"
        case "LEVEL 14+": return "14+"
        case "LEVEL 15": return "15"
        default: return "0"
        }
    }
}
