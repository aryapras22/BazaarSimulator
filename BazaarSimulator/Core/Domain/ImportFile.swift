import Foundation

enum ImportFileKind: String, Sendable, Codable, Hashable {
    case legend
    case floorPlan
}

enum ImportFileState: Sendable, Hashable {
    case waiting
    case reading(progress: Double?)
    case done(booths: Int, doors: Int)
    case failed(message: String)
    case cancelled
}

struct ImportFile: Identifiable, Sendable, Hashable {
    let id: UUID
    let url: URL
    let kind: ImportFileKind
    var state: ImportFileState
    var fileSize: Int64
    var thumbnailData: Data?

    init(
        id: UUID = UUID(),
        url: URL,
        kind: ImportFileKind,
        state: ImportFileState = .waiting,
        fileSize: Int64 = 0,
        thumbnailData: Data? = nil
    ) {
        self.id = id
        self.url = url
        self.kind = kind
        self.state = state
        self.fileSize = fileSize
        self.thumbnailData = thumbnailData
    }
}
