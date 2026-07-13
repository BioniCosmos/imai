import Foundation

enum RatingCalculator {
    static func calculateTargetRating(_ targetRating: Int) -> [Rating] {
        let rating = targetRating / 50
        let minLevel = max(10, min(150, getReachableLevel(rating: rating)))
        var map: [Int: Int] = [:]

        for level in (minLevel...150).reversed() {
            let achievement = getReachableAchievement(level: level, rating: rating)
            switch achievement {
            case 800_000, 900_000, 940_000:
                map[achievement] = level
            case 970_000...1_010_000:
                map[achievement] = level
            default:
                break
            }
        }

        return map.map { achievement, level in
            let r = ConvertUtils.achievementToRating(level: level, achievement: achievement)
            return Rating(
                innerLevel: Float(level) / 10,
                achievement: String(format: "%.4f%%", Float(achievement) / 10000),
                rating: r,
                total: r * 50
            )
        }.sorted { $0.innerLevel > $1.innerLevel }
    }

    private static func getReachableLevel(rating: Int) -> Int {
        for level in 10...150 {
            if rating < ConvertUtils.achievementToRating(level: level, achievement: 1_005_000) {
                return level
            }
        }
        return 0
    }

    private static func getReachableAchievement(level: Int, rating: Int) -> Int {
        var maxAchi = 1_010_000
        var minAchi = 0

        if ConvertUtils.achievementToRating(level: level, achievement: 1_005_000) < rating {
            return 1_010_001
        }

        for _ in 0..<20 {
            if maxAchi - minAchi >= 2 {
                let tempAchi = Int(floor((Double(maxAchi) + Double(minAchi)) / 2))
                if ConvertUtils.achievementToRating(level: level, achievement: tempAchi) < rating {
                    minAchi = tempAchi
                } else {
                    maxAchi = tempAchi
                }
            }
        }
        return maxAchi
    }
}
