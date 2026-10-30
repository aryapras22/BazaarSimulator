import Foundation

enum MockDataError: Error {
    case fileNotFound(String)
}

enum MockDataStore {
    static func load<T: Decodable>(_ type: T.Type = T.self, from fileName: String, in bundle: Bundle = .main) throws -> T {
        guard let url = bundle.url(forResource: fileName, withExtension: "json") else {
            throw MockDataError.fileNotFound(fileName)
        }
        return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
    }
}
