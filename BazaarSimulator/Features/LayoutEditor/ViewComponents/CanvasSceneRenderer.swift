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
        var floorLayout = snapshot.layout
        if let previewHall = drag.previewHall {
            floorLayout.hall = previewHall
        }
        FloorRenderer.draw(in: &context, size: size, transform: transform, layout: floorLayout)
        drawSceneObjects(in: &context, snapshot: snapshot, transform: transform, drag: drag)

        if snapshot.activeLayer == .booths {
            GroupOverlayRenderer.draw(snapshot.groupClusters, in: &context, transform: transform)
        }
        drawDragPreviews(drag: drag, snapshot: snapshot, in: &context, transform: transform)
        drawVisitorFlow(snapshot: snapshot, in: &context, transform: transform)
    }

    private static func drawVisitorFlow(
        snapshot: CanvasDisplaySnapshot,
        in context: inout GraphicsContext,
        transform: CanvasTransform
    ) {
        guard snapshot.showVisitorFlow else { return }
        for object in snapshot.layout.objects where object.kind == .door {
            DoorRenderer.drawDirectionArrows(
                direction: object.doorFlow?.direction ?? .both,
                placement: object.placement,
                in: &context,
                transform: transform
            )
        }
        MarkerRenderer.draw(
            markers: snapshot.layout.markers,
            showVisitorFlow: true,
            in: &context,
            transform: transform
        )
    }

    private static func drawSceneObjects(
        in context: inout GraphicsContext,
        snapshot: CanvasDisplaySnapshot,
        transform: CanvasTransform,
        drag: CanvasDragState
    ) {
        let colorsByID = Dictionary(uniqueKeysWithValues: snapshot.legend.entries.map { ($0.id, $0.color) })
        let ordered = LayoutHitTester.drawOrderedObjects(in: snapshot.layout)
        let marqueeIDs = marqueeTouchedIDs(drag: drag, snapshot: snapshot, transform: transform)

        var selectedObject: LayoutObject?
        var draggedObjects: [LayoutObject] = []
        for var object in ordered {
            guard !snapshot.hiddenLayers.contains(object.kind.layer) else { continue }
            if let previewPlacement = drag.previewPlacements[object.id] {
                object.placement = previewPlacement
            } else if object.id == drag.objectID {
                object.placement.center += drag.deltaWorld
            } else if object.id == drag.resize?.objectID {
                object.placement = drag.resize!.preview
            }
            if object.id == snapshot.selectionID {
                selectedObject = object
            } else if drag.previewPlacements[object.id] != nil {
                draggedObjects.append(object)
            }
            let isInactive = object.kind.layer != snapshot.activeLayer
            if isInactive {
                context.drawLayer { inactiveContext in
                    inactiveContext.opacity = 0.35
                    drawObject(object, snapshot: snapshot, colorsByID: colorsByID, marqueeIDs: marqueeIDs,
                               transform: transform, in: &inactiveContext)
                }
            } else {
                drawObject(object, snapshot: snapshot, colorsByID: colorsByID, marqueeIDs: marqueeIDs,
                           transform: transform, in: &context)
            }
        }
        drawPreviewInserts(
            drag: drag,
            snapshot: snapshot,
            colorsByID: colorsByID,
            transform: transform,
            in: &context
        )
        for dragged in draggedObjects {
            SelectionDimensionRenderer.drawDimensions(for: dragged, in: &context, transform: transform)
        }
        if let selectedObject, selectedObject.kind.layer == snapshot.activeLayer {
            drawSelectionDetails(selectedObject, drag: drag, in: &context, transform: transform)
        }
        WallNodeRenderer.draw(snapshot: snapshot, transform: transform, in: &context)
        HallEdgeHandleRenderer.draw(snapshot: snapshot, drag: drag, transform: transform, in: &context)
    }

    private static func drawPreviewInserts(
        drag: CanvasDragState,
        snapshot: CanvasDisplaySnapshot,
        colorsByID: [UUID: LegendColor],
        transform: CanvasTransform,
        in context: inout GraphicsContext
    ) {
        for inserted in drag.previewInserts {
            if inserted.kind == .booth {
                let isWarning = drag.previewWarningIDs.contains(inserted.id)
                let boothState = BoothDrawState(
                    booth: inserted,
                    displayLabel: BoothLabelFormatter.display(inserted.label),
                    isSelected: false,
                    isHovered: false,
                    isGroupMember: false,
                    isHoveredGroupMember: false,
                    hasObjectWarning: isWarning,
                    blockedSides: [],
                    categoryColor: nil
                )
                BoothRenderer.draw(boothState, in: &context, transform: transform)
            } else {
                drawObject(inserted, snapshot: snapshot, colorsByID: colorsByID, transform: transform, in: &context)
            }
        }
    }

    private static func drawObject(
        _ object: LayoutObject,
        snapshot: CanvasDisplaySnapshot,
        colorsByID: [UUID: LegendColor],
        marqueeIDs: Set<UUID> = [],
        transform: CanvasTransform,
        in context: inout GraphicsContext
    ) {
        let isInactive = object.kind.layer != snapshot.activeLayer
        let isMarqueed = !isInactive && marqueeIDs.contains(object.id)
        let isGroupMember = !isInactive && snapshot.groupMemberIDs.contains(object.id)
        let isHighlightedMember = object.kind != .booth && (isGroupMember || isMarqueed)
        let isSelected = !isInactive && (object.id == snapshot.selectionID || isHighlightedMember)
        let isHovered = !isInactive && object.id == snapshot.hoverID
        let hasWarning = snapshot.issues.warningObjectIDs.contains(object.id)
        let ext = object.kind == .wall
            ? WallCornerExtensions(layout: snapshot.layout).extensions(for: object.id)
            : (0.0, 0.0)
        let objectState = ObjectDrawState(
            object: object,
            isSelected: isSelected,
            isHovered: isHovered,
            hasWarning: hasWarning,
            cornerExtensions: ext
        )

        switch object.kind {
        case .booth:
            let boothState = BoothDrawState(
                booth: object,
                displayLabel: BoothLabelFormatter.display(object.label),
                isSelected: isSelected,
                isHovered: isHovered,
                isGroupMember: isGroupMember,
                isHoveredGroupMember: isMarqueed || (!isInactive && snapshot.hoveredGroupMemberIDs.contains(object.id)),
                hasObjectWarning: hasWarning,
                blockedSides: snapshot.issues.blockedSidesByBoothID[object.id] ?? [],
                categoryColor: object.categoryID.flatMap { colorsByID[$0] }
            )
            BoothRenderer.draw(boothState, in: &context, transform: transform)
        case .door:
            DoorRenderer.draw(objectState, in: &context, transform: transform)
        case .closedArea:
            BlockedAreaRenderer.draw(objectState, in: &context, transform: transform)
        default:
            ObstacleRenderer.draw(objectState, in: &context, transform: transform)
        }
    }

    private static func drawSelectionDetails(
        _ selectedObject: LayoutObject,
        drag: CanvasDragState,
        in context: inout GraphicsContext,
        transform: CanvasTransform
    ) {
        SelectionDimensionRenderer.drawDimensions(for: selectedObject, in: &context, transform: transform)
        if let text = drag.wallLengthChipText, let worldPoint = drag.wallLengthChipWorld {
            let viewPoint = transform.toView(worldPoint)
            SelectionDimensionRenderer.drawSizeChip(text, near: CGPoint(x: viewPoint.x, y: viewPoint.y), in: &context)
        } else if selectedObject.id == drag.objectID, let pointerLocation = drag.pointerLocation {
            SelectionDimensionRenderer.drawDragOffset(drag.deltaWorld, near: pointerLocation, in: &context)
        } else if drag.resize != nil, let pointerLocation = drag.pointerLocation {
            let widthText = DimensionInput.text(for: selectedObject.placement.sizeM.x)
            let lengthText = DimensionInput.text(for: selectedObject.placement.sizeM.y)
            let sizeText = "\(widthText) × \(lengthText) m"
            SelectionDimensionRenderer.drawSizeChip(sizeText, near: pointerLocation, in: &context)
        }
        if selectedObject.kind.hasResizeHandles {
            drawResizeHandles(for: selectedObject.placement, in: &context, transform: transform)
        }
    }
}

extension CanvasSceneRenderer {
    private static func drawDragPreviews(
        drag: CanvasDragState,
        snapshot: CanvasDisplaySnapshot,
        in context: inout GraphicsContext,
        transform: CanvasTransform
    ) {
        if drag.drawingStart != nil, drag.drawingCurrent != nil {
            drawDrawingPreview(
                drag: drag,
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
        } else if let pointer = drag.wallCurrentPointer {
            WallDrawingRenderer.draw(
                drawing: WallDrawing(),
                currentPointer: pointer,
                lockAngle: false,
                in: &context,
                transform: transform
            )
        }
        if let start = drag.marqueeStart, let current = drag.marqueeCurrent {
            drawMarqueePreview(start: start, current: current, in: &context, transform: transform)
        }
        if !drag.guides.isEmpty {
            drawGuides(drag.guides, in: &context, transform: transform)
        }
        if let text = drag.wallLengthChipText, let worldPoint = drag.wallLengthChipWorld, snapshot.selectionID == nil {
            let viewPoint = transform.toView(worldPoint)
            SelectionDimensionRenderer.drawSizeChip(text, near: CGPoint(x: viewPoint.x, y: viewPoint.y), in: &context)
        }
    }

    private static func marqueeTouchedIDs(
        drag: CanvasDragState,
        snapshot: CanvasDisplaySnapshot,
        transform: CanvasTransform
    ) -> Set<UUID> {
        guard let start = drag.marqueeStart, let current = drag.marqueeCurrent else { return [] }
        let viewStart = transform.toView(start)
        let viewCurrent = transform.toView(current)
        let delta = CGPoint(x: viewCurrent.x - viewStart.x, y: viewCurrent.y - viewStart.y)
        guard SelectGesture.isPastThreshold(delta) else { return [] }
        return SelectGesture.touchedObjects(
            from: start,
            to: current,
            layout: snapshot.layout,
            layer: snapshot.activeLayer
        )
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

    private static func drawGuides(
        _ guides: [SnapGuide],
        in context: inout GraphicsContext,
        transform: CanvasTransform
    ) {
        for guide in guides {
            let viewStart = transform.toView(guide.start)
            let viewEnd = transform.toView(guide.end)
            guard simd_distance(guide.start, guide.end) > 1e-4 else { continue }
            var path = Path()
            path.move(to: CGPoint(x: viewStart.x, y: viewStart.y))
            path.addLine(to: CGPoint(x: viewEnd.x, y: viewEnd.y))
            context.stroke(
                path,
                with: .color(Palette.accent.opacity(0.85)),
                style: StrokeStyle(lineWidth: 1.0, dash: [4, 4])
            )
        }
    }

    private static func drawDrawingPreview(
        drag: CanvasDragState,
        in context: inout GraphicsContext,
        transform: CanvasTransform
    ) {
        guard let start = drag.drawingStart, let current = drag.drawingCurrent else { return }
        let snaps = !drag.isOptionDown
        let placement = BlockedAreaDrawing.placement(from: start, to: current, snapped: snaps)
        let preview = placement ?? BlockedAreaDrawing.previewPlacement(
            from: start,
            to: current,
            snapped: snaps
        )
        let isBelowMinimum = placement == nil
        let tempArea = LayoutObject(kind: drag.drawingKind, label: "", placement: preview)
        let state = ObjectDrawState(
            object: tempArea,
            isSelected: !isBelowMinimum,
            isHovered: false,
            hasWarning: isBelowMinimum
        )
        BlockedAreaRenderer.draw(state, in: &context, transform: transform)

        let pointerView = transform.toView(current)
        let text = "\(DimensionInput.text(for: preview.sizeM.x)) × \(DimensionInput.text(for: preview.sizeM.y)) m"
        SelectionDimensionRenderer.drawSizeChip(text, near: CGPoint(x: pointerView.x, y: pointerView.y), in: &context)
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
