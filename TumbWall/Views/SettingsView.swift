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
        TabView {
            generalSettings
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 520, height: 500)
    }
    
    private var generalSettings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // MARK: - Tumblr API Section
                settingsSection(
                    icon: "key.fill",
                    title: "Tumblr API",
                    iconColor: .orange
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("API Key")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            SecureField("Enter your Tumblr API key", text: $apiKey)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        Text("Required for API mode. Leave empty to use the Scraper engine.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // MARK: - Download Engine Section
                settingsSection(
                    icon: "gear.badge",
                    title: "Download Engine",
                    iconColor: .blue
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Force Scraping")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("Use scraping even if an API Key is configured.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: $forceScraping)
                                .toggleStyle(.switch)
                                .labelsHidden()
                        }
                    }
                }
                
                // MARK: - Network Section
                settingsSection(
                    icon: "network",
                    title: "Network",
                    iconColor: .green
                ) {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("User Agent")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Picker("", selection: $userAgent) {
                                ForEach(presetUserAgents, id: \.self) { agent in
                                    Text(shortName(for: agent)).tag(agent)
                                }
                                Text("Custom").tag(userAgent)
                            }
                            .labelsHidden()
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Custom User Agent")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            TextField("Enter custom User Agent string", text: $userAgent)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        Divider()
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Max Concurrent Downloads")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("Number of simultaneous download connections.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Stepper("\(maxConcurrentDownloads)", value: $maxConcurrentDownloads, in: 1...10)
                                .frame(width: 100)
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Section Builder
    
    @ViewBuilder
    private func settingsSection<Content: View>(
        icon: String,
        title: String,
        iconColor: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Header
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(iconColor)
                    .frame(width: 24)
                
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            
            // Section Content Card
            VStack(alignment: .leading, spacing: 0) {
                content()
                    .padding(16)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
            )
        }
    }
    
    private func shortName(for agent: String) -> String {
        if agent.contains("Chrome") { return "Chrome (macOS)" }
        if agent.contains("Firefox") { return "Firefox (macOS)" }
        if agent.contains("Safari") { return "Safari (macOS)" }
        return "Custom"
    }
}
