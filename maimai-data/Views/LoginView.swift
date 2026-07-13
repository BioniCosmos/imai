import SwiftUI

struct LoginView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var username = AppPreferences.username
    @State private var password = AppPreferences.password
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("账号") {
                    TextField("用户名", text: $username)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    SecureField("密码", text: $password)
                }

                if !AppPreferences.accountHistory.isEmpty {
                    Section("历史账号") {
                        ForEach(AppPreferences.accountHistory, id: \.username) { account in
                            HStack {
                                Text(account.username)
                                Spacer()
                                Button("使用") {
                                    username = account.username
                                    password = account.password
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }

                Section {
                    Button {
                        login()
                    } label: {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("登录")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(username.isEmpty || password.isEmpty || isLoading)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("登录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private func login() {
        Task {
            isLoading = true
            errorMessage = nil
            defer { isLoading = false }

            do {
                let cookie = try await MaimaiDataService.login(username: username, password: password)
                AppPreferences.saveLoginInfo(username: username, password: password, cookie: cookie)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    LoginView()
}
