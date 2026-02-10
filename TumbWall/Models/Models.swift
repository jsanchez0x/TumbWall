import Foundation

enum AppError: LocalizedError, Identifiable {
    var id: String { localizedDescription }
    
    case invalidURL
    case networkError(Error)
    case apiError(String)
    case parsingError
    case fileSystemError(Error)
    case cancelled
    case blogNotFound
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "The URL provided is invalid."
        case .networkError(let error): return "Network error: \(error.localizedDescription)"
        case .apiError(let reason): return "API Error: \(reason)"
        case .parsingError: return "Failed to parse content."
        case .fileSystemError(let error): return "File system error: \(error.localizedDescription)"
        case .cancelled: return "Operation cancelled."
        case .blogNotFound: return "Blog not found or private."
        case .unknown: return "An unknown error occurred."
        }
    }
}

struct TumbBlog: Identifiable, Codable {
    var id: String { name }
    let name: String
    let url: String
    let title: String?
}

struct TumbImage: Identifiable, Codable, Hashable {
    let id: String
    let url: URL
    let width: Int
    let height: Int
    let postUrl: String?

    var resolutionString: String {
        "\(width)x\(height)"
    }
}

struct DownloadStat: Identifiable {
    let id = UUID()
    let filename: String
    var status: Status
    
    enum Status: Equatable {
        case pending
        case downloading
        case completed(URL)
        case failed(String)
        case skipped(String)
        
        var isTerminal: Bool {
            switch self {
            case .completed, .failed, .skipped: return true
            default: return false
            }
        }
    }
}
