import Foundation
import CoreGraphics
import simd

struct ActiveResize: Equatable, Sendable {
    var objectID: UUID
    var handle: ResizeHandle
    var initialPlacement: Placement
    var preview: Placement
}

struct CanvasDragState: Equatable, Sendable {
    var objectID: UUID?
    var deltaWorld: SIMD2<Double> = .zero
    var pointerLocation: CGPoint?
    var drawingStart: SIMD2<Double>?
    var drawingCurrent: SIMD2<Double>?
    var drawingKind: LayoutObjectKind = .closedArea
    var isOptionDown: Bool = false
    var isShiftDown: Bool = false
    var resize: ActiveResize?
    var placementCandidate: PlacementCandidate?
    var placingSource: LibraryRowDisplay.Source?
    var wallDrawing: WallDrawing?
    var wallCurrentPointer: SIMD2<Double>?
    var marqueeStart: SIMD2<Double>?
    var marqueeCurrent: SIMD2<Double>?
    var previewPlacements: [UUID: Placement] = [:]
    var previewInserts: [LayoutObject] = []
    var guides: [SnapGuide] = []
    var wallLengthChipText: String?
    var wallLengthChipWorld: SIMD2<Double>?
}
