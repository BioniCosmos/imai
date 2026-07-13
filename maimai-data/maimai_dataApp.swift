import SwiftUI
import SwiftData

@main
struct maimai_dataApp: App {
    let dataManager = DataManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataManager)
                .modelContainer(dataManager.container)
        }
    }
}
