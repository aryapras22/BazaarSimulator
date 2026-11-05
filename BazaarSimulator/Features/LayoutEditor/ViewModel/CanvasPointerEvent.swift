import Foundation
import CoreGraphics
import simd
#if canImport(AppKit)
import AppKit
#endif
#if canImport(SwiftUI)
import SwiftUI
#endif

enum CanvasMouseButton: Sendable, Equatable, Hashable {
    case left
    case right
    case middle
}

struct CanvasModifiers: OptionSet, Sendable, Equatable, Hashable {
    let rawValue: Int

    static let shift = CanvasModifiers(rawValue: 1 << 0)
    static let option = CanvasModifiers(rawValue: 1 << 1)
    static let command = CanvasModifiers(rawValue: 1 << 2)
    static let control = CanvasModifiers(rawValue: 1 << 3)
}

#if canImport(AppKit)
extension CanvasModifiers {
    init(modifierFlags: NSEvent.ModifierFlags) {
        var modifiers: CanvasModifiers = []
        if modifierFlags.contains(.shift) { modifiers.insert(.shift) }
        if modifierFlags.contains(.option) { modifiers.insert(.option) }
        if modifierFlags.contains(.command) { modifiers.insert(.command) }
        if modifierFlags.contains(.control) { modifiers.insert(.control) }
        self = modifiers
    }
}
#endif

#if canImport(SwiftUI)
extension CanvasModifiers {
    init(eventModifiers: EventModifiers) {
        var modifiers: CanvasModifiers = []
        if eventModifiers.contains(.shift) { modifiers.insert(.shift) }
        if eventModifiers.contains(.option) { modifiers.insert(.option) }
        if eventModifiers.contains(.command) { modifiers.insert(.command) }
        if eventModifiers.contains(.control) { modifiers.insert(.control) }
        self = modifiers
    }
}
#endif

struct CanvasPointerEvent: Sendable, Equatable {
    var worldPoint: SIMD2<Double>
    var viewPoint: CGPoint = .zero
    var button: CanvasMouseButton = .left
    var modifiers: CanvasModifiers = []
    var hitObjectID: UUID?
    var pointsPerMetre: Double = 10.0
}
