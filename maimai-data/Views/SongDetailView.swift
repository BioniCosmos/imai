import SwiftUI
import SwiftData

struct SongDetailView: View {
    @EnvironmentObject private var dataManager: DataManager
    let song: SongData

    @State private var records: [Record] = []
    @State private var aliases: [Alias] = []
    @State private var charts: [Chart] = []

    private var sortedCharts: [Chart] {
        charts.sorted { $0.difficultyType.index < $1.difficultyType.index }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                if !aliases.isEmpty {
                    aliasesSection
                }

                chartsSection
            }
            .padding(.vertical)
        }
        .navigationTitle(song.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadDetails()
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            AsyncImage(url: song.jacketURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.gray.opacity(0.3)
            }
            .frame(width: 100, height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(song.strokeColorName), lineWidth: 3))

            VStack(alignment: .leading, spacing: 6) {
                Text(song.title)
                    .font(.headline)
                    .lineLimit(2)
                Text(song.artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    Label("\(song.bpm)", systemImage: "metronome")
                    Label(song.type, systemImage: "music.note")
                }
                .font(.caption)

                Text("ID: \(song.id)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(song.from)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(song.bgColorName).opacity(0.15))
    }

    private var aliasesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("别名")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            FlowLayout(spacing: 8) {
                ForEach(aliases) { alias in
                    Text(alias.alias)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(song.bgColorName).opacity(0.2))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal)
        }
    }

    private var chartsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("谱面信息")
                .font(.headline)
                .padding(.horizontal)

            ForEach(sortedCharts) { chart in
                ChartRow(chart: chart, record: records.first { $0.levelIndex == chart.difficultyType.index })
                    .padding(.horizontal)
            }
        }
    }

    private func loadDetails() async {
        do {
            records = try dataManager.records(for: song.id)
            aliases = try dataManager.aliases(for: song.id)
            charts = try dataManager.charts(for: song.id)
        } catch {
            print("Failed to load details: \(error)")
        }
    }
}

struct ChartRow: View {
    let chart: Chart
    let record: Record?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(chart.difficultyType.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(chart.difficultyType.color)

                Spacer()

                Text("Lv \(chart.level)")
                    .font(.subheadline)

                Text(String(format: "定数 %.1f", chart.ds))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("谱师: \(chart.charter)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if chart.notesTotal > 0 {
                HStack(spacing: 8) {
                    NoteBadge(label: "TAP", count: chart.notesTap, color: .blue)
                    NoteBadge(label: "HLD", count: chart.notesHold, color: .green)
                    NoteBadge(label: "SLD", count: chart.notesSlide, color: .orange)
                    if chart.notesTouch > 0 {
                        NoteBadge(label: "TCH", count: chart.notesTouch, color: .purple)
                    }
                    NoteBadge(label: "BRK", count: chart.notesBreak, color: .red)
                }
            }

            if let record = record {
                HStack {
                    Text(String(format: "%.4f%%", record.achievements))
                        .font(.caption.bold())
                    Text("Rating \(record.ra)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct NoteBadge: View {
    let label: String
    let count: Int
    let color: Color

    var body: some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.caption2.bold())
            Text("\(count)")
                .font(.caption2)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.15))
        .foregroundStyle(color)
        .clipShape(Capsule())
    }
}

#Preview {
    NavigationStack {
        SongDetailView(song: SongData(
            id: 1,
            title: "Test Song",
            titleKana: "test",
            artist: "Artist",
            imageUrl: "",
            genre: "流行&动漫",
            catCode: "",
            bpm: 120,
            from: "舞萌DX",
            type: "DX",
            version: "200",
            isNew: true
        ))
    }
    .environmentObject(DataManager(inMemory: true))
}
