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
    
    var height: Int {
        switch self {
        case .any: return 0
        case .hd: return 1080
        case .u4k: return 2160
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
    @Published var customHeight: String = ""
    @Published var destinationURL: URL?
    
    var resolvedWidth: Int {
        if selectedResolution == .custom {
            return Int(customWidth) ?? 0
        }
        return selectedResolution.width
    }
    
    var resolvedHeight: Int {
        if selectedResolution == .custom {
            return Int(customHeight) ?? 0
        }
        return selectedResolution.height
    }
    
    var canStartDownload: Bool {
        guard !blogUrl.isEmpty, destinationURL != nil else { return false }
        if selectedResolution == .custom {
            guard let w = Int(customWidth), let h = Int(customHeight), w > 0, h > 0 else {
                return false
            }
        }
        return true
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
                
                let minWidth = resolvedWidth
                let minHeight = resolvedHeight
                
                var page = 0
                var totalQueued = 0
                
                // Unlimited pagination: loop through all pages until content is exhausted
                while isDownloading {
                    log("Fetching page \(page + 1)...", type: .info)
                    
                    let images: [TumbImage]
                    do {
                        images = try await provider.fetchImages(for: blogUrl, offset: page * 20)
                    } catch let error as AppError where error.errorDescription == AppError.blogNotFound.errorDescription {
                        // Tumblr returns 404 when no more pages are available (scraper)
                        log("No more pages available.", type: .info)
                        break
                    }
                    
                    if images.isEmpty {
                        log("No more images found. All pages processed.", type: .info)
                        break
                    }
                    
                    // Filter by format only (resolution checked post-download)
                    let filtered = images.filter { image in
                        return DownloadViewModel.shouldDownload(image: image, minWidth: minWidth, minHeight: minHeight)
                    }
                    
                    if !filtered.isEmpty {
                        totalFound += filtered.count
                        totalQueued += filtered.count
                        log("Found \(filtered.count) valid images on page \(page + 1). Queuing for download...", type: .info)
                        
                        setupDownloadObservers(expectedCount: totalQueued)
                        downloadManager.startDownload(images: filtered, to: destination, concurrency: settings.maxConcurrentDownloads)
                    } else {
                        log("Page \(page + 1): no images matching resolution criteria.", type: .info)
                    }
                    
                    page += 1
                }
                
                if totalQueued == 0 {
                    log("No images found matching criteria across all pages.", type: .warning)
                    isDownloading = false
                }
                
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
        // Cancel previous observers to avoid duplicates
        subscribers.removeAll()
        
        // Observe completion
        downloadManager.completionSubject
            .receive(on: RunLoop.main)
            .sink { [weak self] (image, url, error) in
                guard let self = self else { return }
                
                if let error = error {
                    self.totalFailed += 1
                    self.log("Failed: \(error.localizedDescription)", type: .error)
                } else if let url = url {
                    // Post-Download Validation
                    if self.validateAndKeepImage(at: url, originalImage: image) {
                        self.totalDownloaded += 1
                        self.log("Saved: \(url.lastPathComponent)", type: .success)
                    } else {
                        self.totalFailed += 1 // Count as failed/rejected
                        // Log handled in validateAndKeepImage
                    }
                }
                
                self.updateProgress(expected: expectedCount)
            }
            .store(in: &subscribers)
    }
    
    private func validateAndKeepImage(at url: URL, originalImage: TumbImage) -> Bool {
        let minW = resolvedWidth
        let minH = resolvedHeight
        
        self.log("Validation: Checking [\(originalImage.url)] -> [\(url.lastPathComponent)]...", type: .info)
        
        // If Any resolution, accept everything
        if minW == 0 && minH == 0 { return true }
        
        // Check dimensions
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            self.log("Validation Failed: Could not read image properties for \(url.lastPathComponent)", type: .warning)
            try? FileManager.default.removeItem(at: url)
            return false
        }
        
        let propertiesOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, propertiesOptions) as? [String: Any],
              let width = properties[kCGImagePropertyPixelWidth as String] as? Int,
              let height = properties[kCGImagePropertyPixelHeight as String] as? Int else {
            self.log("Validation Failed: No dimensions found for \(url.lastPathComponent)", type: .warning)
            try? FileManager.default.removeItem(at: url)
            return false
        }
        
        let meetsWidth = width >= minW
        let meetsHeight = height >= minH
        
        if meetsWidth && meetsHeight {
            self.log("Validated: \(width)x\(height) (>= \(minW)x\(minH))", type: .info)
            return true
        } else {
            self.log("Rejected: \(width)x\(height) < \(minW)x\(minH). Deleting...", type: .warning)
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                self.log("Error deleting rejected file: \(error.localizedDescription)", type: .error)
            }
            return false
        }
    }
    
    private func updateProgress(expected: Int) {
        let completed = totalDownloaded + totalFailed
        if expected > 0 {
            progress = Double(completed) / Double(expected)
        }
        
        if completed >= expected && !isDownloading {
            log("Download complete. \(totalDownloaded) success, \(totalFailed) failed.", type: .success)
            statusMessage = "Complete"
            subscribers.removeAll()
        } else {
            statusMessage = "Downloaded \(totalDownloaded), failed \(totalFailed) of \(totalFound) found..."
        }
    }
    
    private func log(_ message: String, type: LogEntry.LogType) {
        withAnimation {
            logs.insert(LogEntry(message: message, type: type), at: 0)
        }
    }
    
    // MARK: - Filtering Logic
    static func shouldDownload(image: TumbImage, minWidth: Int, minHeight: Int) -> Bool {
        // 1. Format Check
        let validExtensions = ["jpg", "jpeg", "png"]
        let ext = image.url.pathExtension.lowercased()
        if !validExtensions.contains(ext) {
            return false
        }
        
        // 2. Resolution Check
        // Reformulated: verify ONLY if we have valid dimensions.
        // If image.width is 0 (unknown), we allow it (optimistic approach) because Scraper often yields 0.
        // We only reject if we KNOW it's too small.
        if minWidth > 0 && image.width > 0 {
            if image.width < minWidth { return false }
        }
        
        if minHeight > 0 && image.height > 0 {
            if image.height < minHeight { return false }
        }
        
        return true
    }
}
