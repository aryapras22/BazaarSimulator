import Extractor
import Foundation
import os

struct SymbolLegendStore: Sendable {
    static let shared = SymbolLegendStore()

    let symbols: SymbolLegend

    init(bundle: Bundle = .main) {
        guard let url = bundle.url(forResource: "legends", withExtension: "json") else {
            Logger.symbols.error("legends.json is missing from the bundle, reading without symbol legends")
            symbols = .empty
            return
        }
        do {
            symbols = try SymbolLegend.load(from: url)
        } catch {
            Logger.symbols.error("legends.json did not load: \(error.localizedDescription)")
            symbols = .empty
        }
    }
}

private extension Logger {
    static let symbols = Logger(subsystem: "BazaarSimulator", category: "SymbolLegendStore")
}
