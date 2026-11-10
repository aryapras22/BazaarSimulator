import Foundation
import simd

extension SelectTool {
    func startWallLengthTyping(context: ToolContext) -> Bool {
        guard let selectionID = context.selectionID,
              let wall = context.layout.objects.first(where: { $0.id == selectionID }),
              wall.kind == .wall,
              context.activeLayer == .structure else {
            return false
        }
        let graph = WallGraph(layout: context.layout)
        if let endpoints = graph.endpoints(for: wall.id) {
            let distStart = simd_distance(pressPoint, endpoints.start)
            let distEnd = simd_distance(pressPoint, endpoints.end)
            lengthAnchor = distStart <= distEnd ? .start : .end
        } else {
            lengthAnchor = .start
        }
        isTypingLength = true
        typedLengthString = ""
        updateWallLengthPreview(wall: wall, context: context)
        return true
    }

    func handleWallLengthKey(_ key: CanvasKey, context: ToolContext) -> Bool {
        guard let selectionID = context.selectionID,
              let wall = context.layout.objects.first(where: { $0.id == selectionID }) else {
            cancelWallLength(context: context)
            return false
        }
        switch key {
        case .character(let char):
            guard char.isNumber || char == "." else { return false }
            typedLengthString.append(char)
            updateWallLengthPreview(wall: wall, context: context)
            return true
        case .delete:
            if !typedLengthString.isEmpty {
                typedLengthString.removeLast()
                updateWallLengthPreview(wall: wall, context: context)
                return true
            }
            return false
        case .returnKey:
            commitWallLength(context: context)
            return true
        case .escape:
            cancelWallLength(context: context)
            return true
        default:
            return false
        }
    }

    func commitWallLength(context: ToolContext) {
        defer { cancelWallLength(context: context) }
        guard let selectionID = context.selectionID,
              let wall = context.layout.objects.first(where: { $0.id == selectionID }),
              wall.kind == .wall,
              let newLength = Double(typedLengthString),
              newLength > 0.01 else {
            return
        }
        let graph = WallGraph(layout: context.layout)
        let edit = WallEditing.setWallLength(
            wall: wall,
            newLength: newLength,
            anchor: lengthAnchor,
            in: context.layout,
            graph: graph
        )
        context.applyEdit(edit, coalesceKey: "wall-length-\(wall.id)")
    }

    func cancelWallLength(context: ToolContext) {
        isTypingLength = false
        typedLengthString = ""
        context.clearPreview()
    }

    func updateWallLengthPreview(wall: LayoutObject, context: ToolContext) {
        let graph = WallGraph(layout: context.layout)
        guard let endpoints = graph.endpoints(for: wall.id) else { return }
        let farEnd = (lengthAnchor == .start) ? endpoints.end : endpoints.start
        let chipText = typedLengthString.isEmpty
            ? "\(DimensionInput.text(for: wall.placement.sizeM.x)) m"
            : "\(typedLengthString) m"

        var previewPlacements: [UUID: Placement] = [:]
        if let newLength = Double(typedLengthString), newLength > 0.01 {
            let edit = WallEditing.setWallLength(
                wall: wall,
                newLength: newLength,
                anchor: lengthAnchor,
                in: context.layout,
                graph: graph
            )
            if case .batch(let edits) = edit {
                for subEdit in edits {
                    if case .replace(_, let after) = subEdit {
                        previewPlacements[after.id] = after.placement
                    }
                }
            }
        }

        context.setPreview(CanvasDragState(
            objectID: wall.id,
            pointerLocation: CGPoint(x: farEnd.x, y: farEnd.y),
            previewPlacements: previewPlacements,
            wallLengthChipText: chipText,
            wallLengthChipWorld: farEnd
        ))
    }
}
