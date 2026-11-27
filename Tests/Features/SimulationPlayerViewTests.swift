import AppKit
import Foundation
import Testing
@testable import BazaarSimulator

@MainActor
@Suite
struct SimulationPlayerViewTests {
    private func space(inWindow windowNumber: Int) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: windowNumber,
            context: nil, characters: " ", charactersIgnoringModifiers: " ", isARepeat: false, keyCode: 49
        )!
    }

    @Test("Space is handled only for the player's window")
    func spaceOnlyInThePlayerWindow() {
        #expect(SimulationPlayerView.handlesSpace(space(inWindow: 7), windowNumber: 7))
        #expect(!SimulationPlayerView.handlesSpace(space(inWindow: 8), windowNumber: 7))
        #expect(!SimulationPlayerView.handlesSpace(space(inWindow: 7), windowNumber: nil))
    }
}
