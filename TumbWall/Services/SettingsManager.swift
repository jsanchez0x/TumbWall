import SwiftUI
import Combine

class SettingsManager: ObservableObject {
    var objectWillChange = ObservableObjectPublisher()
    @AppStorage("tumblrApiKey") var apiKey: String = ""
    @AppStorage("forceScraping") var forceScraping: Bool = false
    @AppStorage("userAgent") var userAgent: String = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
    @AppStorage("maxConcurrentDownloads") var maxConcurrentDownloads: Int = 3
    
    static let shared = SettingsManager()
    
    let availableUserAgents = [
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:109.0) Gecko/20100101 Firefox/115.0"
    ]
}
