import SwiftUI
import simd

enum CanvasContextAction: Sendable, Equatable {
    case rotateSelected
    case duplicateSelected
    case resetOpenSides
    case deleteSelected
    case addObject(kind: LayoutObjectKind, atWorld: SIMD2<Double>)
}

struct CanvasIssueSnapshot: Sendable, Equatable {
    var warningObjectIDs: Set<UUID> = []
    var blockedSidesByBoothID: [UUID: OpenSides] = [:]
}

struct CanvasDisplaySnapshot: Sendable {
    var layout: Layout
    var legend: Legend
    var tab: EditorTab
    var selectionID: UUID?
    var hoverID: UUID?
    var issues: CanvasIssueSnapshot = CanvasIssueSnapshot()
}

struct LayoutCanvasView: View {
    let snapshot: CanvasDisplaySnapshot
    @Binding var transform: CanvasTransform
    var onSelect: (UUID?) -> Void = { _ in }
    var onHover: (UUID?) -> Void = { _ in }
    var onDragEnded: (UUID, SIMD2<Double>, Bool) -> Void = { _, _, _ in }
    var onContextAction: (CanvasContextAction) -> Void = { _ in }

    @State private var activeDragObjectID: UUID?
    @State private var activeDragDeltaWorld: SIMD2<Double> = .zero
    @State private var lastPanLocation: CGPoint?
    @State private var hoverTracker = HoverTracker()
    @State private var lastHoverHit: UUID?
    @State private var hasFittedInitially = false

    private final class HoverTracker {
        var world: SIMD2<Double> = .zero
    }

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                drawScene(in: &context, size: size)
            }
            .background(Palette.background)
            .contentShape(Rectangle())
            .onAppear {
                if !hasFittedInitially {
                    hasFittedInitially = true
                    fitLayout(in: proxy.size)
                }
            }
            .onHover { isHovering in
                if !isHovering && lastHoverHit != nil {
                    lastHoverHit = nil
                    onHover(nil)
                }
            }
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    let world = transform.toWorld(SIMD2<Double>(location.x, location.y))
                    hoverTracker.world = world
                    let hit = LayoutHitTester.object(at: world, in: snapshot.layout, tab: snapshot.tab)
                    if hit != lastHoverHit {
                        lastHoverHit = hit
                        onHover(hit)
                    }
                case .ended:
                    if lastHoverHit != nil {
                        lastHoverHit = nil
                        onHover(nil)
                    }
                }
            }
            .gesture(canvasGesture)
            .simultaneousGesture(magnificationGesture(in: proxy.size))
            .contextMenu {
                contextMenuContent
            }
        }
    }

    private var canvasGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                handleDragChanged(value)
            }
            .onEnded { value in
                handleDragEnded(value)
            }
    }

    private func magnificationGesture(in size: CGSize) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let center = SIMD2<Double>(Double(size.width) / 2.0, Double(size.height) / 2.0)
                let deltaFactor = Double(value.magnification)
                if deltaFactor > 0.5 && deltaFactor < 2.0 {
                    transform = transform.zoomed(by: 1.0 + (deltaFactor - 1.0) * 0.08, around: center)
                }
            }
    }

    @ViewBuilder
    private var contextMenuContent: some View {
        if snapshot.tab == .floorPlan {
            if let selectedID = snapshot.selectionID,
               let selected = snapshot.layout.objects.first(where: { $0.id == selectedID }) {
                if selected.kind.isRotatable {
                    Button("Rotate 90°") {
                        onContextAction(.rotateSelected)
                    }
                }
                Button("Duplicate") {
                    onContextAction(.duplicateSelected)
                }
                if selected.kind == .booth {
                    Button("Reset open sides") {
                        onContextAction(.resetOpenSides)
                    }
                }
                Divider()
                Button("Delete", role: .destructive) {
                    onContextAction(.deleteSelected)
                }
            } else {
                Button("Add Booth Here") {
                    onContextAction(.addObject(kind: .booth, atWorld: hoverTracker.world))
                }
                Button("Add Table Here") {
                    onContextAction(.addObject(kind: .table, atWorld: hoverTracker.world))
                }
                Button("Add Fixture Here") {
                    onContextAction(.addObject(kind: .fixture, atWorld: hoverTracker.world))
                }
                Button("Add Rail Here") {
                    onContextAction(.addObject(kind: .rail, atWorld: hoverTracker.world))
                }
            }
        }
    }

    private func fitLayout(in size: CGSize) {
        let viewSize = SIMD2<Double>(Double(size.width), Double(size.height))
        transform = CanvasTransform.fitting(layoutSize: snapshot.layout.sizeM, in: viewSize)
    }

    private func handleDragChanged(_ value: DragGesture.Value) {
        let distance = hypot(value.translation.width, value.translation.height)
        guard distance >= 2.0 else { return }

        if activeDragObjectID == nil && lastPanLocation == nil {
            let startWorld = transform.toWorld(SIMD2<Double>(value.startLocation.x, value.startLocation.y))
            if let hitID = LayoutHitTester.object(at: startWorld, in: snapshot.layout, tab: snapshot.tab),
               let object = snapshot.layout.objects.first(where: { $0.id == hitID }),
               object.kind.isMovable {
                if snapshot.selectionID != hitID {
                    onSelect(hitID)
                }
                activeDragObjectID = hitID
            } else {
                lastPanLocation = value.startLocation
            }
        }

        if activeDragObjectID != nil {
            activeDragDeltaWorld = SIMD2<Double>(
                Double(value.translation.width) / transform.scale,
                Double(value.translation.height) / transform.scale
            )
        } else if let previous = lastPanLocation {
            let delta = SIMD2<Double>(
                Double(value.location.x - previous.x),
                Double(value.location.y - previous.y)
            )
            transform = transform.panned(by: delta)
            lastPanLocation = value.location
        }
    }

    private func handleDragEnded(_ value: DragGesture.Value) {
        let distance = hypot(value.translation.width, value.translation.height)
        if let draggedID = activeDragObjectID {
            let isOptionDown = NSEvent.modifierFlags.contains(.option)
            onDragEnded(draggedID, activeDragDeltaWorld, isOptionDown)
            activeDragObjectID = nil
            activeDragDeltaWorld = .zero
            return
        }
        lastPanLocation = nil
        if distance < 2.0 {
            let clickWorld = transform.toWorld(SIMD2<Double>(value.location.x, value.location.y))
            let hitID = LayoutHitTester.object(at: clickWorld, in: snapshot.layout, tab: snapshot.tab)
            onSelect(hitID)
        }
    }

    private func drawScene(in context: inout GraphicsContext, size: CGSize) {
        FloorRenderer.draw(in: &context, size: size, transform: transform, layout: snapshot.layout)

        let colorsByID = Dictionary(uniqueKeysWithValues: snapshot.legend.entries.map { ($0.id, $0.color) })
        let ordered = LayoutHitTester.drawOrderedObjects(in: snapshot.layout)

        for var object in ordered where object.kind != .closedArea {
            if object.id == activeDragObjectID {
                object.placement.center += activeDragDeltaWorld
            }
            drawObject(object, colorsByID: colorsByID, in: &context)
        }

        MarkerRenderer.draw(markers: snapshot.layout.markers, tab: snapshot.tab, in: &context, transform: transform)
    }

    private func drawObject(
        _ object: LayoutObject,
        colorsByID: [UUID: LegendColor],
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
                hasObjectWarning: hasWarning,
                blockedSides: snapshot.issues.blockedSidesByBoothID[object.id] ?? [],
                categoryColor: object.categoryID.flatMap { colorsByID[$0] }
            )
            BoothRenderer.draw(boothState, in: &context, transform: transform)
        case .table:
            SeatingRenderer.draw(objectState, in: &context, transform: transform)
        case .door:
            DoorRenderer.draw(objectState, in: &context, transform: transform)
        default:
            ObstacleRenderer.draw(objectState, in: &context, transform: transform)
        }
    }
}

#Preview("Annyeong Floor Plan") {
    @Previewable @State var transform = CanvasTransform()
    let layout = PreviewLayouts.annyeong()
    LayoutCanvasView(
        snapshot: CanvasDisplaySnapshot(
            layout: layout,
            legend: PreviewLayouts.sampleLegend,
            tab: .floorPlan,
            selectionID: layout.objects.first { $0.kind == .booth }?.id
        ),
        transform: $transform
    )
    .frame(width: 900, height: 650)
    .preferredColorScheme(.dark)
}

#Preview("Beyond Flow") {
    @Previewable @State var transform = CanvasTransform()
    let layout = PreviewLayouts.beyond()
    LayoutCanvasView(
        snapshot: CanvasDisplaySnapshot(
            layout: layout,
            legend: PreviewLayouts.sampleLegend,
            tab: .flow,
            selectionID: layout.objects.first { $0.kind == .door }?.id
        ),
        transform: $transform
    )
    .frame(width: 900, height: 650)
    .preferredColorScheme(.dark)
}

#Preview("Validation Issue & Zoomed Labels") {
    @Previewable @State var transform = CanvasTransform(scale: 20, offset: SIMD2<Double>(50, 50))
    let layout = PreviewLayouts.smallMarket()
    let boothID = layout.objects.first { $0.kind == .booth }?.id ?? UUID()
    LayoutCanvasView(
        snapshot: CanvasDisplaySnapshot(
            layout: layout,
            legend: PreviewLayouts.sampleLegend,
            tab: .floorPlan,
            selectionID: boothID,
            issues: CanvasIssueSnapshot(
                warningObjectIDs: [boothID],
                blockedSidesByBoothID: [boothID: .right]
            )
        ),
        transform: $transform
    )
    .frame(width: 900, height: 650)
    .preferredColorScheme(.dark)
}
