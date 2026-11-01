import Foundation

@MainActor
protocol ImportQueueing: AnyObject {
    var files: [ImportFile] { get }
    var legend: Legend? { get }
    var extractedLayouts: [UUID: ExtractedLayout] { get }
    func add(urls: [URL], kind: ImportFileKind)
    func remove(id: UUID)
    func cancel()
    func retry(id: UUID)
    func reset()
}
