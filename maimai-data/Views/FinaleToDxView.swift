import SwiftUI

/// Port of `FinaleToDxActivity` — converts between achievement percentage and
/// DX score by entering note counts for each judgement type.
struct NoteSectionState {
    var perfect = ""
    var great = ""
    var good = ""
    var miss = ""

    var counts: (perfect: Int, great: Int, good: Int, miss: Int, total: Int) {
        let p = Int(perfect) ?? 0
        let g = Int(great) ?? 0
        let gd = Int(good) ?? 0
        let m = Int(miss) ?? 0
        return (p, g, gd, m, p + g + gd + m)
    }
}

struct FinaleToDxView: View {
    @State private var tap = NoteSectionState()
    @State private var hold = NoteSectionState()
    @State private var slide = NoteSectionState()
    @State private var breakNotes = NoteSectionState()
    @State private var breakScore = ""

    @State private var resultText: String?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                noteSection(title: "TAP", icon: "circle.fill", color: .blue, state: $tap)
                noteSection(title: "HOLD", icon: "rectangle.fill", color: .green, state: $hold)
                noteSection(title: "SLIDE", icon: "star.fill", color: .orange, state: $slide)
                noteSection(title: "BREAK", icon: "diamond.fill", color: .red, state: $breakNotes)

                breakScoreInput
                calculateButton
                resultView
                errorView
            }
            .padding(.vertical)
        }
        .navigationTitle("DX 分数转换")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var breakScoreInput: some View {
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
    }

    private var calculateButton: some View {
        Button {
            calculate()
        } label: {
            Text("计算")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .padding(.horizontal)
    }

    @ViewBuilder
    private var resultView: some View {
        if let result = resultText {
            Text(result)
                .font(.title3.bold())
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var errorView: some View {
        if let error = errorMessage {
            Text(error)
                .foregroundStyle(.red)
                .font(.caption)
        }
    }

    private func noteSection(title: String, icon: String, color: Color, state: Binding<NoteSectionState>) -> some View {
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
                judgementField(label: "Perfect", text: state.perfect)
                judgementField(label: "Great", text: state.great)
                judgementField(label: "Good", text: state.good)
                judgementField(label: "Miss", text: state.miss)
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

        let tap = tap.counts
        let hold = hold.counts
        let slide = slide.counts
        let breakNotes = breakNotes.counts
        let bs = Int(breakScore) ?? 0

        guard tap.total + hold.total + slide.total + breakNotes.total > 0 else {
            errorMessage = "请至少输入一组 note 数量"
            return
        }

        let dxTotalScore = tap.total * 10 + hold.total * 20 + slide.total * 30 + breakNotes.total * 50

        let dxPlayMaxScore =
            tap.perfect * 10 + tap.great * 8 + tap.good * 5 +
            hold.perfect * 20 + hold.great * 16 + hold.good * 10 +
            slide.perfect * 30 + slide.great * 24 + slide.good * 15 +
            breakNotes.perfect * 50 + breakNotes.great * 40 + breakNotes.good * 20

        let dxPlayMinScore =
            tap.perfect * 10 + tap.great * 8 + tap.good * 5 +
            hold.perfect * 20 + hold.great * 16 + hold.good * 10 +
            slide.perfect * 30 + slide.great * 24 + slide.good * 15 +
            breakNotes.perfect * 50 + breakNotes.great * 25 + breakNotes.good * 20

        guard dxTotalScore > 0 else {
            errorMessage = "总 note 数不能为 0"
            return
        }

        if bs == 0 {
            guard breakNotes.total > 0 else {
                errorMessage = "请输入 BREAK 数量"
                return
            }
            let breakRatio = 1.0 / Double(breakNotes.total)
            let dxMaxScore = Double(dxPlayMaxScore) / Double(dxTotalScore) * 100.0
                + Double(breakNotes.perfect) * breakRatio * 1.0
                + Double(breakNotes.great) * breakRatio * 0.4
                + Double(breakNotes.good) * breakRatio * 0.3

            let dxMinScore = Double(dxPlayMinScore) / Double(dxTotalScore) * 100.0
                + Double(breakNotes.perfect) * breakRatio * 0.5
                + Double(breakNotes.great) * breakRatio * 0.4
                + Double(breakNotes.good) * breakRatio * 0.3

            resultText = String(format: "达成率: %.4f%% ~ %.4f%%", dxMinScore, dxMaxScore)
        } else {
            if breakNotes.great > 0 || breakNotes.good > 0 || breakNotes.miss > 0
                || breakNotes.perfect * 2600 < bs || breakNotes.perfect * 2500 > bs {
                errorMessage = "绝赞数据错误，请重新填写"
                return
            }
            guard breakNotes.total > 0 else {
                errorMessage = "请输入 BREAK 数量"
                return
            }
            let dxBreakScore = 1.0 - 0.25 * Double(breakNotes.total * 2600 - bs) / 50.0 / Double(breakNotes.total)
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
