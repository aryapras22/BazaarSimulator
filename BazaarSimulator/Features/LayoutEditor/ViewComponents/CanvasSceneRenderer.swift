import SwiftUI
import simd

enum CanvasSceneRenderer {
    static func draw(
        in context: inout GraphicsContext,
        size: CGSize,
        snapshot: CanvasDisplaySnapshot,
        transform: CanvasTransform,
        drag: CanvasDragState
    ) {
        FloorRenderer.draw(in: &context, size: size, transform: transform, layout: snapshot.layout)
        drawSceneObjects(in: &context, snapshot: snapshot, transform: transform, drag: drag)

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

        if let candidate = drag.placementCandidate, let source = drag.placingSource {
            PlacementPreviewRenderer.draw(
                candidate: candidate,
                source: source,
                legend: snapshot.legend,
                in: &context,
                transform: transform
            )
        }

        if let wallDrawing = drag.wallDrawing {
            let isShiftDown = NSEvent.modifierFlags.contains(.shift)
            WallDrawingRenderer.draw(
                drawing: wallDrawing,
                currentPointer: drag.wallCurrentPointer,
                lockAngle: isShiftDown,
                in: &context,
                transform: transform
            )
        }

        if let start = drag.marqueeStart, let current = drag.marqueeCurrent {
            drawMarqueePreview(start: start, current: current, in: &context, transform: transform)
        }

        MarkerRenderer.draw(markers: snapshot.layout.markers, tab: snapshot.tab, in: &context, transform: transform)
    }

    private static func drawSceneObjects(
        in context: inout GraphicsContext,
        snapshot: CanvasDisplaySnapshot,
        transform: CanvasTransform,
        drag: CanvasDragState
    ) {
        let colorsByID = Dictionary(uniqueKeysWithValues: snapshot.legend.entries.map { ($0.id, $0.color) })
        let ordered = LayoutHitTester.drawOrderedObjects(in: snapshot.layout)

        var selectedObject: LayoutObject?
        for var object in ordered {
            if object.id == drag.objectID {
                object.placement.center += drag.deltaWorld
            } else if object.id == drag.resize?.objectID {
                object.placement = drag.resize!.preview
            }
            if object.id == snapshot.selectionID {
                selectedObject = object
            }
            drawObject(object, snapshot: snapshot, colorsByID: colorsByID, transform: transform, in: &context)
        }
        if let selectedObject {
            drawSelectionDetails(selectedObject, drag: drag, tab: snapshot.tab, in: &context, transform: transform)
        }
    }

    private static func drawMarqueePreview(
        start: SIMD2<Double>,
        current: SIMD2<Double>,
        in context: inout GraphicsContext,
        transform: CanvasTransform
    ) {
        let viewStart = transform.toView(start)
        let viewCurrent = transform.toView(current)
        let delta = CGPoint(x: viewCurrent.x - viewStart.x, y: viewCurrent.y - viewStart.y)
        guard SelectGesture.isPastThreshold(delta) else { return }
        let rect = CGRect(
            x: min(viewStart.x, viewCurrent.x),
            y: min(viewStart.y, viewCurrent.y),
            width: abs(viewCurrent.x - viewStart.x),
            height: abs(viewCurrent.y - viewStart.y)
        )
        let path = Path(rect)
        context.fill(path, with: .color(Palette.accent.opacity(0.12)))
        context.stroke(
            path,
            with: .color(Palette.accent.opacity(0.85)),
            style: StrokeStyle(lineWidth: 1.0, dash: [4, 4])
        )
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

    private static func drawSelectionDetails(
        _ selectedObject: LayoutObject,
        drag: CanvasDragState,
        tab: EditorTab,
        in context: inout GraphicsContext,
        transform: CanvasTransform
    ) {
        SelectionDimensionRenderer.drawDimensions(for: selectedObject, in: &context, transform: transform)
        if selectedObject.id == drag.objectID, let pointerLocation = drag.pointerLocation {
            SelectionDimensionRenderer.drawDragOffset(drag.deltaWorld, near: pointerLocation, in: &context)
        } else if drag.resize != nil, let pointerLocation = drag.pointerLocation {
            let widthText = DimensionInput.text(for: selectedObject.placement.sizeM.x)
            let lengthText = DimensionInput.text(for: selectedObject.placement.sizeM.y)
            let sizeText = "\(widthText) × \(lengthText) m"
            SelectionDimensionRenderer.drawSizeChip(sizeText, near: pointerLocation, in: &context)
        }
        if tab == .floorPlan && selectedObject.kind.hasResizeHandles {
            drawResizeHandles(for: selectedObject.placement, in: &context, transform: transform)
        }
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

    private static func drawResizeHandles(
        for placement: Placement,
        in context: inout GraphicsContext,
        transform: CanvasTransform
    ) {
        for handle in ResizeHandle.allCases {
            let world = PlacementResizing.handlePosition(for: handle, in: placement)
            let viewPt = transform.toView(world)
            let rect = CGRect(x: viewPt.x - 4, y: viewPt.y - 4, width: 8, height: 8)
            let path = Path(roundedRect: rect, cornerRadius: 2)
            context.fill(path, with: .color(Palette.surface))
            context.stroke(path, with: .color(Palette.canvasSelection), lineWidth: 1)
        }
    }
}
