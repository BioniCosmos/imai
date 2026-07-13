import SwiftUI

/// Port of `FinaleToDxActivity` — converts between achievement percentage and
/// DX score by entering note counts for each judgement type.
struct FinaleToDxView: View {
    // TAP
    @State private var tapPerfect = ""
    @State private var tapGreat = ""
    @State private var tapGood = ""
    @State private var tapMiss = ""

    // HOLD
    @State private var holdPerfect = ""
    @State private var holdGreat = ""
    @State private var holdGood = ""
    @State private var holdMiss = ""

    // SLIDE
    @State private var slidePerfect = ""
    @State private var slideGreat = ""
    @State private var slideGood = ""
    @State private var slideMiss = ""

    // BREAK
    @State private var breakPerfect = ""
    @State private var breakGreat = ""
    @State private var breakGood = ""
    @State private var breakMiss = ""
    @State private var breakScore = ""

    @State private var resultText: String?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                noteSection(title: "TAP", icon: "circle.fill", color: .blue,
                            perfect: $tapPerfect, great: $tapGreat, good: $tapGood, miss: $tapMiss)

                noteSection(title: "HOLD", icon: "rectangle.fill", color: .green,
                            perfect: $holdPerfect, great: $holdGreat, good: $holdGood, miss: $holdMiss)

                noteSection(title: "SLIDE", icon: "star.fill", color: .orange,
                            perfect: $slidePerfect, great: $slideGreat, good: $slideGood, miss: $slideMiss)

                noteSection(title: "BREAK", icon: "diamond.fill", color: .red,
                            perfect: $breakPerfect, great: $breakGreat, good: $breakGood, miss: $breakMiss)

                // Break score input
                VStack(alignment: .leading, spacing: 4) {
                    Text("BREAK 总分 (可选)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("2600", text: $breakScore)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 200)
                }
                .padding(.horizontal)

                // Calculate button
                Button {
                    calculate()
                } label: {
                    Text("计算")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)

                // Result
                if let result = resultText {
                    Text(result)
                        .font(.title3.bold())
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                }

                if let error = errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("DX 分数转换")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Note Section

    private func noteSection(
        title: String, icon: String, color: Color,
        perfect: Binding<String>, great: Binding<String>, good: Binding<String>, miss: Binding<String>
    ) -> some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)

            HStack(spacing: 8) {
                judgementField(label: "Perfect", text: perfect)
                judgementField(label: "Great", text: great)
                judgementField(label: "Good", text: good)
                judgementField(label: "Miss", text: miss)
            }
            .padding(.horizontal)
        }
    }

    private func judgementField(label: String, text: Binding<String>) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            TextField("0", text: text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 50)
        }
    }

    // MARK: - Calculation

    private func calculate() {
        errorMessage = nil
        resultText = nil

        let tp = Int(tapPerfect) ?? 0
        let tg = Int(tapGreat) ?? 0
        let tgd = Int(tapGood) ?? 0
        let tm = Int(tapMiss) ?? 0

        let hp = Int(holdPerfect) ?? 0
        let hg = Int(holdGreat) ?? 0
        let hgd = Int(holdGood) ?? 0
        let hm = Int(holdMiss) ?? 0

        let sp = Int(slidePerfect) ?? 0
        let sg = Int(slideGreat) ?? 0
        let sgd = Int(slideGood) ?? 0
        let sm = Int(slideMiss) ?? 0

        let bp = Int(breakPerfect) ?? 0
        let bg = Int(breakGreat) ?? 0
        let bgd = Int(breakGood) ?? 0
        let bm = Int(breakMiss) ?? 0
        let bs = Int(breakScore) ?? 0

        let tapCount = tp + tg + tgd + tm
        let holdCount = hp + hg + hgd + hm
        let slideCount = sp + sg + sgd + sm
        let breakCount = bp + bg + bgd + bm

        guard tapCount + holdCount + slideCount + breakCount > 0 else {
            errorMessage = "请至少输入一组 note 数量"
            return
        }

        let dxTotalScore = tapCount * 10 + holdCount * 20 + slideCount * 30 + breakCount * 50

        let dxPlayMaxScore = tp * 10 + tg * 8 + tgd * 5 +
            hp * 20 + hg * 16 + hgd * 10 +
            sp * 30 + sg * 24 + sgd * 15 +
            bp * 50 + bg * 40 + bgd * 20

        let dxPlayMinScore = tp * 10 + tg * 8 + tgd * 5 +
            hp * 20 + hg * 16 + hgd * 10 +
            sp * 30 + sg * 24 + sgd * 15 +
            bp * 50 + bg * 25 + bgd * 20

        guard dxTotalScore > 0 else {
            errorMessage = "总 note 数不能为 0"
            return
        }

        if bs == 0 {
            // No break score provided — show range
            guard breakCount > 0 else {
                errorMessage = "请输入 BREAK 数量"
                return
            }
            let dxMaxScore = Double(dxPlayMaxScore) / Double(dxTotalScore) * 100.0
                + Double(bp) / Double(breakCount) * 1.0
                + Double(bg) / Double(breakCount) * 0.4
                + Double(bgd) / Double(breakCount) * 0.3

            let dxMinScore = Double(dxPlayMinScore) / Double(dxTotalScore) * 100.0
                + Double(bp) / Double(breakCount) * 0.5
                + Double(bg) / Double(breakCount) * 0.4
                + Double(bgd) / Double(breakCount) * 0.3

            resultText = String(format: "达成率: %.4f%% ~ %.4f%%", dxMinScore, dxMaxScore)
        } else {
            // Break score provided — validate and compute exact value
            if bg > 0 || bgd > 0 || bm > 0 || bp * 2600 < bs || bp * 2500 > bs {
                errorMessage = "绝赞数据错误，请重新填写"
                return
            }
            guard breakCount > 0 else {
                errorMessage = "请输入 BREAK 数量"
                return
            }
            let dxBreakScore = 1.0 - 0.25 * Double(breakCount * 2600 - bs) / 50.0 / Double(breakCount)
            let dxCurrentScore = Double(dxPlayMaxScore) / Double(dxTotalScore) * 100.0 + dxBreakScore

            resultText = String(format: "达成率: %.4f%%", dxCurrentScore)
        }
    }
}

#Preview {
    NavigationStack {
        FinaleToDxView()
    }
}
