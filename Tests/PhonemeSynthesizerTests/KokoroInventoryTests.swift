import XCTest
@testable import PhonemeSynthesizer

final class KokoroInventoryTests: XCTestCase {
    func testAcceptsCommonEnglishIPA() throws {
        XCTAssertNoThrow(try KokoroPhonemeInventory.validate("həˈloʊ wɜːld"))
    }

    func testRejectsUnsupportedSymbolsExplicitly() {
        XCTAssertThrowsError(try KokoroPhonemeInventory.validate("həˈloʊ🙂")) { error in
            XCTAssertTrue(error.localizedDescription.contains("🙂"))
        }
    }

    func testRemovesEspeakJoinersBeforeValidation() throws {
        XCTAssertEqual(try IPAInput("a\u{200D}ʊ").value, "aʊ")
    }
}
