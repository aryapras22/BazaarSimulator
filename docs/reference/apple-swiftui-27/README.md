# Apple SwiftUI 27 and Liquid Glass reference

> Reference for AI agents and developers working on Bazaar Simulator. It condenses Apple's official documentation on Liquid Glass and the SwiftUI changes in the 27 SDKs (iOS 27, iPadOS 27, macOS 27). It summarizes and links the sources; it does not copy them. When this folder and Apple's site disagree, Apple's site wins; when Apple's guidance and this project's Hi-Fi or `ArchitectureGuide.md` disagree, the project documents win and the conflict is noted in the PR.

Fetched: 3 November 2026, from developer.apple.com (documentation data for the SwiftUI, Technology Overviews, and Human Interface Guidelines pages listed in each file).

## Files

| File | Use it for |
| --- | --- |
| [LiquidGlassDesign.md](LiquidGlassDesign.md) | What Liquid Glass is, where it belongs, regular vs clear, color, accessibility, and the adoption checklist |
| [LiquidGlassSwiftUIAPI.md](LiquidGlassSwiftUIAPI.md) | Every SwiftUI API for glass, button styles, concentric shapes, background extension, scroll edge effects, and glass toolbars, with signatures, availability, and short examples |
| [SwiftUI27Updates.md](SwiftUI27Updates.md) | What changed in SwiftUI in June 2026 (27 SDKs) and September 2026, plus the June 2025 (26 SDKs) Liquid Glass baseline |

## How to use this reference

1.  Check availability before writing code. Liquid Glass APIs arrived in the 26 SDKs; some toolbar APIs are 27 only, and some are iOS only. Each API in `LiquidGlassSwiftUIAPI.md` lists its platforms and versions. This app's deployment target is macOS 27.0, so anything marked macOS 26 or 27 is available; anything without macOS is not.
2.  Prefer system components first. Standard SwiftUI navigation, toolbars, sheets, and controls adopt Liquid Glass on their own. Custom glass is for a few important floating controls, not for content.
3.  Follow the project's rules too. `AGENTS.md`, `docs/ArchitectureGuide.md`, and `docs/DeveloperAgreement.md` still apply: views talk to their own view model, colors and spacing come from `Core/DesignSystem` tokens, and shared components need previews.
4.  If the API you need is not here, read the official page (links in each section) rather than guessing a signature.

## What this means for Bazaar Simulator

The app is a macOS 27 SwiftUI app with a dark navy Hi-Fi, a `NavigationSplitView` with a project sidebar, a full-window layout editor with a floating inspector, and a canvas. Apple's guidance applies to it like this:

| Area | Guidance | Status in the code |
| --- | --- | --- |
| Sidebar and toolbar | Let `NavigationSplitView` and `.toolbar` draw their own Liquid Glass backgrounds; Apple asks apps to remove custom backgrounds from these elements | `ProjectLibraryView` paints `sidebarBackground()` (navy plus glows). That overrides the system sidebar material. Check on a Mac whether the Hi-Fi look can come from the window background behind a translucent sidebar instead |
| Toolbar groups | Group related toolbar items; separate groups with `ToolbarSpacer(.fixed)`; hide whole items with `.hidden(_:)`, not the view inside | The editor toolbar mixes a back button, a layout picker, segmented tabs, and tool buttons. Group them deliberately |
| Content layer (canvas, cards, drop zones, lists) | Do not use Liquid Glass in the content layer; use standard materials or opaque fills | The canvas, cards, and drop zones use opaque tokens. Keep it that way |
| Floating controls over the canvas (zoom buttons, segmented tabs, readout chip) | Allowed sparingly; wrap several glass controls in one `GlassEffectContainer` | Currently opaque `surface` chips. Glass is an option to try against the Hi-Fi, not a requirement |
| Inspector | Apple suggests `inspector(isPresented:content:)` for inspector panels in split views | The editor uses a custom floating `InspectorPanel`. Switching is a design decision; record it if made |
| Buttons | `.buttonStyle(.glass)` and `.glassProminent` instead of hand-made glass buttons | Custom `PrimaryButtonStyle` and `SecondaryButtonStyle` match the Hi-Fi. Do not replace them without a design decision |
| Corner shapes | `ConcentricRectangle` and `.rect(corners:isUniform:)` keep nested corners concentric with windows and sheets | Corners use fixed `Radius` tokens. Fine for now |
| Accessibility | Test with Reduce Transparency, Increase Contrast, and Reduce Motion; glass changes under these settings | Add these to manual checks when any glass is introduced |

## Sources

All pages on developer.apple.com:

*   [Liquid Glass (technology overview)](https://developer.apple.com/documentation/technologyoverviews/liquid-glass)
*   [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass)
*   [Applying Liquid Glass to custom views](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views)
*   [Landmarks: Building an app with Liquid Glass](https://developer.apple.com/documentation/swiftui/landmarks-building-an-app-with-liquid-glass)
*   [Landmarks: Refining the system provided Liquid Glass effect in toolbars](https://developer.apple.com/documentation/swiftui/landmarks-refining-the-system-provided-glass-effect-in-toolbars)
*   [Landmarks: Displaying custom activity badges](https://developer.apple.com/documentation/swiftui/landmarks-displaying-custom-activity-badges)
*   [Human Interface Guidelines: Materials](https://developer.apple.com/design/human-interface-guidelines/materials)
*   [SwiftUI updates](https://developer.apple.com/documentation/updates/swiftui)
*   API pages linked from each entry in `LiquidGlassSwiftUIAPI.md`
