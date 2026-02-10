import SwiftUI

struct SettingsView: View {
    @AppStorage("tumblrApiKey") private var apiKey: String = ""
    @AppStorage("forceScraping") private var forceScraping: Bool = false
    @AppStorage("userAgent") private var userAgent: String = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
    @AppStorage("maxConcurrentDownloads") private var maxConcurrentDownloads: Int = 3
    
    private let presetUserAgents = [
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:109.0) Gecko/20100101 Firefox/115.0"
    ]
    
    var body: some View {
        Form {
            Section(header: Text("Tumblr API")) {
                SecureField("API Key", text: $apiKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Text("Required for API mode. Leave empty to use Scraper.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section(header: Text("Download Engine")) {
                Toggle("Force Scraping", isOn: $forceScraping)
                    .toggleStyle(SwitchToggleStyle())
                
                Text("If enabled, scraping will be used even if an API Key is present.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section(header: Text("Network")) {
                VStack(alignment: .leading) {
                    Text("User Agent")
                    Picker("", selection: $userAgent) {
                        ForEach(presetUserAgents, id: \.self) { agent in
                            Text(shortName(for: agent)).tag(agent)
                        }
                        Text("Custom").tag(userAgent) // Simple hack to show current if custom
                    }
                    .labelsHidden()
                    
                    TextField("Custom User Agent", text: $userAgent)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                Stepper("Max Concurrent Downloads: \(maxConcurrentDownloads)", value: $maxConcurrentDownloads, in: 1...10)
            }
        }
        .padding()
        .padding()
        .frame(width: 500, height: 450)
    }
    
    private func shortName(for agent: String) -> String {
        if agent.contains("Chrome") { return "Chrome (macOS)" }
        if agent.contains("Firefox") { return "Firefox (macOS)" }
        if agent.contains("Safari") { return "Safari (macOS)" }
        return "Custom"
    }
}
