import SwiftUI

struct RatingView: View {
    @State private var targetRatingText = ""
    @State private var singleLevelText = ""
    @State private var singleAchievementText = ""
    @State private var results: [Rating] = []
    @State private var singleRating: Int = 0

    private var targetRating: Int? {
        Int(targetRatingText)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("单曲 Rating 计算") {
                    HStack {
                        Text("谱面定数")
                        Spacer()
                        TextField("13.5", text: $singleLevelText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    HStack {
                        Text("达成率 (%)")
                        Spacer()
                        TextField("100.0", text: $singleAchievementText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    HStack {
                        Text("单曲 Rating")
                        Spacer()
                        Text("\(singleRating)")
                            .font(.title3.bold())
                    }
                }

                Section("目标 Rating") {
                    HStack {
                        Text("目标值")
                        Spacer()
                        TextField("15200", text: $targetRatingText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }

                    Button("计算推荐配置") {
                        calculate()
                    }
                }

                if !results.isEmpty {
                    Section("结果") {
                        ForEach(results) { rating in
                            HStack {
                                Text(String(format: "%.1f", rating.innerLevel))
                                    .font(.subheadline.bold())
                                Spacer()
                                Text(rating.achievement)
                                    .font(.subheadline)
                                Spacer()
                                Text("\(rating.rating)")
                                    .font(.subheadline)
                                    .foregroundStyle(.blue)
                                Spacer()
                                Text("\(rating.total)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Rating 计算")
            .onChange(of: singleLevelText) { _, _ in updateSingleRating() }
            .onChange(of: singleAchievementText) { _, _ in updateSingleRating() }
        }
    }

    private func updateSingleRating() {
        guard let level = Double(singleLevelText) else { return }
        guard let achievement = Double(singleAchievementText) else { return }
        let levelInt = Int(level * 10)
        let achievementInt = Int(achievement * 10000)
        singleRating = ConvertUtils.achievementToRating(level: levelInt, achievement: achievementInt)
    }

    private func calculate() {
        guard let target = targetRating, target > 0 else { return }
        results = RatingCalculator.calculateTargetRating(target)
    }
}

#Preview {
    RatingView()
}
