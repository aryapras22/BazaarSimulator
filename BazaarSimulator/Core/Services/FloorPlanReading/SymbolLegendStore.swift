import Extractor
import Foundation

struct SymbolLegendStore: Sendable {
    static let shared = SymbolLegendStore()

    let symbols: SymbolLegend

    init(bundle: Bundle = .main) {
        if let url = bundle.url(forResource: "legends", withExtension: "json", subdirectory: "symbols") ??
            bundle.url(forResource: "legends", withExtension: "json") {
            self.symbols = (try? SymbolLegend.load(from: url)) ?? .empty
        } else {
            let localURL = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Resources")
                .appendingPathComponent("Legends")
                .appendingPathComponent("symbols")
                .appendingPathComponent("legends.json")
            if FileManager.default.fileExists(atPath: localURL.path) {
                self.symbols = (try? SymbolLegend.load(from: localURL)) ?? .empty
            } else {
                self.symbols = .empty
            }
        }
    }
}
