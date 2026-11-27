import Foundation

enum MockDataError: Error {
    case fileNotFound(String)
}

enum MockDataStore {
    static func rawData(
        from fileName: String,
        in bundle: Bundle = .main
    ) throws -> Data {
        guard let url = bundle.url(forResource: fileName, withExtension: "json") else {
            throw MockDataError.fileNotFound(fileName)
        }
        return try Data(contentsOf: url)
    }

    static func load<T: Decodable>(
        _ type: T.Type = T.self,
        from fileName: String,
        in bundle: Bundle = .main
    ) throws -> T {
        let data = try rawData(from: fileName, in: bundle)
        return try JSONDecoder().decode(T.self, from: data)
    }
}
