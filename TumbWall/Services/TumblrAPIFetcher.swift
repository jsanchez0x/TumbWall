import Foundation

class TumblrAPIFetcher: ImageProviderProtocol {
    private let apiKey: String
    private let session: URLSession

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    func fetchImages(for blogName: String, offset: Int = 0) async throws -> [TumbImage] {
        guard !apiKey.isEmpty else {
            throw AppError.apiError("API Key is missing")
        }

        // Clean blog name (extract from URL if needed)
        let cleanName = extractBlogName(from: blogName)
        let endpoint = "https://api.tumblr.com/v2/blog/\(cleanName)/posts/photo"
        
        guard var components = URLComponents(string: endpoint) else {
            throw AppError.invalidURL
        }
        
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "limit", value: "20"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]
        
        guard let url = components.url else { throw AppError.invalidURL }
        
        var request = URLRequest(url: url)
        request.setValue(SettingsManager.shared.userAgent, forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.networkError(NSError(domain: "Invalid Response", code: 0))
        }
        
        if httpResponse.statusCode == 404 {
            throw AppError.blogNotFound
        }
        
        guard httpResponse.statusCode == 200 else {
            throw AppError.apiError("Status Code: \(httpResponse.statusCode)")
        }
        
        // Parse JSON
        let decoder = JSONDecoder()
        do {
            let apiResponse = try decoder.decode(TumblrAPIResponse.self, from: data)
            return apiResponse.response.posts.flatMap { post -> [TumbImage] in
                post.photos.map { photo in
                    // Get the largest size
                    let original = photo.original_size
                    return TumbImage(id: UUID().uuidString, url: URL(string: original.url)!, width: original.width, height: original.height, postUrl: post.post_url)
                }
            }
        } catch {
            print("Decoding Error: \(error)")
            throw AppError.parsingError
        }
    }
    
    private func extractBlogName(from input: String) -> String {
        // Simple extraction: if it contains ".tumblr.com", strip schema and suffix
        // e.g., https://art.tumblr.com -> art.tumblr.com (API handles hostnames usually)
        if let url = URL(string: input), let host = url.host {
            return host
        }
        return input
    }
}

// MARK: - API Response Models inside Helper
struct TumblrAPIResponse: Codable {
    let response: APIResponseData
}

struct APIResponseData: Codable {
    let posts: [APIPost]
}

struct APIPost: Codable {
    let id: Int64?
    let post_url: String?
    let photos: [APIPhoto]
}

struct APIPhoto: Codable {
    let original_size: APIPhotoSize
}

struct APIPhotoSize: Codable {
    let url: String
    let width: Int
    let height: Int
}
