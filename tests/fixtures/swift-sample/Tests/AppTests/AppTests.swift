import XCTest
@testable import App

final class AppTests: XCTestCase {
    func testGreet() { XCTAssertEqual(Greeter().greet("World"), "Hello, World!") }
}
