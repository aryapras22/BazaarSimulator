import AppKit
import SwiftUI
import simd

struct CanvasScrollCatcher: NSViewRepresentable {
    var excludedTrailingWidth: CGFloat = 0
    var onScroll: (_ delta: CGSize, _ location: CGPoint, _ isPreciseScrolling: Bool, _ isCommandDown: Bool) -> Void
    var onPan: ((_ delta: SIMD2<Double>) -> Void)?

    func makeNSView(context: Context) -> ScrollCatcherView {
        let view = ScrollCatcherView()
        view.excludedTrailingWidth = excludedTrailingWidth
        view.onScroll = onScroll
        view.onPan = onPan
        return view
    }

    func updateNSView(_ nsView: ScrollCatcherView, context: Context) {
        nsView.excludedTrailingWidth = excludedTrailingWidth
        nsView.onScroll = onScroll
        nsView.onPan = onPan
    }

    final class ScrollCatcherView: NSView {
        var excludedTrailingWidth: CGFloat = 0
        var onScroll: ((CGSize, CGPoint, Bool, Bool) -> Void)?
        var onPan: ((SIMD2<Double>) -> Void)?
        private var monitor: Any?

        override var isFlipped: Bool { true }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window != nil && monitor == nil {
                let mask: NSEvent.EventTypeMask = [.scrollWheel, .otherMouseDragged]
                monitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
                    if event.type == .scrollWheel {
                        self?.handleScroll(event)
                    } else if event.type == .otherMouseDragged {
                        self?.handleOtherMouseDragged(event)
                    }
                    return event
                }
            } else if window == nil, let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }

        private func handleScroll(_ event: NSEvent) {
            guard let window, event.window === window else { return }
            let location = convert(event.locationInWindow, from: nil)
            guard bounds.contains(location) else { return }
            guard location.x < bounds.width - excludedTrailingWidth else { return }
            onScroll?(
                CGSize(width: event.scrollingDeltaX, height: event.scrollingDeltaY),
                location,
                event.hasPreciseScrollingDeltas,
                event.modifierFlags.contains(.command)
            )
        }

        private func handleOtherMouseDragged(_ event: NSEvent) {
            guard let window, event.window === window else { return }
            let location = convert(event.locationInWindow, from: nil)
            guard bounds.contains(location) else { return }
            guard location.x < bounds.width - excludedTrailingWidth else { return }
            guard event.buttonNumber == 2 else { return }
            onPan?(SIMD2<Double>(Double(event.deltaX), Double(event.deltaY)))
        }
    }
}
