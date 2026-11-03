import Foundation

struct GroupSelection: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case group(BoothGroupKind)
        case custom
    }

    var kind: Kind
    var memberIDs: Set<UUID>
}
