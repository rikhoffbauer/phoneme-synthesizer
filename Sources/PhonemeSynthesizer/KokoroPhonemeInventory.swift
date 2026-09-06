import Foundation

public enum PhonemeValidationError: LocalizedError, Equatable {
    case unsupportedSymbols([String])

    public var errorDescription: String? {
        switch self {
        case .unsupportedSymbols(let symbols):
            return "Unsupported phoneme symbols for Kokoro ANE: \(symbols.joined(separator: " "))"
        }
    }
}

public enum KokoroPhonemeInventory {
    // FluidInference/kokoro-82m-coreml ANE/vocab.json, pinned with FluidAudio.
    public static let symbols = Set(";:,.!?—…\"()“” ̃ʣʥʦʨᵝꭧAIOQSTWYᵊabcdefhijklmnopqrstuvwxyzɑɐɒæβɔɕçɖðʤəɚɛɜɟɡɥɨɪʝɯɰŋɳɲɴøɸθœɹɾɻʁɽʂʃʈʧʊʋʌɣɤχʎʒʔˈˌːʰʲ↓→↗↘ᵻ".unicodeScalars.map(String.init))

    public static func validate(_ ipa: String) throws {
        let unsupported = Set(ipa.unicodeScalars.map(String.init).filter { !symbols.contains($0) }).sorted()
        if !unsupported.isEmpty { throw PhonemeValidationError.unsupportedSymbols(unsupported) }
    }
}
