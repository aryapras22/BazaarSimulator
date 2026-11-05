import Foundation
import simd

extension LayoutEditorViewModel {
    func handleWallClick(at world: SIMD2<Double>, isShiftDown: Bool) {
        guard case .drawWall = tool, let layout = activeLayout else { return }
        let snapped = WallDrawing.snappedPoint(
            world,
            from: wallDrawing?.points.last,
            in: layout,
            pointsPerMetre: transform.scale,
            lockAngle: isShiftDown
        )

        if wallDrawing == nil {
            wallDrawing = WallDrawing(points: [snapped], typedLength: "")
            return
        }

        if let last = wallDrawing?.points.last, last != snapped {
            wallDrawing?.points.append(snapped)
            wallDrawing?.typedLength = ""
        }
    }

    func handleWallPointerMove(at world: SIMD2<Double>, isShiftDown: Bool) -> SIMD2<Double>? {
        guard case .drawWall = tool, let layout = activeLayout else { return nil }
        let snapped = WallDrawing.snappedPoint(
            world,
            from: wallDrawing?.points.last,
            in: layout,
            pointsPerMetre: transform.scale,
            lockAngle: isShiftDown
        )

        if let typed = wallDrawing?.typedLength,
           let length = Double(typed),
           let last = wallDrawing?.points.last {
            return WallDrawing.point(from: last, toward: snapped, length: length)
        }
        return snapped
    }

    func handleWallKey(_ character: Character) -> Bool {
        guard case .drawWall = tool else { return false }
        if character.isNumber || character == "." {
            wallDrawing?.typedLength.append(character)
            return true
        }
        return false
    }

    func handleWallBackspace() -> Bool {
        guard case .drawWall = tool else { return false }
        if let typed = wallDrawing?.typedLength, !typed.isEmpty {
            wallDrawing?.typedLength.removeLast()
            return true
        }
        if let points = wallDrawing?.points, !points.isEmpty {
            wallDrawing?.points.removeLast()
            if wallDrawing?.points.isEmpty == true {
                wallDrawing = nil
            }
            return true
        }
        return false
    }

    func handleWallReturn(currentPointer: SIMD2<Double>?) -> Bool {
        guard case .drawWall = tool,
              let typed = wallDrawing?.typedLength,
              let length = Double(typed),
              let last = wallDrawing?.points.last,
              let pointer = currentPointer else {
            return false
        }
        let nextPoint = WallDrawing.point(from: last, toward: pointer, length: length)
        wallDrawing?.points.append(nextPoint)
        wallDrawing?.typedLength = ""
        return true
    }

    func finishWallDrawing() {
        guard case .drawWall(let itemID) = tool,
              let drawing = wallDrawing,
              drawing.points.count >= 2,
              let layout = activeLayout else {
            wallDrawing = nil
            selectTool(.select)
            return
        }

        let item = ObjectCatalog.item(itemID)
        let thickness = item?.sizeM.y ?? 0.2
        let height = item?.heightM ?? 3.0
        let kind = item?.kind ?? .wall

        let newObjects = drawing.objects(
            kind: kind,
            thickness: thickness,
            height: height,
            catalogID: itemID
        )

        if !newObjects.isEmpty {
            let edits: [LayoutEdit] = newObjects.enumerated().map { index, object in
                .insert(object, index: layout.objects.count + index)
            }
            withSingleRefresh {
                commitEdit(.batch(edits))
                if let lastID = newObjects.last?.id {
                    applySelection(lastID)
                }
            }
        }

        wallDrawing = nil
        selectTool(.select)
    }

    func cancelWallDrawing() {
        wallDrawing = nil
        selectTool(.select)
    }
}
