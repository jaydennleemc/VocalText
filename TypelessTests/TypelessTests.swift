import XCTest

final class TypelessTests: XCTestCase {
    func testAppBundleIdentifier() {
        // Verify the test bundle loads correctly
        let bundle = Bundle(for: TypelessTests.self)
        XCTAssertNotNil(bundle.bundleIdentifier)
    }

    func testAssertTrue() {
        XCTAssertTrue(true, "Basic test infrastructure works")
    }
}
