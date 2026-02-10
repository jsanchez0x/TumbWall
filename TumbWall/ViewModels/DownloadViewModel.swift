import SwiftUI
import Combine

enum MinResolution: String, CaseIterable, Identifiable {
    case any = "Any"
    case hd = "HD (1920x1080)"
    case u4k = "4K (3840x2160)"
    case custom = "Custom"
    
    var id: String { rawValue }
    
    var width: Int {
        switch self {
        case .any: return 0
        case .hd: return 1920
        case .u4k: return 3840
        case .custom: return -1 // Handled by ViewModel
        }
    }
}

@MainActor
class DownloadViewModel: ObservableObject {
    // Inputs
    @Published var blogUrl: String = ""
    @Published var selectedResolution: MinResolution = .hd
    @Published var customWidth: String = ""
    @Published var destinationURL: URL?
    
    var resolvedWidth: Int {
        if selectedResolution == .custom {
            return Int(customWidth) ?? 0
        }
        return selectedResolution.width
    }
    
    // State
    @Published var isDownloading = false
    @Published var progress: Double = 0.0
    @Published var statusMessage: String = "Ready"
    @Published var logs: [LogEntry] = []
    
    // Stats
    @Published var totalFound = 0
    @Published var totalDownloaded = 0
    @Published var totalFailed = 0
    
    private var subscribers = Set<AnyCancellable>()
    private let settings = SettingsManager.shared
    private let downloadManager = DownloadManager.shared
    
    struct LogEntry: Identifiable {
        let id = UUID()
        let message: String
        let timestamp = Date()
        let type: LogType
        
        enum LogType {
            case info, warning, error, success
        }
    }
    
    func startDownload() {
        guard let destination = destinationURL else {
            log("Please select a destination folder.", type: .error)
            return
        }
        
        guard !blogUrl.isEmpty else {
            log("Please enter a blog URL.", type: .error)
            return
        }
        
        isDownloading = true
        progress = 0
        totalFound = 0
        totalDownloaded = 0
        totalFailed = 0
        logs.removeAll()
        
        Task {
            do {
                let provider = getProvider()
                log("Starting download with strategy: \(String(describing: type(of: provider)))", type: .info)
                
                // Fetch loop (Limit to 5 pages for safety in this demo, or until empty)
                var allImages: [TumbImage] = []
                
                for page in 0..<5 {
                    if !isDownloading { break } // Cancel check
                    
                    log("Fetching page \(page + 1)...", type: .info)
                    let images = try await provider.fetchImages(for: blogUrl, offset: page * 20)
                    if images.isEmpty { break }
                    
                    // Filter
                    let filtered = images.filter { image in
                        // Simple check: if width >= required OR generic checks
                        // Tumblr API gives distinct sizes. Scraper might be zero.
                        // If scraper returns 0, we download it to check or assume generic.
                        // For this demo: if width is known and < required, skip.
                        if image.width > 0 && image.width < resolvedWidth {
                            return false
                        }
                        return true
                    }
                    
                    allImages.append(contentsOf: filtered)
                    log("Found \(filtered.count) valid images on page \(page + 1).", type: .info)
                    totalFound += filtered.count
                }
                
                if allImages.isEmpty {
                    log("No images found matching criteria.", type: .warning)
                    isDownloading = false
                    return
                }
                
                log("Queueing \(allImages.count) images for download...", type: .info)
                
                // Start Downloads
                // We observe the manager via Combine
                setupDownloadObservers(expectedCount: allImages.count)
                
                downloadManager.startDownload(images: allImages, to: destination, concurrency: settings.maxConcurrentDownloads)
                
            } catch {
                log("Error: \(error.localizedDescription)", type: .error)
                isDownloading = false
            }
        }
    }
    
    func stopDownload() {
        isDownloading = false
        downloadManager.cancelAll()
        log("Download cancelled by user.", type: .warning)
    }
    
    private func getProvider() -> ImageProviderProtocol {
        if settings.forceScraping {
            return ScraperFetcher()
        }
        if !settings.apiKey.isEmpty {
            return TumblrAPIFetcher(apiKey: settings.apiKey)
        }
        return ScraperFetcher()
    }
    
    private func setupDownloadObservers(expectedCount: Int) {
        // Observe completion
        downloadManager.completionSubject
            .receive(on: RunLoop.main)
            .sink { [weak self] (imageId, url, error) in
                guard let self = self else { return }
                if let error = error {
                    self.totalFailed += 1
                    self.log("Failed: \(error.localizedDescription)", type: .error)
                } else {
                    self.totalDownloaded += 1
                    // self.log("Downloaded: \(url?.lastPathComponent ?? "image")", type: .success)
                }
                
                self.updateProgress(expected: expectedCount)
            }
            .store(in: &subscribers)
    }
    
    private func updateProgress(expected: Int) {
        let completed = totalDownloaded + totalFailed
        progress = Double(completed) / Double(expected)
        
        if completed >= expected {
            isDownloading = false
            log("Detailed download complete. \(totalDownloaded) success, \(totalFailed) failed.", type: .success)
            statusMessage = "Complete"
            subscribers.removeAll() // Stop listening
        } else {
            statusMessage = "Downloading \(completed)/\(expected)..."
        }
    }
    
    private func log(_ message: String, type: LogEntry.LogType) {
        withAnimation {
            logs.insert(LogEntry(message: message, type: type), at: 0)
        }
    }
}
