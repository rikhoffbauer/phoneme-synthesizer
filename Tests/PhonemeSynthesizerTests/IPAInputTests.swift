import XCTest
@testable import PhonemeSynthesizer

final class IPAInputTests: XCTestCase {
    func testStripsDecorativeSlashDelimiters() throws {
        XCTAssertEqual(try IPAInput("/həˈloʊ/").value, "həˈloʊ")
    }

    func testStripsDecorativeBracketDelimiters() throws {
        XCTAssertEqual(try IPAInput("[ h ə ˈ l o ʊ ]").value, "h ə ˈ l o ʊ")
    }

    func testNormalizesUnicodeToNFC() throws {
        let decomposed = "e\u{301}"
        XCTAssertEqual(try IPAInput(decomposed).value, "é")
    }

    func testRejectsEmptyInput() {
        XCTAssertThrowsError(try IPAInput(" /  / "))
    }
}
