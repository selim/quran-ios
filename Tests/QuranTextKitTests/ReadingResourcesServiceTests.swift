//
//  ReadingResourcesServiceTests.swift
//
//
//  Created by Mohamed Afifi on 2023-02-20.
//

@testable import QuranTextKit
import TestUtilities
import XCTest

final class ReadingResourcesServiceTests: XCTestCase {
    private var service: ReadingResourcesService!

    override func setUp() {
        ReadingPreferences.shared.reading = .hafs_1405
        OnDemandResource.requestInitializer = BundleResourceRequestFake.init
    }

    func testResourceAvailable() throws {
        BundleResourceRequestFake.resourceAvailable = true
        let service = ReadingResourcesService()

        let publisher = service.publisher.collect(1).first()
        let events = try awaitPublisher(publisher)

        XCTAssertEqual(events, [.ready])
    }

    func testResourceDownloading() throws {
        BundleResourceRequestFake.resourceAvailable = false
        BundleResourceRequestFake.downloadResult = .success(())
        let service = ReadingResourcesService()

        let publisher = service.publisher.collect(3).first()
        let events = try awaitPublisher(publisher)

        XCTAssertEqual(events, [.downloading(progress: 0),
                                .downloading(progress: 1),
                                .ready])
    }

    func testResourceDownloadFailure() throws {
        let error = URLError(.notConnectedToInternet)
        BundleResourceRequestFake.resourceAvailable = false
        BundleResourceRequestFake.downloadResult = .failure(error)
        let service = ReadingResourcesService()

        let publisher = service.publisher.collect(2).first()
        let events = try awaitPublisher(publisher)

        XCTAssertEqual(events, [.downloading(progress: 0),
                                .error(error as NSError)])
    }

    func testResourceSwitching() throws {
        BundleResourceRequestFake.resourceAvailable = true
        let service = ReadingResourcesService()

        let publisher = service.publisher.collect(1).first()
        let events = try awaitPublisher(publisher)
        XCTAssertEqual(events, [.ready])

        // Switch preference
        BundleResourceRequestFake.resourceAvailable = false
        BundleResourceRequestFake.downloadResult = .success(())
        ReadingPreferences.shared.reading = .hafs_1440

        let newPublisher = service.publisher.collect(4).first()
        let newEvents = try awaitPublisher(newPublisher)
        XCTAssertEqual(newEvents, [events.last,
                                   .downloading(progress: 0),
                                   .downloading(progress: 1),
                                   .ready])
    }
}

private class BundleResourceRequestFake: NSBundleResourceRequest {
    static var resourceAvailable: Bool = true
    static var downloadResult: Result<Void, Error>?

    override func conditionallyBeginAccessingResources(completionHandler: @escaping (Bool) -> Void) {
        DispatchQueue.global().async {
            completionHandler(Self.resourceAvailable)
        }
    }

    override func beginAccessingResources(completionHandler: @escaping (Error?) -> Void) {
        DispatchQueue.global().async {
            switch Self.downloadResult! {
            case .success:
                self.progress.completedUnitCount = self.progress.totalUnitCount
                completionHandler(nil)
            case .failure(let error):
                completionHandler(error)
            }
        }
    }
}
