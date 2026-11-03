# AGENTS.md

Bazaar Simulator is a macOS SwiftUI app for planning bazaar layouts: import floor plans, review layouts, set visitor parameters, compare layouts, and run a 3D simulation.

## Source of truth

Read these before changing code. They override anything inferred from the existing code.

- `docs/ArchitectureGuide.md` covers the feature-sliced MVVM structure, layer rules, directory structure, core building blocks, size limits, testing, and reusable components.
- `docs/DeveloperAgreement.md` covers branching, pull requests, naming, commit messages, definition of done, and which rules block a merge.

If a change alters a rule or structure described in either document, update the document in the same change.

For Apple UI APIs (Liquid Glass, glass button styles, toolbars, concentric shapes, and the SwiftUI 27 changes), read `docs/reference/apple-swiftui-27/README.md` before writing UI code. Check each API's platform and version there; the app targets macOS 27.

## Rules to keep in mind

- Views talk only to their own ViewModel. ViewModels use services, repositories, the engine, and `ProjectSession` through protocols, injected through `init`.
- Feature A never imports Feature B. Shared logic goes in `Core/`.
- The simulation engine imports Foundation and `simd` only.
- `Core/DesignSystem` imports SwiftUI only and holds all colors, spacing, and radii as tokens.
- Domain types are plain `Sendable` structs. SwiftData `@Model` classes stay behind repositories.
- Size limits are in `.swiftlint.yml`. A warning means look for a second concern, an error blocks the merge.
- Names, branch prefixes, and Conventional Commits format follow `docs/DeveloperAgreement.md`.
