import XCTest
@testable import maohuoban

@MainActor
extension MHBHTTPClientRequestInfrastructureTests {
    func testAPISessionFactoryUsesDedicatedConfiguration() {
        let configuration = MHBHTTPClientSessionFactory.configuration()

        XCTAssertEqual(configuration.timeoutIntervalForRequest, 30)
        XCTAssertEqual(configuration.timeoutIntervalForResource, 60)
        XCTAssertEqual(configuration.requestCachePolicy, .reloadIgnoringLocalCacheData)
        XCTAssertNil(configuration.urlCache)
        XCTAssertTrue(configuration.waitsForConnectivity)
        XCTAssertTrue(configuration.allowsCellularAccess)
        XCTAssertTrue(configuration.allowsConstrainedNetworkAccess)
        XCTAssertTrue(configuration.allowsExpensiveNetworkAccess)
    }
}
