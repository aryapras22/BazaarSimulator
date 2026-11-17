import AppKit
import SwiftUI

/// One entry of a sidebar row's right-click menu.
struct SidebarMenuItem {
    let title: String
    let symbol: String
    /// A destructive entry is drawn in red, text and icon, the way the delete entry looks in the design.
    var isDestructive = false
    let action: () -> Void
}

/// A right-click menu for a sidebar row. SwiftUI's own `contextMenu` ignores color on macOS, so the menu is built
/// from AppKit items here, which lets Delete be red. It sits over the row and only takes the right click, so the
/// row still gets every other click.
struct SidebarContextMenu: NSViewRepresentable {
    let items: [SidebarMenuItem]

    func makeNSView(context: Context) -> RightClickView {
        RightClickView()
    }

    func updateNSView(_ view: RightClickView, context: Context) {
        view.items = items
    }
}

final class RightClickView: NSView {
    var items: [SidebarMenuItem] = []
    private var runners: [MenuItemRunner] = []

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let event = NSApp.currentEvent else { return nil }
        let isRightClick = event.type == .rightMouseDown
            || (event.type == .leftMouseDown && event.modifierFlags.contains(.control))
        return isRightClick ? super.hitTest(point) : nil
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        guard !items.isEmpty else { return nil }
        let menu = NSMenu()
        runners = items.map(MenuItemRunner.init)
        for runner in runners {
            menu.addItem(runner.makeMenuItem())
        }
        return menu
    }
}

/// Holds an entry's action for AppKit, which calls it by selector.
private final class MenuItemRunner: NSObject {
    private let item: SidebarMenuItem

    init(_ item: SidebarMenuItem) {
        self.item = item
    }

    func makeMenuItem() -> NSMenuItem {
        let entry = NSMenuItem(title: item.title, action: #selector(run), keyEquivalent: "")
        entry.target = self

        let image = NSImage(systemSymbolName: item.symbol, accessibilityDescription: item.title)
        if item.isDestructive {
            let red = NSColor(Palette.destructive)
            entry.attributedTitle = NSAttributedString(
                string: item.title,
                attributes: [.foregroundColor: red, .font: NSFont.menuFont(ofSize: 0)]
            )
            entry.image = image?.withSymbolConfiguration(NSImage.SymbolConfiguration(paletteColors: [red]))
        } else {
            entry.image = image
        }
        return entry
    }

    @objc private func run() {
        item.action()
    }
}
