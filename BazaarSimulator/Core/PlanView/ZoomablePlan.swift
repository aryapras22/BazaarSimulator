
import SwiftUI

enum PlanZoom {
    static let range: ClosedRange<CGFloat> = 1...4
    static let step: CGFloat = 1.5

    static func clamp(_ value: CGFloat) -> CGFloat {
        min(max(value, range.lowerBound), range.upperBound)
    }
}

struct ZoomablePlan<Content: View>: View {
    @Binding var zoom: CGFloat
    @ViewBuilder let content: Content

    @State private var pinchStart: CGFloat?
    @State private var pan: CGSize = .zero
    @State private var dragStart: CGSize?

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            content
                .frame(width: size.width * zoom, height: size.height * zoom)
                .offset(clamped(pan, in: size))
                .frame(width: size.width, height: size.height)
                .clipped()
                .contentShape(Rectangle())
                .gesture(pinch)
                .simultaneousGesture(drag(in: size), isEnabled: zoom > 1)
                .onChange(of: zoom, rescalePan)
                .accessibilityZoomAction(zoom(with:))
        }
    }

    private func rescalePan(from old: CGFloat, to new: CGFloat) {
        let ratio = new / old
        pan = new <= 1 ? .zero : CGSize(width: pan.width * ratio, height: pan.height * ratio)
    }

    private func zoom(with action: AccessibilityZoomGestureAction) {
        let factor = action.direction == .zoomIn ? PlanZoom.step : 1 / PlanZoom.step
        zoom = PlanZoom.clamp(zoom * factor)
    }

    private var pinch: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let start = pinchStart ?? zoom
                pinchStart = start
                zoom = PlanZoom.clamp(start * value.magnification)
            }
            .onEnded { _ in pinchStart = nil }
    }

    private func drag(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                let start = dragStart ?? clamped(pan, in: size)
                dragStart = start
                let moved = CGSize(width: start.width + value.translation.width, height: start.height + value.translation.height)
                pan = clamped(moved, in: size)
            }
            .onEnded { _ in dragStart = nil }
    }

    private func clamped(_ offset: CGSize, in size: CGSize) -> CGSize {
        let limitX = size.width * (zoom - 1) / 2, limitY = size.height * (zoom - 1) / 2
        return CGSize(width: min(max(offset.width, -limitX), limitX), height: min(max(offset.height, -limitY), limitY))
    }
}
