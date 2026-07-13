import SwiftUI

struct SettingsView: View {
    @State private var enableAliasSearch = AppPreferences.enableAliasSearch
    @State private var enableCharterSearch = AppPreferences.enableCharterSearch
    @State private var enableShowAlias = AppPreferences.enableShowAlias
    @State private var enableDivingFishNickname = AppPreferences.enableDivingFishNickname
    @State private var divingFishNickname = AppPreferences.divingFishNickname

    var body: some View {
        NavigationStack {
            Form {
                Section("搜索") {
                    Toggle("匹配别名", isOn: $enableAliasSearch)
                        .onChange(of: enableAliasSearch) { _, v in AppPreferences.enableAliasSearch = v }
                    Toggle("匹配谱师", isOn: $enableCharterSearch)
                        .onChange(of: enableCharterSearch) { _, v in AppPreferences.enableCharterSearch = v }
                }

                Section("显示") {
                    Toggle("显示别名", isOn: $enableShowAlias)
                        .onChange(of: enableShowAlias) { _, v in AppPreferences.enableShowAlias = v }
                }

                Section("Diving-Fish") {
                    Toggle("使用 Diving-Fish 昵称", isOn: $enableDivingFishNickname)
                        .onChange(of: enableDivingFishNickname) { _, v in
                            AppPreferences.enableDivingFishNickname = v
                        }
                    if enableDivingFishNickname {
                        TextField("昵称", text: $divingFishNickname)
                            .onChange(of: divingFishNickname) { _, v in
                                AppPreferences.divingFishNickname = v
                            }
                    }
                }

                Section("数据") {
                    HStack {
                        Text("当前数据版本")
                        Spacer()
                        Text(AppPreferences.dataVersion)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("账号")
                        Spacer()
                        Text(AppPreferences.username.isEmpty ? "未登录" : AppPreferences.username)
                            .foregroundStyle(.secondary)
                    }
                    if !AppPreferences.username.isEmpty {
                        Button(role: .destructive) {
                            AppPreferences.logout()
                        } label: {
                            Text("登出 / 更换账户")
                                .frame(maxWidth: .infinity)
                        }
                    }
                }

                Section("工具") {
                    NavigationLink {
                        VersionChecklistView()
                    } label: {
                        Label("版本进度", systemImage: "list.bullet.rectangle")
                    }
                    NavigationLink {
                        ChecklistView()
                    } label: {
                        Label("等级进度", systemImage: "chart.bar")
                    }
                    NavigationLink {
                        FinaleToDxView()
                    } label: {
                        Label("DX 分数转换", systemImage: "arrow.triangle.swap")
                    }
                }

                Section("关于") {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("v1.0")
                            .foregroundStyle(.secondary)
                    }
                    Link("Diving-Fish",
                         destination: URL(string: "https://www.diving-fish.com/maimaidx/prober/")!)
                }
            }
            .navigationTitle("设置")
        }
    }
}

#Preview {
    SettingsView()
}
