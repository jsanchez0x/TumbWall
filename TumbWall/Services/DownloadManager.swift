import Foundation
import Combine

class DownloadManager: ObservableObject {
    static let shared = DownloadManager()
    
    private let operationQueue = OperationQueue()
    private var session: URLSession!
    
    // Publish updates to VM
    let progressSubject = PassthroughSubject<(String, Double), Never>()
    let completionSubject = PassthroughSubject<(TumbImage, URL?, Error?), Never>()
    
    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: configuration)
    }
    
    func startDownload(images: [TumbImage], to destination: URL, concurrency: Int) {
        operationQueue.maxConcurrentOperationCount = concurrency
        
        for image in images {
            let operation = DownloadOperation(session: session, image: image, destination: destination)
            
            operation.onProgress = { [weak self] progress in
                self?.progressSubject.send((image.id, progress))
            }
            
            operation.onCompletion = { [weak self] location, error in
                self?.completionSubject.send((image, location, error))
            }
            
            operationQueue.addOperation(operation)
        }
    }
    
    func cancelAll() {
        operationQueue.cancelAllOperations()
    }
}

// Wrapper for async download as an Operation
class DownloadOperation: Operation {
    let session: URLSession
    let image: TumbImage
    let destination: URL
    
    var onProgress: ((Double) -> Void)?
    var onCompletion: ((URL?, Error?) -> Void)?
    
    private var _isExecuting = false
    private var _isFinished = false
    private var downloadTask: URLSessionDownloadTask?
    
    override var isAsynchronous: Bool { true }
    
    override var isExecuting: Bool {
        get { _isExecuting }
        set {
            willChangeValue(forKey: "isExecuting")
            _isExecuting = newValue
            didChangeValue(forKey: "isExecuting")
        }
    }
    
    override var isFinished: Bool {
        get { _isFinished }
        set {
            willChangeValue(forKey: "isFinished")
            _isFinished = newValue
            didChangeValue(forKey: "isFinished")
        }
    }
    
    init(session: URLSession, image: TumbImage, destination: URL) {
        self.session = session
        self.image = image
        self.destination = destination
        super.init()
    }
    
    override func start() {
        guard !isCancelled else {
            isFinished = true
            return
        }
        
        isExecuting = true
        
        let fileManager = FileManager.default
        let filename = image.url.lastPathComponent
        let fileURL = destination.appendingPathComponent(filename)
        
        // Skip if exists
        if fileManager.fileExists(atPath: fileURL.path) {
            finish(url: fileURL, error: nil)
            return
        }
        
        downloadTask = session.downloadTask(with: image.url) { [weak self] tempURL, response, error in
            guard let self = self else { return }
            
            if let error = error {
                self.finish(url: nil, error: error)
                return
            }
            
            guard let tempURL = tempURL else {
                self.finish(url: nil, error: AppError.networkError(NSError(domain: "No data", code: -1)))
                return
            }
            
            do {
                try fileManager.moveItem(at: tempURL, to: fileURL)
                self.finish(url: fileURL, error: nil)
            } catch {
                self.finish(url: nil, error: error)
            }
        }
        
        // KVO for progress could be added here if needed, but simple task doesn't support easy progress closure without delegate.
        // For simplicity in this demo, we assume 0 -> 100 on completion or use delegate. 
        // To keep it simple and robust, we just mark start/end.
        // If granular progress is needed, we need a SessionDelegate.
        
        downloadTask?.resume()
    }
    
    override func cancel() {
        downloadTask?.cancel()
        super.cancel()
        finish(url: nil, error: AppError.cancelled)
    }
    
    private func finish(url: URL?, error: Error?) {
        onCompletion?(url, error)
        isExecuting = false
        isFinished = true
    }
}
