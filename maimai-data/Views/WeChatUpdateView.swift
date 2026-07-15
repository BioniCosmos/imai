import SwiftUI

/// Uploads maimai DX score data to Diving-Fish via the wahlap proxy server.
///
/// Flow:
/// 1. POST /api/tasks → get task_id
/// 2. User copies https://server/tasks/{task_id} → opens in WeChat
/// 3. WeChat OAuth completes → server intercepts callback → fetches + uploads
/// 4. App polls GET /api/tasks/{task_id} until completed
/// 5. App refreshes Diving-Fish B50 data
struct WeChatUpdateView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var username: String = AppPreferences.username
    @State private var password: String = AppPreferences.password
    @State private var selectedDifficulties: Set<Int> = [0, 1, 2, 3, 4]

    @State private var state: UpdateState = .idle
    @State private var taskId: String?
    @State private var results: [WahlapService.DifficultyResult]?
    @State private var errorMessage: String?

    private let difficultyNames = ["Basic", "Advanced", "Expert", "Master", "Re:Master"]

    enum UpdateState {
        case idle
        case creatingTask
        case waitingForWeChat(taskId: String, url: String)
        case polling(taskId: String)
        case completed
        case failed(String)
    }

    var body: some View {
        NavigationStack {
            Form {
                credentialsSection
                difficultiesSection
                actionSection
                statusSection
            }
            .navigationTitle("上传成绩")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var credentialsSection: some View {
        Section("Diving-Fish 账号") {
            TextField("用户名", text: $username)
                .textContentType(.username)
                .autocapitalization(.none)
                .disableAutocorrection(true)

            SecureField("密码", text: $password)
                .textContentType(.password)
        }
    }

    @ViewBuilder
    private var difficultiesSection: some View {
        Section("更新难度") {
            ForEach(Array(difficultyNames.enumerated()), id: \.offset) { index, name in
                Toggle(name, isOn: Binding(
                    get: { selectedDifficulties.contains(index) },
                    set: { selectedDifficulties.toggle(index, to: $0) }
                ))
            }
        }
    }

    @ViewBuilder
    private var actionSection: some View {
        Section {
            switch state {
            case .idle:
                Button(action: startUpdate) {
                    HStack {
                        Spacer()
                        Label("开始上传", systemImage: "arrow.up.circle")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
                .disabled(username.isEmpty || password.isEmpty || selectedDifficulties.isEmpty)

            case .creatingTask:
                HStack {
                    ProgressView()
                    Text("正在创建任务...")
                        .foregroundStyle(.secondary)
                }

            case .waitingForWeChat(let taskId, let url):
                VStack(alignment: .leading, spacing: 8) {
                    Text("请在微信中打开以下链接：")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(url)
                        .font(.caption.monospaced())
                        .padding(8)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    Button(action: { UIPasteboard.general.string = url }) {
                        Label("复制链接", systemImage: "doc.on.doc")
                    }

                    Button(action: { startPolling(taskId: taskId) }) {
                        Label("已在微信中打开", systemImage: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                }

            case .polling:
                HStack {
                    ProgressView()
                    Text("正在等待服务器处理...")
                        .foregroundStyle(.secondary)
                }

            case .completed:
                Label("上传完成", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)

            case .failed(let msg):
                VStack(alignment: .leading, spacing: 8) {
                    Label("上传失败", systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("重试") {
                        state = .idle
                        errorMessage = nil
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        if let results, !results.isEmpty {
            Section("上传结果") {
                ForEach(results.sorted(by: { $0.difficulty < $1.difficulty }), id: \.difficulty) { result in
                    HStack {
                        Text(result.name)
                        Spacer()
                        if result.status == "success" {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func startUpdate() {
        state = .creatingTask
        errorMessage = nil
        results = nil

        let diffs = Array(selectedDifficulties).sorted()
        let uname = username
        let pwd = password

        Task {
            do {
                let response = try await WahlapService.createTask(
                    username: uname,
                    password: pwd,
                    difficulties: diffs
                )
                let id = response.taskId
                let url = Constants.wechatEntryURL(taskId: id).absoluteString
                taskId = id
                await MainActor.run {
                    state = .waitingForWeChat(taskId: id, url: url)
                }
            } catch {
                await MainActor.run {
                    state = .failed(error.localizedDescription)
                }
            }
        }
    }

    private func startPolling(taskId: String) {
        state = .polling(taskId: taskId)

        Task {
            do {
                let status = try await WahlapService.waitForTask(id: taskId)
                await MainActor.run {
                    results = status.results
                    if status.state == "completed" {
                        state = .completed
                        // Refresh Diving-Fish data in the background.
                        Task {
                            try? await Task.sleep(nanoseconds: 2_000_000_000)
                            // Trigger B50 refresh via notification.
                            NotificationCenter.default.post(
                                name: .wahlapUploadCompleted,
                                object: nil
                            )
                        }
                    } else {
                        state = .failed(status.errorMessage ?? "未知错误")
                    }
                }
            } catch {
                await MainActor.run {
                    state = .failed(error.localizedDescription)
                }
            }
        }
    }
}

private extension Set {
    mutating func toggle(_ element: Element, to selected: Bool) {
        if selected {
            insert(element)
        } else {
            remove(element)
        }
    }
}

// MARK: - Notification

extension Notification.Name {
    static let wahlapUploadCompleted = Notification.Name("wahlapUploadCompleted")
}

#Preview {
    WeChatUpdateView()
}
