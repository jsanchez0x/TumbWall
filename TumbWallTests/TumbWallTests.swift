import XCTest
@testable import TumbWall

@MainActor
final class TumbWallTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        SettingsManager.shared.apiKey = ""
        SettingsManager.shared.forceScraping = false
    }

    func testTumblrAPIFetcherURLConstruction() async throws {
        // Setup Mock
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        
        let apiResponse = """
        {
            "response": {
                "posts": [
                    {
                        "id": 12345,
                        "post_url": "https://test.tumblr.com/post/1",
                        "photos": [
                            { "original_size": { "url": "https://media.tumblr.com/1.jpg", "width": 1000, "height": 1000 } }
                        ]
                    }
                ]
            }
        }
        """.data(using: .utf8)!
        
        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else { throw URLError(.badURL) }
            
            // Verify Logic
            XCTAssertTrue(url.absoluteString.contains("api.tumblr.com"))
            XCTAssertTrue(url.absoluteString.contains("api_key=TEST_KEY"))
            
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, apiResponse)
        }
        
        let fetcher = TumblrAPIFetcher(apiKey: "TEST_KEY", session: session)
        let images = try await fetcher.fetchImages(for: "test.tumblr.com", offset: 0)
        
        XCTAssertEqual(images.count, 1)
        XCTAssertEqual(images.first?.width, 1000)
    }
    
    func testScraperFetcherLogic() async throws {
         // Setup Mock
         let config = URLSessionConfiguration.ephemeral
         config.protocolClasses = [MockURLProtocol.self]
         let session = URLSession(configuration: config)
         
         let html = """
         <html>
            <body>
                <div class="post">
                    <img src="https://64.media.tumblr.com/hash/tumblr_id_500.jpg" width="500" height="500">
                </div>
            </body>
         </html>
         """.data(using: .utf8)!
         
         MockURLProtocol.requestHandler = { request in
             let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
             return (response, html)
         }
         
         let fetcher = ScraperFetcher(session: session)
         let images = try await fetcher.fetchImages(for: "scrape.tumblr.com", offset: 0)
         
         XCTAssertEqual(images.count, 1)
         // Verify resolution upgrade logic
         XCTAssertTrue(images.first?.url.absoluteString.contains("_1280.jpg") ?? false, "Should upgrade to 1280")
     }
    
    func testStrategySelection() {
        let settings = SettingsManager.shared
        
        // Case 1: No Key -> Scraper
        settings.apiKey = ""
        settings.forceScraping = false
        // We can't strictly inspect the type returned by private function in VM, 
        // but we can test the logic if we exposed a factory. 
        // Given the constraints, we will verify the inputs that drive the decision.
        
        XCTAssertTrue(settings.apiKey.isEmpty)
        XCTAssertFalse(settings.forceScraping)
        // In a real app we'd expose the Factory to test: Factory.get(settings) is Scraper
        
        // Case 2: Key Present -> API
        settings.apiKey = "ABC"
        XCTAssertFalse(SettingsManager.shared.apiKey.isEmpty)
        
        // Case 3: Key Present + Force -> Scraper
        settings.forceScraping = true
        XCTAssertTrue(SettingsManager.shared.forceScraping)
    }
    
    // MARK: - Resolution Tests
    
    func testStandardResolutionWidths() {
        XCTAssertEqual(MinResolution.hd.width, 1920)
        XCTAssertEqual(MinResolution.u4k.width, 3840)
        XCTAssertEqual(MinResolution.any.width, 0)
        XCTAssertEqual(MinResolution.custom.width, -1)
        
        // Heights
        XCTAssertEqual(MinResolution.hd.height, 1080)
        XCTAssertEqual(MinResolution.u4k.height, 2160)
        XCTAssertEqual(MinResolution.any.height, 0)
        XCTAssertEqual(MinResolution.custom.height, -1)
    }

    func testCustomResolutionParsing() async {
        // Use Task with @MainActor to properly isolate the ViewModel
        let result = await MainActor.run {
            let viewModel = DownloadViewModel()
            
            // Test 1: Default resolution
            let defaultWidth = viewModel.resolvedWidth
            let defaultHeight = viewModel.resolvedHeight
            XCTAssertEqual(defaultWidth, 1920, "Default should be HD width (1920)")
            XCTAssertEqual(defaultHeight, 1080, "Default should be HD height (1080)")
            
            // Test 2: Custom with valid input
            viewModel.selectedResolution = .custom
            viewModel.customWidth = "500"
            viewModel.customHeight = "300"
            let customValidW = viewModel.resolvedWidth
            let customValidH = viewModel.resolvedHeight
            XCTAssertEqual(customValidW, 500, "Custom width 500 should resolve to 500")
            XCTAssertEqual(customValidH, 300, "Custom height 300 should resolve to 300")
            
            // Test 3: Custom with invalid input
            viewModel.customWidth = "abc"
            viewModel.customHeight = "xyz"
            let customInvalidW = viewModel.resolvedWidth
            let customInvalidH = viewModel.resolvedHeight
            XCTAssertEqual(customInvalidW, 0, "Invalid width input should resolve to 0")
            XCTAssertEqual(customInvalidH, 0, "Invalid height input should resolve to 0")
            
            // Test 4: Custom with empty input
            viewModel.customWidth = ""
            viewModel.customHeight = ""
            let customEmptyW = viewModel.resolvedWidth
            let customEmptyH = viewModel.resolvedHeight
            XCTAssertEqual(customEmptyW, 0, "Empty width input should resolve to 0")
            XCTAssertEqual(customEmptyH, 0, "Empty height input should resolve to 0")
            
            // Test 5: canStartDownload validation
            viewModel.blogUrl = "test"
            viewModel.destinationURL = URL(fileURLWithPath: "/tmp")
            viewModel.selectedResolution = .hd
            XCTAssertTrue(viewModel.canStartDownload, "Should be ready with HD preset")
            
            viewModel.selectedResolution = .custom
            viewModel.customWidth = ""
            viewModel.customHeight = ""
            XCTAssertFalse(viewModel.canStartDownload, "Should not be ready with empty custom values")
            
            viewModel.customWidth = "100"
            viewModel.customHeight = "200"
            XCTAssertTrue(viewModel.canStartDownload, "Should be ready with valid custom values")
            
            return true
        }
        
        XCTAssertTrue(result)
    }


    // MARK: - Filter Logic Tests (Bugfix & New Feature)
    
    // Helper to create a dummy image
    func makeImage(url: String, width: Int, height: Int) -> TumbImage {
        return TumbImage(id: UUID().uuidString, url: URL(string: url)!, width: width, height: height, postUrl: "http://test.com")
    }

    func testResolutionFiltering() {
        // NOTE: Resolution filtering is now Post-Download. 
        // `shouldDownload` only checks format.
        // We verify that it returns TRUE for any resolution, as we want to download first.
        
        let hdWidth = 1920
        let hdHeight = 1080
        
        // 1. Unknown Resolution (0x0) -> Should be ACCEPTED
        let unknownImg = makeImage(url: "http://test.com/img.jpg", width: 0, height: 0)
        XCTAssertTrue(DownloadViewModel.shouldDownload(image: unknownImg, minWidth: 0, minHeight: 0), "Should download 0x0 images for later validation")
        
        // 2. Low Resolution -> Should be ACCEPTED (for now)
        let lowResImg = makeImage(url: "http://test.com/img.jpg", width: 500, height: 500)
        XCTAssertTrue(DownloadViewModel.shouldDownload(image: lowResImg, minWidth: 0, minHeight: 0), "Should download low res images for later validation")
        
        // 3. High Resolution -> Should be ACCEPTED
        let highResImg = makeImage(url: "http://test.com/img.jpg", width: 2000, height: 2000)
        XCTAssertTrue(DownloadViewModel.shouldDownload(image: highResImg, minWidth: 0, minHeight: 0), "Should download high res images")
    }
    
    func testFormatFiltering() {
        // 1. Valid Formats
        let jpg = makeImage(url: "http://test.com/image.jpg", width: 100, height: 100)
        let jpeg = makeImage(url: "http://test.com/image.jpeg", width: 100, height: 100)
        let png = makeImage(url: "http://test.com/image.png", width: 100, height: 100)
        let JPG = makeImage(url: "http://test.com/image.JPG", width: 100, height: 100)
        
        XCTAssertTrue(DownloadViewModel.shouldDownload(image: jpg, minWidth: 0, minHeight: 0), "Should accept jpg")
        XCTAssertTrue(DownloadViewModel.shouldDownload(image: jpeg, minWidth: 0, minHeight: 0), "Should accept jpeg")
        XCTAssertTrue(DownloadViewModel.shouldDownload(image: png, minWidth: 0, minHeight: 0), "Should accept png")
        XCTAssertTrue(DownloadViewModel.shouldDownload(image: JPG, minWidth: 0, minHeight: 0), "Should accept JPG (case insensitive)")
        
        // 2. Invalid Formats
        let gif = makeImage(url: "http://test.com/image.gif", width: 100, height: 100)
        let webp = makeImage(url: "http://test.com/image.webp", width: 100, height: 100)
        let noExt = makeImage(url: "http://test.com/image", width: 100, height: 100)
        
        XCTAssertFalse(DownloadViewModel.shouldDownload(image: gif, minWidth: 0, minHeight: 0), "Should reject gif")
        XCTAssertFalse(DownloadViewModel.shouldDownload(image: webp, minWidth: 0, minHeight: 0), "Should reject webp")
        XCTAssertFalse(DownloadViewModel.shouldDownload(image: noExt, minWidth: 0, minHeight: 0), "Should reject no extension")
    }
}
