import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            SongListView()
                .tabItem {
                    Label("歌曲", systemImage: "music.note.list")
                }
                .tag(0)

            RatingView()
                .tabItem {
                    Label("Rating", systemImage: "star")
                }
                .tag(1)

            ProberView()
                .tabItem {
                    Label("B50", systemImage: "trophy")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape")
                }
                .tag(3)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(DataManager(inMemory: true))
}
