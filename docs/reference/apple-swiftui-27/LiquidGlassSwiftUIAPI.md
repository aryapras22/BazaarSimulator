# Liquid Glass: SwiftUI API reference

> Signatures and availability as published on developer.apple.com, fetched 3 November 2026. Examples are short illustrations of the documented behavior. Each heading links the official page. "macOS 26" means macOS 26.0 and later unless stated.

## Availability at a glance

| API | iOS / iPadOS | macOS | tvOS | watchOS | visionOS |
| --- | --- | --- | --- | --- | --- |
| `Glass`, `glassEffect(_:in:)`, `GlassEffectContainer`, `glassEffectID`, `glassEffectUnion`, `glassEffectTransition`, `GlassEffectTransition` | 26 | 26 | 26 | 26 | no |
| `.buttonStyle(.glass)`, `.glassProminent`, `.glass(_:)` | 26 | 26 | 26 | 26 | no |
| `GlassButtonStyle.init(_:)` | 26.1 | 26.1 | 26.1 | 26.1 | no |
| `ConcentricRectangle`, `.rect(corners:isUniform:)` | 26 | 26 | 26 | 26 | 26 |
| `backgroundExtensionEffect()` | 26 | 26 | 26 | 26 | 26 |
| `scrollEdgeEffectStyle(_:for:)`, `scrollEdgeEffectHidden(_:for:)` | 26 | 26 | 26 | 26 | style type only |
| `safeAreaBar(edge:alignment:spacing:content:)` | 26 | 26 | 26 | 26 | 26 |
| `ToolbarSpacer`, `sharedBackgroundVisibility(_:)` | 26 | 26 | no | no | no |
| `visibilityPriority(_:)`, `ToolbarItemVisibilityPriority` | 27 | 26.1 | 27 | 27 | 27 |
| `toolbarMinimizationBehavior(_:for:)` | 27 | 27 | 27 | 27 | 27 |
| `ToolbarOverflowMenu` | 27 | no (Mac Catalyst 27 only) | no | no | 27 |
| `tabBarMinimizeBehavior(_:)` | 26 | 26 | 26 | 26 | 26 |

Mac Catalyst follows the iOS column. `glassBackgroundEffect(displayMode:)` is a visionOS API for window glass and is not the same as `glassEffect`.

* * *

## Glass

[`Glass`](https://developer.apple.com/documentation/swiftui/glass) configures the material. Pass it to `glassEffect(_:in:)` or to the `glass(_:)` button style.

```swift
struct Glass
static var regular: Glass   // default; blurs and adjusts luminosity for legibility
static var clear: Glass     // highly translucent; for components over rich media
static var identity: Glass  // no effect; content renders as if no glass were applied
func tint(_ color: Color?) -> Glass
func interactive(_ isEnabled: Bool = true) -> Glass
```

*   `tint(_:)` suggests prominence. Pass `nil` to remove a tint.
*   `interactive(_:)` makes a custom element react to touch and pointer input the way glass buttons do.
*   `identity` is useful to switch glass off conditionally without changing the view structure.
*   With `clear`, keep content legible by putting a dimming layer under it, for example `.background(.black.opacity(0.3))`.

```swift
Label("Flag", systemImage: "flag.fill")
    .padding()
    .glassEffect(.regular.tint(.orange).interactive())
```

## glassEffect(_:in:)

[`glassEffect(_:in:)`](https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:))

```swift
nonisolated func glassEffect(
    _ glass: Glass = .regular,
    in shape: some Shape = DefaultGlassEffectShape()
) -> some View
```

*   Draws a glass shape anchored behind the view and applies glass foreground effects over it.
*   Defaults: `regular` variant, `Capsule` shape.
*   The glass fills the view's bounds, padding included, so add padding before the modifier.
*   Put it after the modifiers that affect the view's appearance; the modifier captures the content to render.
*   Use a rounded rectangle for larger elements where a capsule would look wrong: `.glassEffect(in: .rect(cornerRadius: 16))`.

## GlassEffectContainer

[`GlassEffectContainer`](https://developer.apple.com/documentation/swiftui/glasseffectcontainer)

```swift
@MainActor @preconcurrency struct GlassEffectContainer<Content> where Content: View
init(spacing:content:)   // spacing controls when shapes blend; see the linked page for the exact parameter types
```

*   Wrap every group of glass views in one container. It renders them together (better performance) and lets their shapes blend and morph.
*   `spacing` controls when shapes start to merge: the larger it is, the earlier neighbouring glass shapes blend. If the container's spacing is larger than the spacing of the stack inside it, the shapes blend even at rest.
*   Avoid many separate containers on one screen; that also costs performance.

```swift
GlassEffectContainer(spacing: 16) {
    VStack(spacing: 8) {
        Button("Zoom in", systemImage: "plus") { zoomIn() }
            .labelStyle(.iconOnly)
            .padding(10)
            .glassEffect(.regular.interactive())
        Button("Zoom out", systemImage: "minus") { zoomOut() }
            .labelStyle(.iconOnly)
            .padding(10)
            .glassEffect(.regular.interactive())
    }
}
```

## glassEffectUnion(id:namespace:)

[`glassEffectUnion(id:namespace:)`](https://developer.apple.com/documentation/swiftui/view/glasseffectunion(id:namespace:))

```swift
@MainActor @preconcurrency func glassEffectUnion(
    id: (some Hashable & Sendable)?,
    namespace: Namespace.ID
) -> some View
```

Merges the glass of several views into one shape at rest. Effects with the same union ID, the same shape, and the same glass variant combine. Useful for views created dynamically or not sharing one stack.

## glassEffectID(_:in:) and glassEffectTransition(_:)

[`glassEffectID(_:in:)`](https://developer.apple.com/documentation/swiftui/view/glasseffectid(_:in:)), [`glassEffectTransition(_:)`](https://developer.apple.com/documentation/swiftui/view/glasseffecttransition(_:)), [`GlassEffectTransition`](https://developer.apple.com/documentation/swiftui/glasseffecttransition)

```swift
nonisolated func glassEffectID(_ id: (some Hashable & Sendable)?, in namespace: Namespace.ID) -> some View
@MainActor @preconcurrency func glassEffectTransition(_ transition: GlassEffectTransition) -> some View

struct GlassEffectTransition {
    static var matchedGeometry: GlassEffectTransition  // default for effects within the container's spacing
    static var materialize: GlassEffectTransition      // fades content and animates the material in or out, no geometry matching
    static var identity: GlassEffectTransition         // no change
}
```

*   Give each glass view a unique ID in a `@Namespace` so SwiftUI morphs the right shapes when views appear or disappear.
*   Both modifiers only matter during view hierarchy changes and animations, inside a `GlassEffectContainer`.
*   Use `matchedGeometry` for effects close together (within the container's spacing) and `materialize` for effects farther apart, triggered with `withAnimation`.

```swift
@State private var isExpanded = false
@Namespace private var glass

var body: some View {
    GlassEffectContainer(spacing: 40) {
        HStack(spacing: 40) {
            Image(systemName: "scribble.variable")
                .frame(width: 80, height: 80)
                .glassEffect()
                .glassEffectID("pencil", in: glass)
            if isExpanded {
                Image(systemName: "eraser.fill")
                    .frame(width: 80, height: 80)
                    .glassEffect()
                    .glassEffectID("eraser", in: glass)
            }
        }
    }
    Button("Toggle") { withAnimation { isExpanded.toggle() } }
        .buttonStyle(.glass)
}
```

* * *

## Glass button styles

[`glass`](https://developer.apple.com/documentation/swiftui/primitivebuttonstyle/glass), [`glassProminent`](https://developer.apple.com/documentation/swiftui/primitivebuttonstyle/glassprominent), [`glass(_:)`](https://developer.apple.com/documentation/swiftui/primitivebuttonstyle/glass(_:)), [`GlassButtonStyle`](https://developer.apple.com/documentation/swiftui/glassbuttonstyle)

```swift
static var glass: GlassButtonStyle                  // like .bordered, in glass
static var glassProminent: GlassProminentButtonStyle // like .borderedProminent, in glass
static func glass(_ glass: Glass) -> Self            // configurable variant or tint
GlassButtonStyle.init()
GlassButtonStyle.init(_ glass: Glass)                // 26.1
```

```swift
Button("Done") { save() }
    .buttonStyle(.glassProminent)

Button("Flag") { flag() }
    .buttonStyle(.glass(.clear))
```

Prefer these over building glass buttons by hand. They apply to a button or to a container of buttons. In tvOS they show glass whether or not the button has focus. AppKit equivalent: `NSButton.BezelStyle.glass`.

* * *

## Concentric shapes

[`ConcentricRectangle`](https://developer.apple.com/documentation/swiftui/concentricrectangle)

A rectangle whose corners can each be concentric with the container's corners, concentric with a minimum radius, a fixed radius, or square. The radius is computed from the container shape, so it adapts across devices and window sizes without hard-coded values.

```swift
ConcentricRectangle()                                   // every corner concentric
ConcentricRectangle(
    topLeadingCorner: .concentric(minimum: 12),
    topTrailingCorner: .fixed(24),
    bottomLeadingCorner: .concentric,
    bottomTrailingCorner: .fixed(0)
)
ConcentricRectangle(uniformTopCorners: .fixed(24), uniformBottomCorners: .concentric)
```

*   Corner styles come from `Edge.Corner.Style`: `.concentric`, `.concentric(minimum:)`, `.fixed(_:)`.
*   Every initializer has a `Shape` shorthand: `.rect(corners:isUniform:)`, `.rect(topLeadingCorner:topTrailingCorner:bottomLeadingCorner:bottomTrailingCorner:)`, and uniform variants for top, bottom, leading, and trailing pairs.
*   A corner far from the container's corner may resolve to radius 0; use `.concentric(minimum:)` to keep it rounded.
*   System views provide container shapes. In custom views, set one with `containerShape(_:)` using a shape that conforms to `RoundedRectangularShape` (`Rectangle`, `RoundedRectangle`, `Capsule`, `Circle`).

* * *

## Background extension

[`backgroundExtensionEffect()`](https://developer.apple.com/documentation/swiftui/view/backgroundextensioneffect())

```swift
@MainActor @preconcurrency func backgroundExtensionEffect() -> some View
```

Duplicates the view into mirrored copies on every edge that has safe area, and blurs them. The typical use is a hero image in the detail column of a `NavigationSplitView` that should appear to continue under the sidebar or inspector. It clips the view so copies do not overlap. Use it on a single background view at a time. Put overlays (titles, buttons) after the modifier so only the image extends. AppKit: `NSBackgroundExtensionView`.

```swift
NavigationSplitView {
    Sidebar()
} detail: {
    BannerImage()
        .backgroundExtensionEffect()
        .overlay(alignment: .bottomLeading) { BannerTitle() }
}
.inspector(isPresented: $showsInspector) { Inspector() }
```

* * *

## Scroll edge effects and custom bars

[`scrollEdgeEffectStyle(_:for:)`](https://developer.apple.com/documentation/swiftui/view/scrolledgeeffectstyle(_:for:)), [`ScrollEdgeEffectStyle`](https://developer.apple.com/documentation/swiftui/scrolledgeeffectstyle), [`scrollEdgeEffectHidden(_:for:)`](https://developer.apple.com/documentation/swiftui/view/scrolledgeeffecthidden(_:for:)), [`safeAreaBar(edge:alignment:spacing:content:)`](https://developer.apple.com/documentation/swiftui/view/safeareabar(edge:alignment:spacing:content:))

```swift
nonisolated func scrollEdgeEffectStyle(_ style: ScrollEdgeEffectStyle?, for edges: Edge.Set) -> some View
nonisolated func scrollEdgeEffectHidden(_ hidden: Bool = true, for edges: Edge.Set = .all) -> some View

struct ScrollEdgeEffectStyle {
    static var automatic: ScrollEdgeEffectStyle  // system picks per platform and context
    static var hard: ScrollEdgeEffectStyle       // linear, nearly opaque boundary
    static var soft: ScrollEdgeEffectStyle       // subtle blurred boundary
}

nonisolated func safeAreaBar(
    edge: HorizontalEdge,
    alignment: VerticalAlignment = .center,
    spacing: CGFloat? = nil,
    @ContentBuilder content: () -> some View
) -> some View
```

*   Scroll views draw an automatic edge effect where pinned controls overlap scrolling content.
*   `safeAreaBar` works like `safeAreaInset` (it insets the safe area for a custom bar) and also extends the scroll edge effect under that bar. The published signature takes a `HorizontalEdge`; check the page for vertical-edge overloads before use.
*   Note the `@ContentBuilder` attribute: the 27 SDK replaces type-specific builders with `ContentBuilder` (see `SwiftUI27Updates.md`).

* * *

## Glass toolbars

[`ToolbarSpacer`](https://developer.apple.com/documentation/swiftui/toolbarspacer), [`sharedBackgroundVisibility(_:)`](https://developer.apple.com/documentation/swiftui/toolbarcontent/sharedbackgroundvisibility(_:)), [`visibilityPriority(_:)`](https://developer.apple.com/documentation/swiftui/toolbarcontent/visibilitypriority(_:)), [`ToolbarItemVisibilityPriority`](https://developer.apple.com/documentation/swiftui/toolbaritemvisibilitypriority), [`ToolbarOverflowMenu`](https://developer.apple.com/documentation/swiftui/toolbaroverflowmenu), [`toolbarMinimizationBehavior(_:for:)`](https://developer.apple.com/documentation/swiftui/view/toolbarminimizationbehavior(_:for:))

```swift
nonisolated struct ToolbarSpacer              // init(_ sizing:, placement:)  sizing: .fixed or .flexible
nonisolated func sharedBackgroundVisibility(_ visibility: Visibility) -> some ToolbarContent
@MainActor @preconcurrency func visibilityPriority(_ priority: ToolbarItemVisibilityPriority) -> some ToolbarContent
struct ToolbarItemVisibilityPriority          // .automatic, .low, .high, init(lowerThan:), init(higherThan:)
nonisolated struct ToolbarOverflowMenu<Content: View>   // iOS, iPadOS, Mac Catalyst, visionOS 27
nonisolated func toolbarMinimizationBehavior(_ behavior: ToolbarMinimizationBehavior, for bars: ToolbarPlacement...) -> some View
```

*   Items in the macOS window toolbar and the iOS navigation bar share a glass background with the other items in their logical group.
*   `ToolbarSpacer(.fixed)` splits groups; `ToolbarSpacer(.flexible)` pushes items apart. Spacers also work in customizable toolbars (`.toolbar(id:)`), where people can add, remove, and reorder them.
*   `sharedBackgroundVisibility(.hidden)` takes an item out of the shared glass and puts it in its own group, for example a status view in the principal placement.
*   `visibilityPriority(.high)` keeps an item in the toolbar longer when space runs out; `.low` sends it to the overflow menu first. Available on macOS from 26.1.
*   `ToolbarOverflowMenu { ... }` always places its buttons in the overflow menu. Not available for native macOS.
*   `toolbarMinimizationBehavior(.onScrollDown, for: .navigationBar)` minimizes the navigation bar while scrolling (the supported placement is `navigationBar`); `toolbarMinimizationSafeAreaAdjustment(_:for:)` customizes the safe area change.
*   Hide an item with `.hidden(_:)` on the item, not on its content.

```swift
.toolbar {
    ToolbarItem(placement: .navigation) {
        Button("Back", systemImage: "chevron.left") { goBack() }
    }
    ToolbarSpacer(.flexible)
    ToolbarItemGroup {
        Button("Select", systemImage: "cursorarrow") { selectTool(.select) }
        Button("Blocked Area", systemImage: "square.dashed") { selectTool(.blockedArea) }
    }
    ToolbarSpacer(.fixed)
    ToolbarItem {
        Button("Zoom to Fit", systemImage: "arrow.up.left.and.arrow.down.right") { fit() }
    }
    .visibilityPriority(.high)
}
```

* * *

## Tab bars (iOS and iPadOS)

[`tabBarMinimizeBehavior(_:)`](https://developer.apple.com/documentation/swiftui/view/tabbarminimizebehavior(_:))

```swift
nonisolated func tabBarMinimizeBehavior(_ behavior: TabBarMinimizeBehavior) -> some View   // e.g. .onScrollDown
```

Related: `Tab(role: .search)` puts a search tab at the trailing end and turns it into a search field; `Tab(role: .prominent)` (27) places a tab in a separate trailing position; `TabViewBottomAccessoryPlacement` adapts an accessory view to where it sits in the tab view; `sidebarAdaptable` lets a tab bar become a sidebar. Not relevant to this macOS app.

* * *

## Performance

*   One `GlassEffectContainer` per group of glass views; avoid many containers and many stand-alone glass views on screen at once.
*   Profile with Instruments after adding custom glass (Apple points to its "Optimize SwiftUI performance with Instruments" and "Explore UI animation hitches and the render loop" material).

## UIKit and AppKit equivalents

| SwiftUI | UIKit | AppKit |
| --- | --- | --- |
| `glassEffect(_:in:)` | `UIGlassEffect` | `NSGlassEffectView` |
| `.buttonStyle(.glass)` / `.glassProminent` | `glass()` / `prominentGlass()` button configurations (also `clearGlass()`, `prominentClearGlass()`) | `NSButton.BezelStyle.glass` |
| `backgroundExtensionEffect()` | `UIBackgroundExtensionView` | `NSBackgroundExtensionView` |
| `ConcentricRectangle` | `UICornerConfiguration` | none listed |
| `safeAreaBar` | `UIScrollEdgeElementContainerInteraction` | none listed |
| `ToolbarSpacer(.fixed)` | `UIBarButtonItem.fixedSpace(_:)` | `NSToolbarItem.Identifier.space` |
