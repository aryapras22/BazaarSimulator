# Liquid Glass: design rules

> Condensed from Apple's [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass), [Liquid Glass overview](https://developer.apple.com/documentation/technologyoverviews/liquid-glass), and [HIG: Materials](https://developer.apple.com/design/human-interface-guidelines/materials) (HIG change log: guidance added 9 June 2025, updated 9 September 2025). Fetched 3 November 2026.

## What it is

Liquid Glass is a dynamic material introduced with the 26 SDKs. It blurs what is behind it, picks up color and light from surrounding content, and reacts to touch and pointer input. It forms a separate functional layer for controls and navigation (bars, sidebars, tab bars, sheets, popovers, menus) that floats above the content layer.

Apple platforms now have two kinds of material:

| Material | Layer | Use |
| --- | --- | --- |
| Liquid Glass | Functional layer above content | Controls and navigation |
| Standard materials (`Material`: ultra-thin, thin, regular, thick; blur, vibrancy, blending modes) | Content layer | Visual structure inside content, such as app backgrounds and grouped sections |

## Where it goes

*   System components adopt it automatically. Building with the latest SDK gives standard bars, sheets, popovers, controls, menus, and split views the new look without code.
*   Keep it out of the content layer. Using glass for content muddles the hierarchy. The exception: transient controls inside content, like a slider knob or toggle, turn into glass while a person interacts with them, and the system does that for you.
*   Use custom glass sparingly. Apply it only to the most important functional elements; several glass controls competing on one screen pull attention away from the content.
*   Remove custom backgrounds from navigation elements. Custom backgrounds on `NavigationStack`, `NavigationSplitView`, the title bar, and toolbars (AppKit: `NSToolbar`, `NSSplitView`) can cover the system glass or fight the scroll edge effect. Prefer letting the system draw them.
*   Do not stack glass on glass. Avoid layering or crowding glass elements; keep standard spacing.

## Regular vs clear

| Variant | Behavior | Use for |
| --- | --- | --- |
| `regular` (default) | Blurs and adjusts the luminosity of what is behind it to keep text legible | Most components, anything with a lot of text (alerts, sidebars, popovers), anything over busy content |
| `clear` | Highly translucent | Only components that float over visually rich media (photos, video) |

With `clear` over bright content, add a dark dimming layer of about 35% opacity behind the component. Over dark content, or with AVKit playback controls that bring their own dimming, no dimming layer is needed.

## Color

*   Be careful with color in controls and navigation so they stay legible and let content show through.
*   Use system colors, or define custom colors with light and dark variants and an increased-contrast option for each.
*   Use a tint on glass to suggest prominence (`Glass.tint(_:)`, `.glassProminent`), not as decoration.
*   On top of standard materials, use vibrant system colors for labels and fills so contrast holds in every context.
*   Pick materials by meaning, not by the color they appear to give; system settings can change their appearance.

## Shape and layout

*   Hardware curvature drives the shape of nested elements. Windows have rounder corners; controls are rounder and can be extra large.
*   Keep nested corners concentric with their container (`ConcentricRectangle`, `.rect(corners:isUniform:)`, `containerShape(_:)`).
*   Do not hard-code control metrics; standard controls change size and shape with the SDK.
*   Lists, tables, and forms have taller rows, more padding, and rounder sections. Section headers use title-style capitalization instead of all caps. Use `Form` with the grouped style to get the new metrics.

## Navigation

*   Keep a clear navigation hierarchy that is visibly separate from content.
*   Sidebars and inspectors: build them with `NavigationSplitView` and `inspector(isPresented:content:)` to get fluid resizing and consistent behavior.
*   Check safe areas next to sidebars and inspectors so content can show through underneath where intended.
*   Use `backgroundExtensionEffect()` to make a hero image appear to continue under a sidebar or inspector without placing content there.
*   iOS: tab bars can minimize on scroll (`tabBarMinimizeBehavior(_:)`); a tab bar can adapt into a sidebar (`sidebarAdaptable`); the search tab uses `Tab(role: .search)`.

## Toolbars and menus

*   Toolbars are glass and group items. Group items that act on the same thing; keep groupings consistent across platforms.
*   Separate groups with a fixed spacer (`ToolbarSpacer(.fixed)`).
*   Prefer standard icons to text for common actions, and do not mix icons and text inside one group.
*   Give every icon-only item an accessibility label.
*   Hide a whole toolbar item with `.hidden(_:)`; hiding only its content leaves an empty glass item.
*   Menu items for standard actions (Cut, Copy, Paste) get icons automatically when they use the standard actions.

## Windows, sheets, popovers

*   Support arbitrary window sizes; split views reflow fluidly.
*   Use safe areas and layout guides so window controls and the title bar can adjust around content.
*   Sheets have larger corner radii; check content near their corners. Remove custom visual-effect backgrounds from popovers and sheets.
*   Anchor action sheets and confirmation dialogs to the control that opens them (`confirmationDialog(_:isPresented:titleVisibility:presenting:actions:)`).

## Scrolling under controls

Scroll views apply a scroll edge effect that blurs and fades content passing under pinned controls. System bars get it automatically. A custom bar with controls over scrolling content should be registered with `safeAreaBar(edge:alignment:spacing:content:)` so the effect extends to it. Tune or hide the effect with `scrollEdgeEffectStyle(_:for:)` and `scrollEdgeEffectHidden(_:for:)`.

## Accessibility and testing

*   People can pick a preferred Liquid Glass look in Settings, and can turn on Reduce Transparency, Increase Contrast, or Reduce Motion. These change or remove glass effects and morphing.
*   Standard components adapt automatically; test every custom glass element, color, and animation under each setting.
*   Profile performance after adopting glass. Many glass effects, or many separate containers, cost rendering time; combine custom glass in one `GlassEffectContainer`.

## Opting out temporarily

An app can keep its pre-26 look while building with the latest SDK by adding the `UIDesignRequiresCompatibility` key to its Info settings. Apple presents this as a transition aid, not a long-term choice.

## Adoption checklist

- [ ] Build with the latest Xcode and look at every screen before changing code.
- [ ] Remove custom backgrounds from sidebars, toolbars, and split views unless a design decision requires them.
- [ ] No glass in the content layer.
- [ ] Custom glass only on a few key floating controls, grouped in one `GlassEffectContainer`.
- [ ] `regular` by default; `clear` only over rich media, with dimming where needed.
- [ ] Toolbar items grouped, spaced with `ToolbarSpacer`, icon-only items labelled.
- [ ] Nested corners concentric with their containers.
- [ ] Section headers in title case.
- [ ] Tested with Reduce Transparency, Increase Contrast, Reduce Motion, light and dark.
- [ ] Profiled after adding custom glass.
