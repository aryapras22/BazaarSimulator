# Project Setup UI Plan

> Plan for the frontend of project setup: the app shell, the project library sidebar, and the legend and floor plan upload screen. It follows `ArchitectureGuide.md` and `DeveloperAgreement.md`. Color and size values were sampled from the Hi-Fi PNG exports, so they are close but not exact. If a Figma file exists, take the final values from it.

## Table of contents
*   Delivery: two PRs
*   What the screens show
*   Design tokens
*   Components
*   Page layout
*   Screen behavior
*   The seam between UI and backend
*   Files
*   Commit order
*   Tests and previews
*   Design gaps and defaults
*   PR description outline
* * *
## Delivery: two PRs

Project setup ships as two pull requests, split along the layer rules.

| PR | Branch | Contents |
| ---| ---| --- |
| 1. UI | `feature/project-setup-ui` | Design system, app shell, project library sidebar, project setup screen, view models, `ProjectSession`, the import protocol and a scripted fake |
| 2. Backend | `feature/project-setup-reading` | `PDFImportService`, the real `ImportQueue`, reader backends, the mapper from reader output to metres, SwiftData and `ProjectRepository` |

Both branches start from `dev`. The UI PR merges first. The backend PR then rebases on `dev` and conforms the real queue to the protocol from the UI PR, so it changes no view code (layer rule 2: view models use services through protocols).

Out of scope for the UI PR:
*   Reading any PDF. The scripted fake stands in for it.
*   Storage. Projects live in memory until the backend PR adds the repository.
*   The review step. Continue opens a placeholder until the Layout editor exists.
* * *
## What the screens show

| Screen | Content | Owner |
| ---| ---| --- |
| 1 | Sidebar with "Projects" and a + button, no rows. Detail shows a grid icon, "Your Workspace is Ready", and "Select the + button in the sidebar to create your first project." | App shell, ProjectLibrary |
| 2 | "Bazaar 1" created and selected. Setup shows "Project", the subtitle "Imported your venue layout and a legend.", a "Project name" field prefilled with "Bazaar 1", a LEGENDS drop zone, and a dimmed FLOOR PLANS drop zone | ProjectSetup |
| 3 | Legend read. A "SCANNED LEGENDS · 3 Elements" card lists FNB, Fashion, and Lifestyle & Hobbies, each with a colored dot and a Remove button. The floor plan drop zone is active | ProjectSetup |
| 4 | "UPLOADED · 3 Plans" card. Two rows read "✓ 66 booths · 3 doors", one reads "Reading..." with a progress bar. Rows show a thumbnail or file icon, the file name, and "Layout N · 2.4 MB". Footer reads "Waiting for Layout 3 to finish reading..." with Cancel and a disabled Continue | ProjectSetup |
| 5 | The "..." menu on a plan row, with Edit and Delete (Delete in red) | ProjectSetup |

An earlier export also showed the third plan row with red error text. The plan covers a failed state even though there is no full-size frame for it.

Drop zone texts:
*   Legends: "Drop PDFs here", "Choose files...", "PDF · one legend for all the layouts"
*   Floor plans: "Drop PDFs here", "Choose files...", "PDF · one file per layout · up to 6"
* * *
## Design tokens

Everything below lives in `Core/DesignSystem/Tokens/`. Views use token names, never literals (agreement: no hard-coded colors, spacing, or radii).

Only a dark appearance is designed (guide, macOS specifics). Force dark at the window. Tokens need one value each, no light variants.

### Palette

| Token | Hex | Used for |
| ---| ---| --- |
| `background` | `#000C20` | Window and detail column |
| `sidebarBase` | `#0B172B` | Top of the sidebar |
| `glowBlue` | `#0E264F` (as seen) | Blue glow, lower left of the sidebar |
| `glowOrange` | `#3C2A2B` (as seen) | Orange glow, bottom of the sidebar |
| `surface` | `#121F36` | Drop zones, legend card, plans card |
| `surfaceBorder` | `#223046` | 1 pt border on surfaces |
| `surfaceDisabled` | `#071329` | Dimmed drop zone |
| `surfaceDisabledBorder` | `#0E1A2F` | Border of the dimmed drop zone |
| `control` | `#2F3946` | "Choose files...", Cancel |
| `controlDisabled` | `#131E2F` | Disabled "Choose files..." |
| `controlOnSurface` | `#253249` | Remove button fill, progress track |
| `controlOnSurfaceBorder` | `#354359` | Remove button border |
| `field` | `#2D394D` | Project name field |
| `fieldBorder` | `#354155` | Project name field border |
| `selection` | `#384458` | Selected sidebar row |
| `selectionBorder` | `#485468` | Selected sidebar row border |
| `menu` | `#19253A` | "..." popover |
| `textPrimary` | `#DDDDDD` | Titles, row names |
| `textSecondary` | `#929292` | Section labels, row subtitles, "Reading..." |
| `textTertiary` | `#848688` | Drop zone hints |
| `textDisabled` | `#585F6B` | Text in the dimmed drop zone |
| `accent` | `#0066CC` | Progress fill |
| `accentIcon` | `#71ACE6` | Drop zone download icon |
| `accentText` | `#659BD1` | "✓ 66 booths · 3 doors" |
| `accentMuted` | `#306CB0` | File icon on a row that is still reading |
| `destructive` | `#F44245` | Remove and Delete text, error text |
| `primaryDisabled` | `#281B28` | Disabled Continue fill |
| `primaryDisabledText` | `#46444F` | Disabled Continue text |

Notes:
*   The done text is blue. Name it `accentText`, not `success`.
*   Legend dot colors (`#DE2A2A`, `#2ADE31`, `#F4DC30` in the Hi-Fi) are data. They come from the legend as RGB values in Domain, and the view converts them to `Color`. They are not tokens.
*   The glow values are the blended pixels seen in the export. The source colors are brighter at low opacity. Tune them by eye.

### Spacing

Measured from the 1470 x 956 frames and rounded to a 4 pt scale.

| Token | Value | Used for |
| ---| ---| --- |
| `xs` | 4 | Title to subtitle, icon to text in small labels |
| `s` | 8 | Inside buttons, between row title and subtitle |
| `m` | 12 | Row vertical padding (rows are about 45 pt tall) |
| `l` | 16 | Section label to card, card inner horizontal padding |
| `xl` | 24 | Page padding from the sidebar, gap between columns, card to next section label |
| `xxl` | 40 | Title block to the project name row |

The drop zone height (190 pt) is a layout constant in the view, not a token.

### Radius

| Token | Value | Used for |
| ---| ---| --- |
| `s` | 6 | Buttons, field, Remove pill, menu items |
| `m` | 10 | Sidebar rows, search field |
| `l` | 16 | Cards and drop zones |
| `xl` | 24 | Floating sidebar (comes free with the glass sidebar of `NavigationSplitView` on recent macOS) |

### Typography

All SF Pro (system font).

| Token | Approx. | Used for |
| ---| ---| --- |
| `title` | 22 pt bold | "Project" |
| `subtitle` | 12 pt regular | Subtitle under the title |
| `fieldLabel` | 14 pt semibold | "Project name" |
| `sectionLabel` | 11 pt regular, uppercase, slight tracking | "LEGENDS", "UPLOADED · 3 Plans" |
| `body` | 13 pt regular | Row names, button text, sidebar rows |
| `caption` | 11 pt regular | Row subtitles, hints, status text |
| `emptyTitle` | 15 pt semibold | "Your Workspace is Ready" |
* * *
## Components

Placement follows the guide's Reusable components section: shared pieces go in `Core/DesignSystem/`, pieces used by one feature stay in that feature's `ViewComponents/`. Components take values, actions are closures, editable state is a `Binding`.

### Core/DesignSystem

| Piece | Form | Why shared |
| ---| ---| --- |
| `Palette`, `Spacing`, `Radius`, `Typography` | Tokens | Every screen |
| `Card` (`.card()`) | ViewModifier | Surface fill, border, radius. Layout cards and analysis panels reuse it |
| `SectionLabel` (`.sectionLabel()`) | ViewModifier | Uppercase caption used across the Hi-Fi (the guide's `CaptionTextFormat`) |
| `AppBackground` (`.appBackground()`) | ViewModifier | Navy fill plus the two radial glows |
| `PrimaryButtonStyle` | ButtonStyle | Continue, and Apply in Parameters later |
| `SecondaryButtonStyle` | ButtonStyle | "Choose files...", Cancel, and Cancel in Parameters later |
| `ProgressBar` | View, `value: Double?` | Import rows, and the Preparing Layout screen later. `nil` shows an indeterminate bar |

### Features/ProjectSetup/ViewComponents

| Component | Inputs | Notes |
| ---| ---| --- |
| `DropZone` | `hint`, `onChoose`, `onDrop` | Reads `@Environment(\.isEnabled)`, so the parent applies `.disabled(...)`. That keeps it to three required parameters (guide rule 6) and avoids an `isEnabled` Boolean. Shows a drag-over highlight |
| `LegendEntryRow` | `name`, `color`, `onRemove` | Dot, name, Remove pill. Accessibility label "Remove FNB" |
| `PlanFileRow` | `display: PlanRowDisplay`, `onEdit`, `onDelete` | Thumbnail or file icon, title, subtitle, trailing status, "..." `Menu` |
| `PlanRowStatusView` | `status: PlanRowDisplay.Status` | Done text, "Reading..." with `ProgressBar`, waiting, failed in `destructive` |
| `RemovePillButtonStyle` | none | Used only here. Move to DesignSystem on a second use |

`PlanRowDisplay` is a plain struct built by `ImportRowFormatter` (guide rule 8: formatting in a small plain type so it can be unit tested). It holds the title, the subtitle ("Layout 2 · 2.6 MB"), and the status. The row only displays strings.

### Features/ProjectLibrary/ViewComponents

| Component | Inputs | Notes |
| ---| ---| --- |
| `ProjectRow` | `name`, `isSelected` | Folder icon and name. Selected rows use `selection` and `selectionBorder` |
| `SidebarSearchField` | `text: Binding<String>` | Pinned to the bottom of the sidebar |
* * *
## Page layout

```
RootView: NavigationSplitView, .appBackground(), dark
├─ sidebar: ProjectLibraryView
│    "Projects" header with +
│    list of ProjectRow
│    SidebarSearchField at the bottom
└─ detail: AppRouter destination
     ├─ no project selected  → EmptyWorkspaceView
     ├─ project in setup     → ProjectSetupView
     └─ after Continue       → review placeholder

ProjectSetupView
VStack(alignment: .leading)
├─ header: "Project" + subtitle
├─ name row: "Project name" + TextField (about 220 pt wide)
├─ HStack(alignment: .top, spacing: Spacing.xl)
│   ├─ legend column (1/3)  LEGENDS · DropZone · SCANNED LEGENDS card
│   └─ floor column  (2/3)  FLOOR PLANS · DropZone · UPLOADED card
├─ Spacer
└─ footer (trailing): status text · Cancel · Continue
```

*   Split the columns 1:2 with `containerRelativeFrame(.horizontal, count: 3, span:, spacing:)` instead of fixed widths, so the screen scales with the window.
*   The detail column has a flat `background` fill. The window background carries the glows, anchored to the left, so they show only through the translucent sidebar. Check this on a real Mac, because the glass sidebar look varies by OS version.
*   A card appears only when it has content. In screen 3 the UPLOADED card does not exist yet.
*   The middle area scrolls if the rows outgrow the window. The header and footer stay fixed.
*   Keep `ProjectSetupView.body` under 50 lines by moving the header, columns, and footer into private computed views (guide: Breaking up a large SwiftUI view).
* * *
## Screen behavior

### Project library
1.  + creates a project named "Bazaar N", where N is the next free number, selects it, and opens setup.
2.  Editing the project name on the setup screen updates the sidebar row. The name lives in `ProjectSession`, and both features read it from there (guide: Cross-feature state).
3.  Search filters the sidebar by name, case-insensitive.

### Project setup
1.  Only PDFs are accepted, by drop or by "Choose files...". Other files show a message in the footer.
2.  The floor plan zone is disabled until a legend has been read.
3.  Legend files do not get their own rows. The legend card lists the entries read from them. Remove deletes one entry from a draft legend held by the view model.
4.  At most 6 floor plans. The 7th is refused, and the floor plan zone is disabled at 6.
5.  Plan rows show "Layout N" by position, the file size, and the thumbnail once one exists. Until the backend provides thumbnails, rows show the file icon.
6.  The "..." menu offers Edit and Delete. Delete removes the file and its result.
7.  Footer status text:
    *   while reading: "Waiting for Layout N to finish reading...", naming the first plan still reading
    *   all done, name empty: "Name the project to continue"
    *   all done: "Ready to continue"
    *   otherwise: "Add a legend and floor plans to continue"
8.  Cancel is active while files are being read. It marks waiting and reading files as cancelled.
9.  Continue is active when every file is done, at least one plan exists, and the name is not empty. It writes the name, the legend, and the draft layouts to `ProjectSession` and moves the router to the review placeholder.
10. Rule 8 allows one reader model app-wide, so the import queue lives in `AppServices` and is shared, not owned by one setup view model.
* * *
## The seam between UI and backend

The setup view model talks to the import pipeline through one protocol in `Core/Services/FloorPlanReading/`, named `ImportQueueing` or similar.

| The view model needs | Shape |
| ---| --- |
| Add files of a kind | `add(urls, kind)` |
| Remove a file | `remove(id)` |
| Cancel the run | `cancel()` |
| Files and their states | observable list of `ImportFile` |
| Results | the legend, and the extracted layout per file |
| Row details | file size and an optional thumbnail per file |

Domain types added in the UI PR (`Core/Domain/`, plain `Sendable` structs):
*   `ImportFileKind`: legend or floor plan
*   `ImportFileState`: waiting, reading (with optional progress), done (with result counts), failed (with message), cancelled
*   `ImportFile`: id, URL, kind, state, file size, optional thumbnail data
*   `Legend` and `LegendEntry`: name and RGB color
*   `ExtractedLayout`: name, size in metres, booths, doors
*   `ProjectDraft`: name, legend, layouts

The UI PR ships `ScriptedImportQueue`, a fake that conforms to the protocol. It moves each file through waiting, reading with rising progress, and done after a short delay, returning counts from the bundled mock layouts. It can be told to fail a named file, so the failed row can be checked by hand. It lives with the test support code and previews, not in `Core/`. `AppServices` uses it until the backend PR swaps in the real queue.
* * *
## Files

```
App/
  BazaarSimulatorApp.swift          forces dark, builds AppServices
  AppServices.swift                 holds the shared import queue
  Navigation/
    AppRouter.swift                 empty / setup / review placeholder
    RootView.swift                  NavigationSplitView and background
    EmptyWorkspaceView.swift
Core/
  Domain/                           types listed in the seam section
  DesignSystem/
    Tokens/       Palette, Spacing, Radius, Typography
    Modifiers/    Card, SectionLabel, AppBackground
    Styles/       PrimaryButtonStyle, SecondaryButtonStyle
    Components/   ProgressBar
  Session/
    ProjectSession.swift
  Services/FloorPlanReading/
    ImportQueueing.swift
Features/
  ProjectLibrary/
    View/ProjectLibraryView.swift
    ViewModel/ProjectLibraryViewModel.swift
    ViewComponents/ProjectRow.swift, SidebarSearchField.swift
  ProjectSetup/
    View/ProjectSetupView.swift
    ViewModel/ProjectSetupViewModel.swift, ImportRowFormatter.swift
    ViewComponents/DropZone.swift, LegendEntryRow.swift, PlanFileRow.swift,
                   PlanRowStatusView.swift, RemovePillButtonStyle.swift
Tests/
  Support/ScriptedImportQueue.swift
  Core/AppRouterTests.swift
  Features/ProjectSetupViewModelTests.swift, ImportRowFormatterTests.swift,
           ProjectLibraryViewModelTests.swift
```

`ContentView.swift` and the mock layout list go away. `MockDataStore` and the mock JSON files stay, because the scripted fake reads them.
* * *
## Commit order

One logical change per commit, in the Conventional Commits format from the agreement. Each commit builds on its own.

1.  `chore: add test target to the Xcode project`
2.  `feat: add design tokens and surface modifiers`
3.  `feat: add button styles and progress bar`
4.  `feat: add app shell with sidebar and empty workspace`
5.  `feat: add project library sidebar with in-memory projects`
6.  `feat: add project session and import queue protocol`
7.  `feat: add project setup header and drop zones`
8.  `feat: add scanned legend card with editable entries`
9.  `feat: add uploaded plans card with row states and menu`
10. `feat: add setup footer with status, cancel and continue`
11. `test: cover setup view model, row formatter and library`
12. `refactor: remove mock layout list from the default view`

Tests for a behavior can land in the same commit as the behavior instead of in commit 11 (agreement: a commit that changes behavior includes its tests).
* * *
## Tests and previews

There is no test target in the Xcode project today, so commit 1 adds one. Without it, the "fast test plan passes" checklist item cannot be met.

`ProjectSetupViewModelTests`, using `ScriptedImportQueue`:
*   Floor plans are refused until a legend is read
*   The 7th floor plan is refused, and the floor plan zone disables at 6
*   Non-PDF files are refused with a message
*   Removing a legend entry removes it from the draft and updates the count
*   The status text names the first plan still reading
*   Continue needs a name, at least one plan, and every file done
*   Cancel marks waiting and reading files as cancelled
*   Continue writes the draft to `ProjectSession`

`ImportRowFormatterTests`:
*   "Layout 2 · 2.6 MB" with a fixed locale
*   "66 booths · 3 doors", and singular forms ("1 booth · 1 door")

`ProjectLibraryViewModelTests`:
*   New projects are numbered "Bazaar 1", "Bazaar 2", and so on
*   Search filters by name, case-insensitive
*   Renaming through the session updates the row

`AppRouterTests`:
*   No project selected shows the empty workspace
*   A new project shows setup
*   Continue shows the review placeholder

Previews:
*   Every DesignSystem piece has the five previews from the agreement: normal, long text, empty value, dark mode, disabled.
*   `PlanFileRow` has one preview per state: waiting, reading with progress, reading without progress, done, failed, cancelled.
*   `ProjectSetupView` has previews for screens 2 to 4, built from `ScriptedImportQueue` in a fixed state.
* * *
## Design gaps and defaults

The Hi-Fi leaves these open. Settle them with the designer before starting, or use the default and say so in the PR.

| Gap | Default |
| ---| --- |
| Enabled Continue | Solid `accent` with white text. The disabled state is maroon, but red reads as destructive and the progress bar already uses blue |
| Legend still being read | One row in the legend card with the file name, "Reading...", and a `ProgressBar` |
| Edit in the plan menu | Disabled until the review editor exists |
| Failed plan row | `destructive` text "Couldn't read this plan", with Retry and Delete in the menu |
| Drag over a drop zone | Border and icon switch to `accent` |
| One legend PDF or several | Several, merged into one legend. The label says LEGENDS, and the guide says legend PDFs |
| Every legend entry removed | Plans already read stay. Continue stays disabled until the legend has at least one entry |
* * *
## PR description outline

Use the three sections from the agreement.

**What and how**
*   Design system: tokens, `Card`, `SectionLabel`, `AppBackground`, two button styles, `ProgressBar`.
*   App shell: `RootView`, `AppRouter`, `EmptyWorkspaceView`.
*   Project library: sidebar, project creation, search, in-memory projects.
*   Project setup: drop zones, legend card, plans card, footer, `ProjectSetupViewModel`, `ImportRowFormatter`.
*   `ProjectSession` and the `ImportQueueing` protocol, with `ScriptedImportQueue` standing in for the backend. No PDF is read yet.
*   Any design gap where a default was used.

**Testing**
*   Walk through screens 1 to 5 by hand: create a project, drop a legend, remove an entry, drop three plans, open the row menu, delete a plan, cancel mid-read, continue.
*   Make the fake fail a file and check the failed row.
*   List the test suites above.

**Checklist**
- [ ] Builds with no SwiftLint errors
- [ ] Fast test plan passes
- [ ] New logic has tests, and a bug fix has a regression test
- [ ] No layer rule is broken
- [ ] New shared components have previews and use design tokens
- [ ] The ClickUp task is linked
