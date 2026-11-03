import Foundation

enum BoothLabelFormatter {
    static func display(_ raw: String) -> String {
        guard let firstDigitIndex = raw.firstIndex(where: \.isNumber),
              firstDigitIndex > raw.startIndex else {
            return raw
        }
        let prefix = raw[..<firstDigitIndex]
        let suffix = raw[firstDigitIndex...]
        return prefix.hasSuffix("-") ? raw : "\(prefix)-\(suffix)"
    }
}
