import Foundation
import SwiftSoup

class ScraperFetcher: ImageProviderProtocol {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchImages(for blogName: String, offset: Int) async throws -> [TumbImage] {
        // Tumblr usually paginates by page number for frontend, not offset.
        // Assuming 20 posts per page provided by offset logic or similar.
        // Page 1 = offset 0-19. Page 2 = 20-39.
        let page = (offset / 20) + 1
        
        let urlString = "https://\(cleanBlogName(blogName)).tumblr.com/page/\(page)"
        guard let url = URL(string: urlString) else { throw AppError.invalidURL }
        
        var request = URLRequest(url: url)
        request.setValue(SettingsManager.shared.userAgent, forHTTPHeaderField: "User-Agent")
        
        // Fetch HTML
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
           throw AppError.networkError(NSError(domain: "Invalid Response", code: 0))
        }
        
        if httpResponse.statusCode == 404 {
            throw AppError.blogNotFound
        }
        
        guard let html = String(data: data, encoding: .utf8) else {
            throw AppError.parsingError
        }
        
        // Parse with SwiftSoup
        do {
            let doc: Document = try SwiftSoup.parse(html)
            let imgs: Elements = try doc.select("img")
            
            var images: [TumbImage] = []
            
            for img in imgs {
                let src = try img.attr("src")
                
                // Filter out small avatars, pixel trackers, etc.
                if src.contains("avatar") || src.contains("tracker") || src.isEmpty { continue }
                
                // Content images usually have format like .../tumblr_id_500.jpg
                // We try to upgrade to 1280 or raw
                if let highRes = upgradeResolution(urlString: src),
                   let finalURL = URL(string: highRes) {
                    
                    // Scraper doesn't always know dimensions without downloading header.
                    // We put 0, 0 or try to parse if possible (some themes put width/height in attr)
                    let width = (try? Int(img.attr("width"))) ?? 0
                    let height = (try? Int(img.attr("height"))) ?? 0
                    
                    // Simple deduplication logic could happen here or in VM
                    if !images.contains(where: { $0.url == finalURL }) {
                        images.append(TumbImage(id: UUID().uuidString, url: finalURL, width: width, height: height, postUrl: urlString))
                    }
                }
            }
            return images
            
        } catch {
            print("Scraping Error: \(error)")
            throw AppError.parsingError
        }
    }
    
    private func cleanBlogName(_ name: String) -> String {
        // Removes https://, .tumblr.com/ etc.
        if let url = URL(string: name), let host = url.host {
            return host.replacingOccurrences(of: ".tumblr.com", with: "")
        }
        return name.replacingOccurrences(of: ".tumblr.com", with: "")
    }
    
    private func upgradeResolution(urlString: String) -> String? {
        // Logic to try finding _1280, _raw, etc.
        // Example: https://64.media.tumblr.com/hash/tumblr_id_500.jpg
        // Target: https://64.media.tumblr.com/hash/tumblr_id_1280.jpg
        
        let pattern = "_[0-9]+\\.(jpg|png|gif)$"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return urlString }
        
        let nsString = urlString as NSString
        let result = regex.stringByReplacingMatches(in: urlString, options: [], range: NSRange(location: 0, length: nsString.length), withTemplate: "_1280.$1")
        
        // Optimization: In a real app we might head-check this URL, but for now we assume 1280 exists if 500 exists.
        return result
    }
}
