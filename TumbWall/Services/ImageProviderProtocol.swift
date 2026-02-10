import Foundation

protocol ImageProviderProtocol {
    /// Fetches images for a given blog.
    /// - Parameters:
    ///   - blogName: The name or URL of the blog.
    ///   - offset: Pagination offset.
    /// - Returns: A list of found TumbImages.
    func fetchImages(for blogName: String, offset: Int) async throws -> [TumbImage]
}
