import Foundation
@testable import BazaarSimulator

enum TestFixtureLoader {
    private final class BundleToken {}

    static func load<T: Decodable>(_ type: T.Type = T.self, from fileName: String) throws -> T {
        let bundle = Bundle(for: BundleToken.self)
        return try MockDataStore.load(type, from: fileName, in: bundle)
    }
}
