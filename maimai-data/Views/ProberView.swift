import SwiftUI
import SwiftData

struct ProberView: View {
    @EnvironmentObject private var dataManager: DataManager
    @State private var oldRecords: [Record] = []
    @State private var newRecords: [Record] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showLogin = false

    /// Total rating for the B35 (old) set. The Android client uses
    /// `level = ds * 10` and `achievement = achievements * 10000` — i.e. it
    /// recomputes RA per record rather than summing the precomputed `ra`
    /// field, which can drift slightly. We do the same.
    private var oldRating: Int { ratingSum(for: oldRecords) }
    private var newRating: Int { ratingSum(for: newRecords) }

    private func ratingSum(for records: [Record]) -> Int {
        records.reduce(0) { sum, record in
            sum + ConvertUtils.achievementToRating(
                level: Int(record.ds * 10),
                achievement: Int(record.achievements * 10000)
            )
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if AppPreferences.cookie.isEmpty {
                    loginPrompt
                } else {
                    recordsContent
                }
            }
            .navigationTitle("B50")
            .sheet(isPresented: $showLogin) {
                LoginView()
            }
            .task {
                await loadRecords()
            }
            .refreshable {
                await loadRecords(force: true)
            }
        }
    }

    private var loginPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("未登录")
                .font(.title2.bold())
            Text("请先登录 Diving-Fish 账号以查看 B50")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("登录") { showLogin = true }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var recordsContent: some View {
        List {
            Section {
                HStack {
                    Text("旧版本 (B35)")
                    Spacer()
                    Text("\(oldRating)")
                        .font(.title2.bold())
                        .foregroundStyle(.blue)
                }
                HStack {
                    Text("新版本 (B15)")
                    Spacer()
                    Text("\(newRating)")
                        .font(.title2.bold())
                        .foregroundStyle(.purple)
                }
                HStack {
                    Text("总计")
                    Spacer()
                    Text("\(oldRating + newRating)")
                        .font(.title2.bold())
                }
            }

            Section {
                Button {
                    Task { await loadRecords(force: true) }
                } label: {
                    if isLoading {
                        HStack {
                            ProgressView()
                            Text("刷新中...")
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        Label("手动刷新 B50 数据", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(isLoading)
            }

            if !oldRecords.isEmpty {
                Section("旧版本 35") {
                    ForEach(oldRecords, id: \.id) { record in
                        RecordRow(record: record)
                    }
                }
            }

            if !newRecords.isEmpty {
                Section("新版本 15") {
                    ForEach(newRecords, id: \.id) { record in
                        RecordRow(record: record)
                    }
                }
            }
        }
        .overlay {
            if isLoading {
                ProgressView()
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func loadRecords(force: Bool = false) async {
        guard !AppPreferences.cookie.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let data = try await MaimaiDataService.records(cookie: AppPreferences.cookie)
            if data.isEmpty {
                throw NetworkError.invalidResponse
            }

            let parsed = try JSONSerialization.jsonObject(with: data)
            guard let json = parsed as? [String: Any] else {
                errorMessage = "响应格式错误 (expected JSON object, got \(type(of: parsed)))"
                return
            }

            if let status = json["status"] as? String, status == "error" {
                errorMessage = "请求出错，请重新登录"
                AppPreferences.cookie = ""
                return
            }

            guard let recordsArray = json["records"] as? [[String: Any]] else {
                errorMessage = "响应中未找到 records 字段"
                return
            }

            let recordData = try JSONSerialization.data(withJSONObject: recordsArray)
            let dtos = try JSONDecoder().decode([RecordDTO].self, from: recordData)
            let newRecordModels = dtos.map { $0.toRecord() }
            try await dataManager.replaceAllRecords(with: newRecordModels)

            // Split into old (B35, !isNew) and new (B15, isNew) using the
            // local song database. Records whose song isn't in the local DB
            // are ignored for the split (matches Android behavior).
            let isNewMap = (try? dataManager.isNewMap()) ?? [:]
            let sorted = newRecordModels.sorted { $0.ra > $1.ra }
            var old = [Record]()
            var new = [Record]()
            for record in sorted {
                guard let isNew = isNewMap[record.songId] else { continue }
                if isNew {
                    if new.count < 15 { new.append(record) }
                } else {
                    if old.count < 35 { old.append(record) }
                }
            }

            oldRecords = old
            newRecords = new
        } catch {
            print("DEBUG loadRecords: catch error=\(error)")
            errorMessage = "请求记录失败: \(error.localizedDescription)"
        }
    }
}

struct RecordRow: View {
    let record: Record

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(record.title)
                    .font(.subheadline)
                Text(record.levelLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(String(format: "%.4f%%", record.achievements))
                    .font(.caption.bold())
                Text("RA \(record.ra)")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
        }
    }
}

#Preview {
    ProberView()
        .environmentObject(DataManager(inMemory: true))
}
