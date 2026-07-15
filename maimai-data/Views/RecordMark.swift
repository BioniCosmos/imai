import SwiftUI

/// Shared mark/badge used by VersionChecklistView and ChecklistView.
struct RecordMark: View {
    let record: Record
    let displayMode: Int

    var body: some View {
        switch displayMode {
        case 0:
            badge(record.rate, color: rateColor(record.rate))
        case 1:
            badge(record.fc, color: fcColor(record.fc))
        case 2:
            badge(record.fs, color: fsColor(record.fs))
        default:
            EmptyView()
        }
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 3)
            .background(color)
            .cornerRadius(3)
    }
}

/// Shared icon for the rank/fc/fs display-mode toggle.
func displayModeIcon(_ displayMode: Int) -> String {
    switch displayMode {
    case 0: return "star"
    case 1: return "music.note"
    case 2: return "sparkles"
    default: return "star"
    }
}

private func rateColor(_ rate: String) -> Color {
    switch rate {
    case "sssp": return .yellow
    case "sss": return .orange
    case "ssp": return .pink
    case "ss": return .red
    case "sp": return .purple
    case "s": return .blue
    default: return .gray
    }
}

private func fcColor(_ fc: String) -> Color {
    switch fc {
    case "app": return .yellow
    case "ap": return .orange
    case "fcp": return .green
    case "fc": return .blue
    default: return .gray
    }
}

private func fsColor(_ fs: String) -> Color {
    switch fs {
    case "fsdp": return .yellow
    case "fsd": return .orange
    case "fsp": return .green
    case "fs": return .blue
    default: return .gray
    }
}
