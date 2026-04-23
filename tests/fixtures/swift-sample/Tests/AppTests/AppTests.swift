import XCTest
@testable import SampleLib

final class AppTests: XCTestCase {
    func testGreeter() {
        let greeter = Greeter(name: "Test")
        XCTAssertEqual(greeter.greet(), "Hello, Test!")
    }

    func testSampleAppInit() {
        let app = SampleApp()
        XCTAssertNotNil(app)
    }
}
