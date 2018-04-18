import XCTest
@testable import MapboxNavigation

class ImageRepositoryTests: XCTestCase {

    lazy var repository: ImageRepository = {
        let repo = ImageRepository.shared
        let config = URLSessionConfiguration.default
        config.protocolClasses = [ImageLoadingURLProtocolSpy.self]
        repo.sessionConfiguration = config

        return repo
    }()

    override func setUp() {
        super.setUp()
        self.continueAfterFailure = false

        URLProtocol.registerClass(ImageLoadingURLProtocolSpy.self)
        ImageLoadingURLProtocolSpy.reset()

        let semaphore = DispatchSemaphore(value: 0)
        repository.resetImageCache {
            semaphore.signal()
        }
        semaphore.wait()
    }

    func test_imageWithURL_downloadsImageWhenNotCached() {
        let imageName = "1.png"
        let fakeURL = URL(string: "http://an.image.url/\(imageName)")!

        ImageLoadingURLProtocolSpy.registerData(UIImagePNGRepresentation(ShieldImage.i280.image)!, forURL: fakeURL)
        XCTAssertNil(repository.cachedImageForKey(imageName))

        var imageReturned: UIImage? = nil
        let semaphore = DispatchSemaphore(value: 0)

        repository.imageWithURL(fakeURL, cacheKey: imageName) { (image) in
            imageReturned = image
            semaphore.signal()
        }
        semaphore.wait()

        XCTAssertNotNil(imageReturned)
        // round-trip through UIImagePNGRepresentation results in changes in data due to metadata stripping, thus direct image comparison is not always possible.
        XCTAssertTrue((imageReturned?.isKind(of: UIImage.self))!)
    }

    func test_imageWithURL_prefersCachedImageWhenAvailable() {
        let imageName = "1.png"
        let fakeURL = URL(string: "http://an.image.url/\(imageName)")!

        repository.storeImage(ShieldImage.i280.image, forKey: imageName, toDisk: false)

        var imageReturned: UIImage? = nil
        let semaphore = DispatchSemaphore(value: 0)

        repository.imageWithURL(fakeURL, cacheKey: imageName) { (image) in
            imageReturned = image
            semaphore.signal()
        }
        semaphore.wait()

        XCTAssertNil(ImageLoadingURLProtocolSpy.pastRequestForURL(fakeURL))
        XCTAssertNotNil(imageReturned)
    }

    override func tearDown() {
        URLProtocol.unregisterClass(ImageLoadingURLProtocolSpy.self)
        super.tearDown()
    }
}