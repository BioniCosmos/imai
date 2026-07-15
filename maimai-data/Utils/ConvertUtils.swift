import Foundation

enum ConvertUtils {
    static func achievementToRating(level: Int, achievement: Int) -> Int {
        let multiplier =
            switch achievement {
            case 1_005_000...: 22.4
            case 1_004_999: 22.2
            case 1_000_000...: 21.6
            case 999_999: 21.4
            case 995_000...: 21.1
            case 990_000...: 20.8
            case 989_999: 20.6
            case 980_000...: 20.3
            case 970_000...: 20.0
            case 969_999: 17.6
            case 940_000...: 16.8
            case 900_000...: 15.2
            case 800_000...: 13.6
            case 799_999: 12.8
            case 750_000...: 12.0
            case 700_000...: 11.2
            case 600_000...: 9.6
            case 500_000...: 8.0
            case 400_000...: 6.4
            case 300_000...: 4.8
            case 200_000...: 3.2
            case 100_000...: 1.6
            default: 0.0
            }
        let temp = Double(min(achievement, 1_005_000)) * Double(level) * multiplier
        return Int(temp / 10_000_000)
    }

    static func levelText(from level: String) -> String {
        level.hasPrefix("LEVEL ") ? String(level.dropFirst(6)) : "0"
    }
}
