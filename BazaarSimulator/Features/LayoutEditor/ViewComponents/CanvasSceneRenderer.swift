import SwiftUI
import simd

struct CanvasDragState {
    var objectID: UUID?
    var deltaWorld: SIMD2<Double>
    var pointerLocation: CGPoint?
    var drawingStart: SIMD2<Double>?
    var drawingCurrent: SIMD2<Double>?
    var isOptionDown: Bool = false
}

enum CanvasSceneRenderer {
    static func draw(
        in context: inout GraphicsContext,
        size: CGSize,
        snapshot: CanvasDisplaySnapshot,
        transform: CanvasTransform,
        drag: CanvasDragState
    ) {
        FloorRenderer.draw(in: &context, size: size, transform: transform, layout: snapshot.layout)

        let colorsByID = Dictionary(uniqueKeysWithValues: snapshot.legend.entries.map { ($0.id, $0.color) })
        let ordered = LayoutHitTester.drawOrderedObjects(in: snapshot.layout)

        var selectedObject: LayoutObject?
        for var object in ordered {
            if object.id == drag.objectID {
                object.placement.center += drag.deltaWorld
            }
            if object.id == snapshot.selectionID {
                selectedObject = object
            }
            drawObject(object, snapshot: snapshot, colorsByID: colorsByID, transform: transform, in: &context)
        }
        if let selectedObject {
            SelectionDimensionRenderer.drawDimensions(for: selectedObject, in: &context, transform: transform)
            if selectedObject.id == drag.objectID, let pointerLocation = drag.pointerLocation {
                SelectionDimensionRenderer.drawDragOffset(drag.deltaWorld, near: pointerLocation, in: &context)
            }
        }

        if snapshot.tab == .floorPlan {
            GroupOverlayRenderer.draw(snapshot.groupClusters, in: &context, transform: transform)
        }

        if let start = drag.drawingStart, let current = drag.drawingCurrent {
            drawDrawingPreview(
                start: start,
                current: current,
                snaps: !drag.isOptionDown,
                in: &context,
                transform: transform
            )
        }

        MarkerRenderer.draw(markers: snapshot.layout.markers, tab: snapshot.tab, in: &context, transform: transform)
    }

    private static func drawDrawingPreview(
        start: SIMD2<Double>,
        current: SIMD2<Double>,
        snaps: Bool,
        in context: inout GraphicsContext,
        transform: CanvasTransform
    ) {
        let placement = BlockedAreaDrawing.placement(from: start, to: current, snapped: snaps)
        let preview = placement ?? BlockedAreaDrawing.previewPlacement(
            from: start,
            to: current,
            snapped: snaps
        )
        let isBelowMinimum = placement == nil
        let tempArea = LayoutObject(kind: .closedArea, label: "", placement: preview)
        let state = ObjectDrawState(
            object: tempArea,
            tab: .floorPlan,
            isSelected: !isBelowMinimum,
            isHovered: false,
            hasWarning: isBelowMinimum
        )
        BlockedAreaRenderer.draw(state, in: &context, transform: transform)

        let pointerView = transform.toView(current)
        let text = "\(DimensionInput.text(for: preview.sizeM.x)) × \(DimensionInput.text(for: preview.sizeM.y)) m"
        SelectionDimensionRenderer.drawSizeChip(text, near: CGPoint(x: pointerView.x, y: pointerView.y), in: &context)
    }

    private static func drawObject(
        _ object: LayoutObject,
        snapshot: CanvasDisplaySnapshot,
        colorsByID: [UUID: LegendColor],
        transform: CanvasTransform,
        in context: inout GraphicsContext
    ) {
        let isSelected = object.id == snapshot.selectionID
        let isHovered = object.id == snapshot.hoverID
        let hasWarning = snapshot.issues.warningObjectIDs.contains(object.id)
        let objectState = ObjectDrawState(
            object: object,
            tab: snapshot.tab,
            isSelected: isSelected,
            isHovered: isHovered,
            hasWarning: hasWarning
        )

        switch object.kind {
        case .booth:
            let boothState = BoothDrawState(
                booth: object,
                displayLabel: BoothLabelFormatter.display(object.label),
                tab: snapshot.tab,
                isSelected: isSelected,
                isHovered: isHovered,
                isGroupMember: snapshot.groupMemberIDs.contains(object.id),
                isHoveredGroupMember: snapshot.hoveredGroupMemberIDs.contains(object.id),
                hasObjectWarning: hasWarning,
                blockedSides: snapshot.issues.blockedSidesByBoothID[object.id] ?? [],
                categoryColor: object.categoryID.flatMap { colorsByID[$0] }
            )
            BoothRenderer.draw(boothState, in: &context, transform: transform)
        case .table:
            SeatingRenderer.draw(objectState, in: &context, transform: transform)
        case .door:
            DoorRenderer.draw(objectState, in: &context, transform: transform)
        case .closedArea:
            BlockedAreaRenderer.draw(objectState, in: &context, transform: transform)
        default:
            ObstacleRenderer.draw(objectState, in: &context, transform: transform)
        }
    }
}
