import SwiftUI

@main
struct TumbWallApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
        }
        
        Settings {
            SettingsView()
        }
    }
}
