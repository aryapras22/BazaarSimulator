import Foundation

@MainActor
protocol ImportQueueing: AnyObject {
    func files(for projectID: UUID) -> [ImportFile]
    func legend(for projectID: UUID) -> Legend?
    func extractedLayout(for fileID: UUID) -> ExtractedLayout?
    func logEntries(for projectID: UUID) -> [ImportLogEntry]

    func add(urls: [URL], kind: ImportFileKind, projectID: UUID)
    func remove(fileID: UUID)
    func retry(fileID: UUID)
    func cancel(projectID: UUID)
    func removeAll(projectID: UUID)
}
