import Foundation

@MainActor
final class AppServices {
    let importQueue: any ImportQueueing
    let projectSession: any ProjectSessionProtocol

    init(
        importQueue: (any ImportQueueing)? = nil,
        projectSession: (any ProjectSessionProtocol)? = nil
    ) {
        self.importQueue = importQueue ?? ScriptedImportQueue()
        self.projectSession = projectSession ?? ProjectSession()
    }
}
