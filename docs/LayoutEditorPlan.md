# Layout Editor Plan

> Plan for the Layout editor: the Floor Plan tab (booths, tables, and other items with an inspector) and the Flow tab (door direction and width with a tip callout). It follows `ArchitectureGuide.md` and `DeveloperAgreement.md`, builds on the project setup work, and treats the bundled mock layouts (`Core/Resources/MockData/*.json`) as the source of truth for the data structure. Colors were sampled from the Hi-Fi exports, so take final values from Figma if it exists.

## Table of contents
*   Delivery
*   What the screens show
*   What the mock data says
*   Domain model
*   From mock JSON to `Layout`
*   Inferred defaults: categories, open sides, door directions, labels
*   Editor behavior: Floor Plan tab
*   Editor behavior: Flow tab
*   Inspector by object kind
*   Canvas: rendering, viewport, hit testing
*   Editing pipeline, undo, and Save Changes
*   Validation
*   Navigation and window
*   Design tokens
*   Components
*   Files
*   Commit order
*   Tests and previews
*   Design gaps and defaults
*   Out of scope
*   PR description outline
* * *
## Delivery

| Item | Value |
| ---| --- |
| Branch | `feature/layout-editor` |
| Base | `feature/project-setup-ui` (the editor needs the session, the router, the factory, and the design system from it) |
| PR target | `dev`, after `feature/project-setup-ui` merges. Rebase onto `dev` at that point (agreement: rebase, do not merge `dev` in) |
| PR count | One. All of it is UI plus pure domain logic (geometry, inference, validation, edit history). No reader, no storage |

Before starting, fix the open issues from the last review of `feature/project-setup-ui` on that branch, then rebase this branch. They are: Continue allowed with every legend entry removed, the fake keeping one legend per project, two `.fileImporter` modifiers on one view, the legend card hiding entries while a legend is pending, and the shortened session sketch in `ArchitectureGuide.md`. The editor reads the legend from the draft, so the first two matter here.

The guide's suggested build order puts the editor (step 3) before project setup (step 7). This branch comes after setup, so the editor must still work on a layout that was never read from a PDF (guide checklist: "Reader independence"). The plan keeps that: the editor only needs a `Layout` value.
* * *
## What the screens show

Four Hi-Fi frames, all with the sidebar hidden and the editor filling the window.

| Frame | Content |
| ---| --- |
| Floor Plan, booth selected | Segmented control "Floor Plan" (selected) and "Flow" at the top center. Canvas on a dark grid shows the layout as a blueprint: white floor, dark blue lines, booths drawn white with salmon strips on their open sides, round tables with four chairs, a round feature in the middle. The selected booth is filled orange. Inspector panel on the right: title "Booth B-7", Category popup "Food & Beverage", Size "(width x length)" with two fields "2" x "2" m, Rotation "90°" with a circular control, Open Sides diagram (a square with a chip "A", right and bottom edges orange and labelled "Open", the other edges dashed), hint "Orange = open · click an edge to toggle", full-width "Save Changes" (disabled) at the bottom |
| Floor Plan, category open | Category popup open with "Food & Beverage" (checked), "Fashion & Beauty", "Lifestyle & Hobbies" |
| Flow, door selected | "Flow" selected. Booths, tables, and the feature are drawn in pale blue with no open-side strips. Doors are highlighted: the selected "Door NW" (top left) in red, the main door at the bottom center filled peach with a red outline. Inspector: title "Door NW", Direction popup "Entrance", Width field "2" m, a blue tip callout "Tip: Door NE is already "Out". Most bazaars use one main entry, make NW "In"?" with a button "Use "In"", "Save Changes" (disabled) |
| Flow, direction open | Direction popup open with "Entrance" (checked), "Exit", "Disable" |

What the frames imply beyond what they show:
*   Selection is per tab. Floor Plan selects booths and other items, Flow selects doors only (booths are drawn pale and inert there).
*   Inspector edits are staged and applied by Save Changes (guide, macOS specifics: "Its edits are held until Save Changes"). Save is disabled until something changed.
*   Open sides are drawn on the canvas, so they are part of the layout data, not just inspector state.
*   The category list is the project's legend. The names in the editor frames ("Food & Beverage", "Fashion & Beauty") differ from the setup frames ("FNB", "Fashion"); the picker shows whatever the legend holds.
*   The editor shows one layout at a time, and there is no visible way to switch layouts or leave the editor (see Design gaps).
* * *
## What the mock data says

Two files, `annyeong-market-layout.json` (70.1 x 84.2 m) and `beyond-market-layout.json` (68.8 x 83.9 m). Units are metres. The origin is the top left, x grows right, y grows down (the lobby sits below the hall at y 65 to 83). Everything is axis-aligned; there is no rotation anywhere.

| Key | Shape | Meaning (inferred) | Annyeong | Beyond |
| ---| ---| ---| ---| --- |
| `meta` | `name`, `sheet`, `world {w, h}`, `note` | Event name, venue sheet, drawing size in metres, how the scale was set | | |
| `hall` | polygon `[[x, y]]` | Walkable boundary of the main hall | 4 points | 4 points |
| `lobby` | polygon | Walkable lobby below the hall, with a chamfered corner | 5 points | 5 points |
| `wall` | rect `x0 x1 y0 y1` | The wall between hall and lobby that holds the doors | 1 | 1 |
| `doors` | `id`, `role`, rect | Doors in that wall. `role` is `entrance` or `both`. Width along the wall is `x1 - x0` (3.52 m and 1.85 m) | 2 | 2 |
| `outerDoors` | `x`, `y0`, `y1` | Doors in the lobby's outer (east) wall, a vertical segment | 2 | 2 |
| `gates` | `id`, `sx`, `sy` | Visitor spawn point "Entrance" in the lobby, next to the first outer door | 1 | 1 |
| `exitPt` | `id`, `sx`, `sy` | Visitor exit point "Exit", next to the second outer door | 1 | 1 |
| `booths` | `id`, `type`, `cx cy w h` | Booths by center and size. `type` is `fnb` or `goods`. IDs are a letter prefix plus a number (`A1`, `F12`, `XX2`); the prefix follows the type (F, G, H are always `fnb`) | 209 | 154 (14 of them in the lobby) |
| `tables` | `cx cy w h` | Seating tables, no ID | 26 at 1.0 m | 136 at 0.8 m |
| `stage` | rect + `face` | Stage; `face` names the front edge (`x0` = left edge, `y1` = bottom edge) | 1 | 1 |
| `kids` + `kidsLabel` + `kidsSeats` | rect, string, bool | Area in front of the stage, labelled "AUDIENCE" in Annyeong, with or without seats | 1 | 1 |
| `columns` | `x y d` | Round pillars, diameter `d` | 0 | 23 at 0.6 m |
| `pilasters` | `kind` + rect | Thin obstacles: `rail`, `wall`, `block` | 5 | 8 |
| `fixtures` | `label`, `kind` + rect, optional `shape`, `rot` | Labelled items: "CLAW MACHINES", "DOORPRIZE", "DECOR"; `kind` `fixture` or `stage` ("EXT", a stage extension); `shape: "round"` fills the rect with an oval and `rot` turns it in degrees | 1 | 6 |
| `closed` | rects, optional `shape`, `rot` | Non-walkable areas inside the hall (back of house, closed strips, atrium voids); `shape` and `rot` as for fixtures | 4 | 6 |
| `foyer`, `corridor` | `x0 x1` + `label [x, y]` | Named lobby zones with a label position (Annyeong only) | 1 each | absent |
| `lobbyBlock` | rect of zeros | Unused (all zero) | | |
| `pantia`, `arrows` | empty arrays | Unused | | |

Checks run on the data: no duplicate booth IDs, no two booths overlap, the most common booth sizes are 2.5 x 2.5 m (`goods`) and 2.0 x 2.0 m (`fnb`) in Annyeong, 2 x 2 and 3 x 3 m in Beyond.

Consequences for the editor:
*   Rotation is new data. The mock has none, so every imported object starts at 0°. A booth with `w > h` is a wide booth, not a rotated one.
*   Open sides are new data. The mock has none, so they are inferred on import (see Inferred defaults).
*   The mock's two booth types do not match a three-entry legend, so categories need a mapping rule.
*   Door direction exists (`role`), but the mock's `both` is missing from the Hi-Fi menu.
*   Doors come in two kinds: hall doors (in `wall`) and outer lobby doors. The Flow tab edits both. `gates` and `exitPt` are spawn and exit points tied to the outer doors.
* * *
## Domain model

All in `Core/Domain/`, plain `Sendable` structs, Foundation and `simd` only (guide: Domain models, layer rule 3 for anything the engine will read). Positions and sizes in metres.

The guide's sketch is the starting point:

```swift
struct LayoutObject: Codable, Identifiable, Sendable {
    var id = UUID()
    var kind: LayoutObjectKind
    var label: String
    var placement: Placement
    var categoryID: LegendEntry.ID?
    var openSides: OpenSides = []
    var doorFlow: DoorFlow?
}

struct Placement: Codable, Sendable {
    var center: SIMD2<Double>
    var sizeM: SIMD2<Double>          // x = width, y = length (depth) in the object's own frame
    var rotationRadians: Double = 0
}
```

Additions:

| Type | Fields | Notes |
| ---| ---| --- |
| `Layout` | `id`, `name`, `sizeM: SIMD2<Double>`, `hall: [SIMD2<Double>]`, `lobby: [SIMD2<Double>]`, `objects: [LayoutObject]`, `markers: [LayoutMarker]`, `zones: [LayoutZone]`, `source: LayoutSource` | One per floor plan. `hall` and `lobby` are polygons, so they are not `LayoutObject`s |
| `LayoutObjectKind` | `booth`, `table`, `door`, `wall`, `rail`, `block`, `pillar`, `fixture`, `stage`, `audienceArea`, `closedArea` | Every fact about a kind lives here as computed properties (guide check 4), see below |
| `OpenSides` | `OptionSet`: `top`, `right`, `bottom`, `left` | In the object's own frame, before rotation. Rotating a booth keeps the same sides open relative to the booth |
| `DoorFlow` | `direction: DoorDirection`, `connection: DoorConnection` | `connection` is `hallToLobby` or `lobbyToOutside`. The guide mentions an angle; the Hi-Fi shows width instead (see Design gaps) |
| `DoorDirection` | `entrance`, `exit`, `both`, `disabled` | `both` comes from the mock (`role: "both"`) |
| `LayoutMarker` | `kind: .spawn / .exit`, `label`, `position` | From `gates` and `exitPt` |
| `LayoutZone` | `label`, `x0`, `x1`, `labelPosition` | From `foyer` and `corridor`. Display only |
| `StageFace` | `top`, `right`, `bottom`, `left` | On a stage object, stored as `openSides` with exactly one side set (the front). Reuses the type instead of adding one |
| `LayoutSource` | `name`, `sheet`, `note` | From `meta`, shown nowhere yet but kept for review |
| `ReviewState` | `detected`, `confirmed` | On `LayoutObject`, prepared for review mode, see Out of scope |

`LayoutObjectKind` computed properties:

| Property | booth | table | door | wall, rail, block | pillar | fixture | stage | audienceArea | closedArea |
| ---| ---| ---| ---| ---| ---| ---| ---| ---| --- |
| `displayName` | Booth | Table | Door | Wall, Rail, Block | Pillar | label or "Fixture" | Stage | Audience area | Closed area |
| `tab` | floorPlan | floorPlan | flow | floorPlan | floorPlan | floorPlan | floorPlan | floorPlan | floorPlan |
| `isMovable` | yes | yes | no (stays on its wall) | yes | yes | yes | yes | yes | no |
| `isResizable` | yes | yes | width only | yes | diameter | yes | yes | yes | no |
| `isRotatable` | yes | yes | no | yes | no | yes | yes | yes | no |
| `hasCategory` | yes | no | no | no | no | no | no | no | no |
| `hasOpenSides` | yes | no | no | no | no | no | front only | no | no |
| `blocksWalking` | yes | yes | no | yes | yes | yes | yes | no | yes |
| `canBeAdded` | yes | yes | no | rail only | no | yes | no | no | no |

The engine, the 3D scene, and the mapper later ask these properties instead of repeating a `switch`.

`Project`-level change: `ProjectDraft.layouts` becomes `[Layout]` instead of `[ExtractedLayout]`. `ExtractedLayout` stays the reader's output and gains `layout: Layout`; its booth and door counts become computed from it. `ProjectSession` gains:

```swift
func layout(id: Layout.ID, in projectID: UUID) -> Layout?
func updateLayout(_ layout: Layout, in projectID: UUID)
func activeLayoutID(for projectID: UUID) -> Layout.ID?
func setActiveLayoutID(_ id: Layout.ID, for projectID: UUID)
```
* * *
## From mock JSON to `Layout`

`BazaarLayout` today decodes only `meta`, `booths`, `doors`, and `tables`. It is a file format, not a domain type, so it moves.

*   Move `Core/Domain/BazaarLayout.swift` to `Core/Services/LayoutImport/BazaarLayoutDTO.swift` and rename the type `BazaarLayoutDTO`.
*   Decode every key in the table above. Optional for keys missing in one file (`foyer`, `corridor`, `kidsLabel`, `kidsSeats`). Do not decode `pantia`, `arrows`, and `lobbyBlock` (empty or all zero in both bundled files), and note them in a comment.
*   Add `MockLayoutMapper` in `Core/Services/LayoutImport/`: `static func layout(from dto: BazaarLayoutDTO, legend: Legend) -> Layout`. Pure, no I/O. `MockDataStore` stays the loader.

Mapping rules:

| JSON | `LayoutObject` |
| ---| --- |
| booth `cx cy w h` | `.booth`, label `id`, center `(cx, cy)`, size `(w, h)`, rotation 0, category from the rule below, open sides inferred |
| table `cx cy w h` | `.table`, label `"T\(index + 1)"`, rotation 0 |
| door rect | `.door`, label `id`, center at the rect center, size `(x1 - x0, y1 - y0)` (width along the wall, thickness across it), `doorFlow (direction from role, .hallToLobby)` |
| outer door `x y0 y1` | `.door`, label `"Outer Door 1"`, `"Outer Door 2"`, center `(x, (y0 + y1) / 2)`, size `(y1 - y0, 0.3)` with rotation 90° so width stays the along-wall measure, `doorFlow (direction inferred, .lobbyToOutside)` |
| wall rect | `.wall`, label "Lobby wall" |
| pilaster `rail` / `wall` / `block` | `.rail` / `.wall` / `.block` |
| column `x y d` | `.pillar`, size `(d, d)` |
| fixture `kind: fixture` | `.fixture`, label from `label` |
| fixture `kind: stage` | `.stage`, label from `label` ("EXT") |
| stage rect + `face` | `.stage`, label "Stage", `openSides` = the face (`x0` to `.left`, `x1` to `.right`, `y0` to `.top`, `y1` to `.bottom`) |
| kids rect | `.audienceArea`, label from `kidsLabel` or "Kids area" |
| closed rect | `.closedArea` |
| gate, exitPt | `LayoutMarker` |
| foyer, corridor | `LayoutZone` |

Rects become `Placement` with center `((x0 + x1) / 2, (y0 + y1) / 2)` and size `(x1 - x0, y1 - y0)`.

The fake import queue uses this mapper: `ScriptedImportQueue` loads the two mock files in turn for floor plans, maps them with the project's legend, and returns `ExtractedLayout(layout:)`. The counts shown on the setup rows ("209 booths · 2 doors") then come from real data instead of the fixed "66 booths · 3 doors".
* * *
## Inferred defaults

### Categories
The mock has `fnb` and `goods`; the legend has named entries with colors. `MockLayoutMapper` maps:
*   `fnb` to the first legend entry whose name matches food (case-insensitive "food", "f&b", "fnb").
*   `goods` booths to non-food legend entries per name group, cycling through the entries (see `LayoutEditorRulersAndGroupsPlan.md`).

The rule is implemented in `CategoryMatcher.defaultCategories(for:in:)` so it can be tested and later reused by the real mapper. See Design gaps for alternatives.

### Open sides
`OpenSideInference.infer(for booth: LayoutObject, in layout: Layout) -> OpenSides`, pure, in `Core/Domain/`.

For each side of the booth (in its own frame), probe a strip 0.3 m deep and as long as that side, just outside it. The side is closed if the strip overlaps any of: another booth, a table, a `blocksWalking` object, a closed area, or the space outside both the hall and the lobby polygons. Otherwise it is open.

On the mock data this gives back-to-back booth rows open only on their aisle faces and corner booths open on two sides, which is what the Hi-Fi draws (salmon strips on aisle faces, "B-7" open right and bottom).

Inference runs once, on import. After that, open sides are user data: moving a booth does not re-run inference, and the inspector's toggles are the only thing that changes them. A context menu item "Reset open sides" re-runs inference for one booth.

### Door directions
*   Hall doors: `role` `entrance` to `.entrance`, `both` to `.both`, anything else to `.both`.
*   Outer doors have no role. The outer door nearest the `gates` point becomes `.entrance`, the one nearest `exitPt` becomes `.exit`, any other becomes `.both`.

### Labels
*   Booth IDs display with a hyphen between the letters and the number: `B7` shows as "B-7", `XX2` as "XX-2" (matches "Booth B-7"). Stored label stays `B7`. `BoothLabelFormatter.display(_:)`.
*   Door titles use the stored label ("Door A"). The Hi-Fi's "Door NW" and "Door NE" are compass names; the mock doors have letter IDs. Default: show the stored label. `DoorLabelFormatter.compassName(for:in:)` (N, NE, E, SE, S, SW, W, NW from the door center relative to the hall's bounding box) exists for doors without a label and for the tip text if the team prefers compass names (see Design gaps).
* * *
## Editor behavior: Floor Plan tab

Selectable: every kind whose `tab` is `floorPlan` and that is movable or resizable (so not closed areas). Doors are drawn but not selectable here.

| Action | Result |
| ---| --- |
| Click an object | Selects it, inspector shows it. Clicking empty floor or the grid deselects |
| Hover | Thin highlight outline on the object under the pointer |
| Drag a selected object | Moves it. Snaps the center to a 0.25 m grid; hold Option to move freely. The drag is drawn live and committed once on mouse up as one undoable edit |
| Arrow keys | Nudge by 0.25 m, Shift + arrow by 1 m |
| R | Rotate the selection by 90° (rotatable kinds) |
| Delete or Backspace | Delete the selection |
| Cmd+D | Duplicate the selection, offset by 1 m |
| Esc | Deselect, or cancel a drag in progress |
| Right-click an object | Rotate 90°, Duplicate, Reset open sides (booths), Delete |
| Right-click empty floor | Add Booth Here, Add Table Here, Add Fixture Here, Add Rail Here. New booths are 2 x 2 m, unassigned, open sides inferred at the drop point |
| Scroll or pinch | Zoom about the pointer. Cmd+= and Cmd+- zoom about the center, Cmd+0 fits the layout |
| Space + drag, or two-finger scroll | Pan |
| Cmd+Z, Shift+Cmd+Z | Undo, redo |

Canvas look in this tab: blueprint floor, booths white with salmon strips on open sides, the selection filled orange, the stage drawn with a thicker line on its front edge, closed areas hatched, pillars as circles, tables as a round top with four chairs, fixtures as labelled rectangles, zone labels in the lobby.
* * *
## Editor behavior: Flow tab

Selectable: doors only (both hall doors and outer doors). Everything else is drawn pale blue (`canvasFlowFill`) without open-side strips and ignores clicks.

| Action | Result |
| ---| --- |
| Click a door | Selects it, inspector shows Direction, Width, and a tip if one applies |
| Doors by direction | Entrance: peach fill, red outline. Exit: same outline, a small outward arrow. Both: peach fill, arrows both ways. Disabled: grey, dashed outline. Selected: thicker dark red outline |
| Spawn and exit markers | Drawn as small labelled pins ("Entrance", "Exit") in the lobby, not selectable |
| Esc | Deselect |
| Cmd+Z, Shift+Cmd+Z | Undo, redo |

Doors cannot be moved in this release (they belong to walls; moving them needs wall snapping). Width changes keep the door centered on its wall.

Switching tabs clears the selection. If the inspector has unsaved changes, the switch asks first (see Saving).

### Tip callout

`DoorFlowAdvisor.advice(for door: LayoutObject, in layout: Layout) -> DoorAdvice?`, pure, in `Core/Domain/`. It returns at most one tip with a suggested direction; the inspector shows the text and a button that applies the suggestion to the inspector draft (not straight to the layout, so Save Changes still commits it).

Rules, checked in order across the doors with the same `connection` as the selected one:

| # | Condition | Tip | Button |
| ---| ---| ---| --- |
| 1 | No door allows entry (no `entrance` or `both`) | "No door lets visitors in. Make {door} an entrance?" | Use "Entrance" |
| 2 | No door allows exit | "No door lets visitors out. Make {door} an exit?" | Use "Exit" |
| 3 | The selected door is disabled and it is the widest door | "{door} is the widest door. Disabling it slows the crowd. Make it Both?" | Use "Both" |
| 4 | Another door is exit-only, the selected door is `both`, and no door is entrance-only | "{other} is already an exit. Most bazaars use one main entry. Make {door} an entrance?" | Use "Entrance" |

Rule 4 is the Hi-Fi's tip. The Hi-Fi says "Out" and "In" while the menu says "Exit" and "Entrance"; the plan uses the menu's words everywhere (see Design gaps). The rules run on the layout with the inspector draft applied, so the tip updates as the user changes the popup.

The wording lives in `DoorAdviceText`, a small enum with one function per rule, so tests can check it and it can move to bundled JSON later like the recommendation texts.
* * *
## Inspector by object kind

Every inspector has the title at the top and Save Changes at the bottom. Fields edit an `InspectorDraft` (a value copy of the selected object); Save Changes writes it back.

| Kind | Title | Fields |
| ---| ---| --- |
| Booth | "Booth {display label}" | Category (popup: legend entries plus "Unassigned"), Size width x length (m), Rotation, Open Sides |
| Table | "Table {label}" | Size width x length, Rotation |
| Fixture | "{label}" | Label (text), Size, Rotation |
| Stage | "Stage" or its label | Size, Rotation, Front (the Open Sides control limited to one side) |
| Audience area | its label | Label, Size |
| Wall, rail, block | "Wall", "Rail", "Block" | Size (length and thickness), Rotation |
| Pillar | "Pillar" | Diameter (m) |
| Door | "{label}" | Direction (popup: Entrance, Exit, Both, Disabled), Width (m), tip callout |

Field rules:
*   Size fields accept 0.1 m steps, minimum 0.5 m for booths, tables, fixtures, stage, 0.1 m for walls, rails, pillars, maximum the layout size. Invalid input shows the field border in `destructive` and keeps Save disabled.
*   Rotation offers 0°, 90°, 180°, 270° (the circular control steps by 90° per click, a popup or typed value accepts the four values). The mock is axis-aligned and the canvas snaps to a grid, so free angles wait (see Design gaps).
*   Open Sides: the diagram shows the booth as it looks on the canvas (rotated). Clicking an edge toggles that side; the toggle maps the clicked screen edge back to the booth's own side through the rotation. Orange = open, dashed = closed. Hint text "Orange = open · click an edge to toggle".
*   Door width: minimum 0.8 m, maximum the length of its wall segment.
*   Pressing Return in a field does not save; only Save Changes does.
* * *
## Canvas: rendering, viewport, hit testing

### Rendering
SwiftUI `Canvas` (guide, macOS specifics). One `LayoutCanvasView` in `Features/LayoutEditor/ViewComponents/` draws in this order: grid, floor polygons, closed areas, zones, objects by kind (floor items, then obstacles, then booths, then doors), markers, hover outline, selection, drag preview.

Drawing code is split by kind into small renderer types that take a `GraphicsContext`, a `CanvasTransform`, and plain values (rule: components take values). Each stays under the function and type limits:
*   `FloorRenderer` (grid, hall, lobby, closed hatch, zones)
*   `BoothRenderer` (fill, outline, open-side strips, selection)
*   `SeatingRenderer` (tables with chairs)
*   `ObstacleRenderer` (walls, rails, blocks, pillars, fixtures, stage, audience area)
*   `DoorRenderer` (both tabs' looks, direction arrows)
*   `MarkerRenderer`

The canvas redraws on every drag frame; Beyond has 154 booths and 136 tables, which `Canvas` handles. The drag offset is view state, not a layout write, so the session and the history are untouched until mouse up.

### Viewport
`CanvasTransform` (pure, `Features/LayoutEditor/ViewModel/`): `scale` (points per metre) and `offset`. Functions: `toView(_ world:)`, `toWorld(_ view:)`, `fitting(layoutSize:in:padding:)`, `zoomed(by:around:)`, `panned(by:)`. Scale is clamped to 4 to 80 points per metre. Fit on first appear and on Cmd+0.

The grid is drawn in world units (1 m minor lines hidden below 12 points per metre, 5 m major lines always), so it moves with pan and zoom.

### Hit testing
`LayoutHitTester.object(at world: SIMD2<Double>, in layout: Layout, tab: EditorTab) -> LayoutObject.ID?`, pure. It tests rotated rectangles (and circles for pillars) through `LayoutGeometry`, returns the topmost hit in draw order, and skips kinds that are not selectable in the given tab. Doors get a 0.3 m tolerance because they are thin.

### Geometry
`LayoutGeometry` in `Core/Domain/`: `corners(of: Placement)`, `bounds(of:)`, `contains(_:point:)`, `intersects(_:_:)` (separating axis test for rotated rectangles), `polygonContains(_:point:)`. Used by hit testing, open-side inference, and validation, and later by the engine's navigation grid.
* * *
## Editing pipeline, undo, and Save Changes

All edits go through one place (guide, macOS specifics: "Route every editor change through one place so undo is implemented once").

```swift
enum LayoutEdit: Sendable, Equatable {
    case replace(before: LayoutObject, after: LayoutObject)   // move, resize, rotate, inspector save
    case insert(LayoutObject, at: Int)
    case delete(LayoutObject, at: Int)
}
```

*   `LayoutEditing.apply(_ edit:, to layout:) -> Layout` and `inverse(of edit:) -> LayoutEdit`, pure, in `Features/LayoutEditor/ViewModel/` (or `Core/Domain/` if the review step needs it).
*   `LayoutEditHistory`: `undoStack`, `redoStack`, `record(_:)`, `undo() -> LayoutEdit?`, `redo() -> LayoutEdit?`, a cap of 200 entries. A new edit clears the redo stack.
*   The view model applies an edit, records it, and writes the new layout to the session with `updateLayout(_:in:)`. Every committed edit reaches the session at once, so the setup screen counts and later the analysis see the change.
*   The menu bar's Undo and Redo are wired through `AppCommands` and a `FocusedValue` that exposes the editor view model's `undo()` and `redo()` and their availability. The view model does not import SwiftUI and does not touch `UndoManager`.

### Saving inspector changes
*   Selecting an object copies it into `InspectorDraft`. Fields edit the draft only.
*   Save Changes is enabled when the draft differs from the object and the draft is valid. It commits one `.replace` edit (one undo step), then refreshes the draft from the saved object.
*   Canvas edits to the selected object (drag, nudge, rotate key) update both the object and the draft's matching fields, so the draft never shows stale values. If the draft has unsaved field changes, those are kept and only the touched fields follow the canvas.
*   Changing the selection, switching tabs, switching layouts, or leaving the editor with unsaved draft changes shows a dialog: Save, Discard, Cancel.
*   Undo while the draft has unsaved changes first asks the same question.
* * *
## Validation

`LayoutValidator.issues(in layout: Layout) -> [LayoutIssue]`, pure, in `Core/Domain/`. Issues have a severity, the object IDs involved, and a message from `LayoutIssueText`.

| Check | Severity | Shown as |
| ---| ---| --- |
| A booth overlaps another booth or a `blocksWalking` object | Warning | Red outline on both, a line under the inspector title |
| An object sits outside both the hall and the lobby | Warning | Red outline |
| An open side faces an obstacle within 0.3 m | Warning | That side's strip drawn red, a line under Open Sides |
| A booth has no open side | Warning | Line under Open Sides: "Visitors cannot reach this booth" |
| No hall door allows entry, or none allows exit | Warning | Banner at the top of the canvas in the Flow tab |
| A size is below the minimum | Error | Field border `destructive`, Save disabled |

Only errors block Save Changes. Warnings never block; the guide's flow allows editing an imperfect layout, and the reader output is often wrong. The validator runs on the layout with the inspector draft applied, so the inspector shows issues before saving.
* * *
## Navigation and window

*   `AppDestination.review(projectID:)` shows `LayoutEditorView` instead of `ReviewPlaceholderView`. `ProjectScreenFactory.makeLayoutEditorViewModel(projectID:)` builds and caches it like the setup view model.
*   The editor opens on the project's active layout, or the first layout if none is active.
*   `RootView` holds `columnVisibility` for the `NavigationSplitView` and sets it to `.detailOnly` on the review destination, `.all` elsewhere. The Hi-Fi hides the sidebar in the editor.
*   Toolbar (not in the Hi-Fi, needed to use the screen): a back chevron to setup, a layout popup ("Layout 1 · plan-original.pdf") when the project has more than one layout, and the segmented control in the principal position.
*   Minimum detail size 960 x 640. The inspector is a fixed 340 points wide, inset 16 from the top, right, and bottom.
*   Passing `-seedMockProject YES` in the Debug scheme's Run arguments seeds the sample "More Market" and "Annyeong Market" projects and opens directly on the Annyeong one.
* * *
## Design tokens

Add to `Core/DesignSystem/Tokens/Palette.swift`. Values sampled from the editor frames.

| Token | Hex | Used for |
| ---| ---| --- |
| `canvasGridLine` | `#071327` | Grid lines on the dark canvas (background is the existing `background`) |
| `canvasFloor` | `#FBFCFE` | Hall and lobby floor |
| `canvasLine` | `#1F4E86` (approx.) | Blueprint lines: walls, booth outlines, tables |
| `canvasLineGlow` | `#2F6BB1` at 40% | Glow along the outer walls, feature fills |
| `canvasBoothFill` | `#F6F6F6` | Booth fill in Floor Plan |
| `canvasOpenSide` | `#FFBCB0` | Open-side strips |
| `canvasSelection` | `#F86323` | Selected object fill |
| `canvasFlowFill` | `#D9ECF8` | Booths and tables in Flow |
| `canvasFlowLine` | `#708EA9` | Their outlines in Flow |
| `canvasDoorFill` | `#F2CAB6` | Door fill in Flow |
| `canvasDoorLine` | `#EB6547` | Door outline in Flow |
| `canvasDoorSelected` | `#B72008` | Selected door outline |
| `canvasIssue` | `destructive` (`#F44245`) | Validation outlines |
| `highlight` | `#F76222` | Open edges and "Open" labels in the Open Sides control |
| `fieldOnSurface` | `#3F4D64` | Inspector fields and popups (lighter than `field`, which sits on `background`) |
| `fieldOnSurfaceBorder` | `#47556B` | Their borders |
| `popoverOnSurface` | `#4F5D73` | Open popup menus in the inspector |
| `diagramFill` | `#C5CEDB` | The square in the Open Sides control |
| `diagramChip` | `#525A65` | The chip in the square, and the dashed closed edges |
| `tipBackground` | `#8CB5EB` | Tip callout |
| `tipText` | `#072955` | Tip text |
| `tipButton` | `#BAE3FE` | Tip button fill |
| `segmentedSelected` | `#3A485E` | Selected segment (close to `selection` `#384458`; reuse `selection` if the designer agrees) |
| `primaryDisabledOnSurface` | `#50313B` fill, `#A7999D` text | Disabled Save Changes on the inspector panel. The setup screen's disabled Continue is `#281B28`; check with the designer whether these should be one token |

Existing tokens reused: `surface` (inspector panel `#122037` vs sampled `#122037`), `surfaceBorder` (panel border), `textPrimary` (titles, labels), `textSecondary`, `Radius.xl` (panel corners), `Spacing.xl` (panel padding).

Typography additions:

| Token | Approx. | Used for |
| ---| ---| --- |
| `panelTitle` | 17 pt semibold | "Booth B-7", "Door NW" |
| `inspectorLabel` | 12 pt semibold | "Category", "Size", "Rotation" |
| `inspectorLabelDetail` | 12 pt regular | "(width x length)" |
| `segment` | 13 pt medium | Segmented control |
| `canvasLabel` | 9 pt medium, scales with zoom, hidden below 10 points per metre | Labels drawn on the canvas |
* * *
## Components

### Core/DesignSystem (shared)

| Component | Form | Why shared |
| ---| ---| --- |
| `SegmentedTabs` | View, `selection: Binding<Tab>`, `tabs: [Tab]`, `title: (Tab) -> String` | Floor Plan and Flow here; Density, Congestion, Footfall in the simulation; the four analysis tabs. The guide lists it |
| `InspectorPanel` | Generic container with `title` and `@ViewBuilder` content, plus a footer slot | The guide places it in `Features/LayoutEditor/ViewComponents/`; keep it there until a second feature needs it |
| `CalloutCard` | View, `message`, `actionTitle`, `action` | Tip in Flow; the "Our choice" card in Analysis has a similar shape. Keep it feature-local until that second use |
| `FieldOnSurfaceStyle` | TextFieldStyle | Inspector fields; Parameters dialog fields later |

`SegmentedTabs` and `FieldOnSurfaceStyle` go in `Core/DesignSystem` with the five agreement previews. The other two start in the feature (extract on the second use).

### Features/LayoutEditor/ViewComponents

| Component | Inputs | Notes |
| ---| ---| --- |
| `LayoutCanvasView` | `layout: Layout` as a display snapshot, `tab`, `selectionID`, `hoverID`, `issues`, `transform: Binding<CanvasTransform>`, callbacks (`onSelect`, `onHover`, `onDragEnded`, `onContextAction`) | Takes values and closures, not the view model |
| Renderers (six) | `GraphicsContext`, `CanvasTransform`, plain values | See Canvas |
| `InspectorPanel` | `title`, content, `footer` | Panel chrome |
| `BoothInspector` | `draft: Binding<InspectorDraft>`, `categories: [CategoryOption]`, `issues: [String]` | Category popup, size, rotation, open sides |
| `DoorInspector` | `draft: Binding<InspectorDraft>`, `advice: DoorAdviceDisplay?`, `onUseAdvice` | Direction popup, width, tip |
| `GenericInspector` | `draft`, `fields: InspectorFields` | Table, fixture, stage, wall, pillar, audience area; `InspectorFields` comes from the kind |
| `SizeFields` | `width: Binding<Double>`, `length: Binding<Double>`, `range` | "2 × 2 m" row |
| `RotationControl` | `degrees: Binding<Int>` | Steps by 90° |
| `OpenSidesControl` | `sides: Binding<OpenSides>`, `rotationDegrees`, `chip: String?`, `allowsMultiple: Bool = true` | Stage passes `false` (single front). The Boolean only limits the toggle, not the layout, so it does not break component rule 5 |
| `CalloutCard` | `message`, `actionTitle`, `action` | Tip |
| `UnsavedChangesDialog` | modifier with Save, Discard, Cancel closures | Used on selection, tab, layout, and back changes |

Display types built by the view model, so views only show strings: `CategoryOption (id, name, color)`, `DoorAdviceDisplay (message, actionTitle)`, `InspectorTitle`.
* * *
## Files

```
App/
  AppCommands.swift                         Undo, Redo, Zoom, Fit, Delete, Duplicate, Rotate menu items
  Navigation/
    AppRouter.swift                         (unchanged destinations)
    ProjectScreenFactory.swift              + makeLayoutEditorViewModel(projectID:)
    RootView.swift                          columnVisibility, review shows LayoutEditorView
Core/
  Domain/
    Layout.swift, LayoutObject.swift, LayoutObjectKind.swift,
    Placement.swift, OpenSides.swift, DoorFlow.swift,
    LayoutMarker.swift, LayoutZone.swift
    LayoutGeometry.swift
    OpenSideInference.swift
    LayoutValidator.swift, LayoutIssue.swift, LayoutIssueText.swift
    DoorFlowAdvisor.swift, DoorAdviceText.swift
    ExtractedLayout.swift                   + layout, computed counts
    ProjectDraft.swift                      layouts: [Layout]
  DesignSystem/
    Tokens/      Palette, Typography (additions)
    Components/  SegmentedTabs
    Styles/      FieldOnSurfaceStyle
  Services/
    LayoutImport/
      BazaarLayoutDTO.swift                 moved from Domain, decodes every key
      MockLayoutMapper.swift
      CategoryMatcher.swift
  Session/
    ProjectSession.swift                    + layout(id:in:), updateLayout, active layout
Features/
  LayoutEditor/
    View/
      LayoutEditorView.swift
    ViewModel/
      LayoutEditorViewModel.swift           selection, tab, coordination
      LayoutEditorViewModel+Editing.swift   move, delete, duplicate, add, undo, redo
      LayoutEditorViewModel+Inspector.swift draft, save, discard, advice
      InspectorDraft.swift
      LayoutEdit.swift, LayoutEditing.swift, LayoutEditHistory.swift
      CanvasTransform.swift
      LayoutHitTester.swift
      BoothLabelFormatter.swift, DoorLabelFormatter.swift
      EditorTab.swift
    ViewComponents/
      LayoutCanvasView.swift
      FloorRenderer.swift, BoothRenderer.swift, SeatingRenderer.swift,
      ObstacleRenderer.swift, DoorRenderer.swift, MarkerRenderer.swift
      InspectorPanel.swift, BoothInspector.swift, DoorInspector.swift,
      GenericInspector.swift, SizeFields.swift, RotationControl.swift,
      OpenSidesControl.swift, CalloutCard.swift, UnsavedChangesDialog.swift
PreviewSupport/
  ScriptedImportQueue.swift                 returns mapped mock layouts
  PreviewLayouts.swift                      small hand-built layouts for previews
Tests/
  Fixtures/small-layout.json                ~10 objects of every kind, for mapper tests
  Core/  MockLayoutMapperTests, CategoryMatcherTests, OpenSideInferenceTests,
         LayoutGeometryTests, LayoutValidatorTests, DoorFlowAdvisorTests,
         ProjectSessionLayoutTests
  Features/  LayoutEditingTests, LayoutEditHistoryTests, CanvasTransformTests,
             LayoutHitTesterTests, LayoutEditorViewModelTests,
             LayoutEditorViewModelInspectorTests, BoothLabelFormatterTests,
             DoorLabelFormatterTests
```

`Tests/Fixtures/small-layout.json` needs the test target to bundle it: add it to the test target's resources, and load it with `Bundle(for:)` through a small test helper (the app's `MockDataStore` loads from `.main`).

The view model is split into extensions by concern to stay under the 250-line type body limit. If the extensions still add up past it, move editing into a separate `LayoutEditingController` the view model owns.
* * *
## Commit order

Conventional Commits, one logical change each, tests in the same commit as the behavior (agreement).

1.  `refactor: move bazaar layout decoding to layout import service`
2.  `feat: decode every key of the mock layout files`
3.  `feat: add layout domain types and object kind facts`
4.  `feat: add layout geometry helpers`
5.  `feat: infer booth open sides from neighbours`
6.  `feat: map mock layouts to domain layouts`
7.  `feat: carry layouts through import, draft, and session`
8.  `feat: add segmented tabs and inspector field style`
9.  `feat: add canvas transform and hit testing`
10. `feat: draw layouts on the editor canvas`
11. `feat: add layout edits and history`
12. `feat: add layout editor view model with selection and tabs`
13. `feat: add booth and generic inspectors with save changes`
14. `feat: add door inspector with flow advice`
15. `feat: add canvas drag, keyboard, and context menu editing`
16. `feat: validate layouts and show issues`
17. `feat: open the editor from review and hide the sidebar`
18. `feat: add editor menu commands`
19. `docs: describe layout editor in architecture guide`
* * *
## Tests and previews

### Unit tests (fast plan)

`MockLayoutMapperTests`
*   Annyeong maps to 209 booths, 26 tables, 4 doors (2 hall, 2 outer), 4 closed areas, 1 stage with front `.left`, 1 audience area labelled "AUDIENCE", 3 rails, 3 walls (2 pilasters plus the lobby wall), 1 fixture, 2 markers, 2 zones
*   Beyond maps to 154 booths, 136 tables, 4 doors, 6 closed areas, 23 pillars, 3 blocks, 3 rails, 3 walls, a stage with front `.bottom`, an "EXT" stage, 5 fixtures, no zones
*   A rect maps to the right center and size
*   An outer door keeps its along-wall length as width
*   Missing optional keys (`foyer`, `kidsLabel`) decode without failing

`CategoryMatcherTests`
*   "fnb" matches "Food & Beverage", "F&B", and "FNB"
*   "goods" matches nothing
*   An empty legend matches nothing

`OpenSideInferenceTests` (small hand-built layouts)
*   A lone booth in the hall is open on four sides
*   Two booths back to back are closed on the shared side
*   A booth against the hall edge is closed on that side
*   A booth next to a closed area or a rail is closed on that side
*   A rotated booth reports sides in its own frame
*   On Annyeong, no booth has zero open sides (sanity check on the real data; tag `.slow` if it is not fast)

`LayoutGeometryTests`
*   Corners of a 90° rotated 2 x 4 rect
*   Intersection true for overlapping rotated rects, false for touching edges
*   Polygon contains a point inside the chamfered lobby, not one in the cut corner

`LayoutValidatorTests`
*   Overlapping booths give one warning naming both
*   A booth outside both polygons gives a warning
*   An open side against a booth gives a warning
*   A booth with no open sides gives a warning
*   Hall doors with no entrance give a warning
*   A booth below the minimum size gives an error

`DoorFlowAdvisorTests`
*   One test per rule, plus "no advice when entrances and exits are fine"
*   Rule 4 text names the other door and the selected door

`LayoutEditingTests` and `LayoutEditHistoryTests`
*   Apply then inverse returns the original layout, for each edit case
*   Undo after a move restores the position; redo moves it again
*   A new edit clears redo
*   The history caps at 200

`CanvasTransformTests`
*   `toWorld(toView(p)) == p`
*   Zoom keeps the point under the pointer fixed
*   Fit centers a 70 x 84 m layout in a 1000 x 800 view with padding
*   Scale clamps to 4 and 80

`LayoutHitTesterTests`
*   Topmost object wins
*   A rotated booth is hit inside its rotated area and missed outside
*   Doors are skipped in Floor Plan; booths are skipped in Flow
*   A door is hit within its 0.3 m tolerance

`LayoutEditorViewModelTests` (with `ProjectSession` and a layout from `PreviewLayouts`)
*   Selecting a booth fills the draft
*   Switching tabs clears the selection
*   Flow tab ignores a booth click
*   Drag end commits one edit and writes the session
*   Delete removes the object and can be undone
*   Duplicate adds a copy 1 m away
*   Add Booth Here adds an unassigned 2 x 2 booth with inferred sides

`LayoutEditorViewModelInspectorTests`
*   Save is disabled until the draft changes
*   Save commits one undoable edit
*   Changing selection with unsaved changes requests confirmation, Discard drops the changes, Save keeps them
*   An invalid size disables Save
*   Use advice sets the draft's direction, and Save applies it
*   Toggling the screen-right edge of a booth rotated 90° toggles its own `top` side

`BoothLabelFormatterTests` and `DoorLabelFormatterTests`
*   "B7" displays as "B-7", "XX2" as "XX-2", "A12" as "A-12"
*   A door at the top left of the hall is "NW"

`ProjectSessionLayoutTests`
*   `updateLayout` replaces the matching layout only
*   The active layout is stored per project

### Previews
*   `SegmentedTabs` and `FieldOnSurfaceStyle`: the five agreement previews.
*   `OpenSidesControl`: none open, two open, all open, rotated 90°, stage (single front), disabled.
*   `BoothInspector`, `DoorInspector` (with and without a tip), `GenericInspector` for a table and a fixture.
*   `LayoutCanvasView` with Annyeong in Floor Plan, Beyond in Flow, a selected booth, a validation issue, and zoomed in on labels.
*   `LayoutEditorView` with the full mock, both tabs.
* * *
## Design gaps and defaults

| Gap | Default |
| ---| --- |
| How to add new items (guide: "still open") | Right-click on empty floor: Add Booth, Table, Fixture, Rail Here |
| How to switch layouts in a multi-layout project | Toolbar popup, shown when there is more than one layout |
| How to leave the editor | Toolbar back chevron to setup until the project screen exists |
| Mock `fnb` and `goods` vs a three-entry legend | `fnb` to the food entry, `goods` to Unassigned. Alternatives: map `goods` to the second legend entry, or ask the user once on entering the editor |
| Mock door role `both` vs a three-item menu | Menu shows Entrance, Exit, Both, Disabled |
| "In" and "Out" in the tip vs "Entrance" and "Exit" in the menu | Use Entrance and Exit everywhere |
| Compass door names ("Door NW") vs mock IDs ("Door A") | Show stored labels; compass names only for unlabelled doors |
| The "A" chip in the Open Sides square | Unknown. Likely the zone letter (zones A to F appear on the project screen), but zones come from the engine. Default: hide the chip until zones exist |
| Rotation: free angle or 90° steps | 90° steps. The data and the grid are axis-aligned |
| The guide's door "angle" vs the Hi-Fi's door width | Width, as in the Hi-Fi. Update the guide's `DoorFlow` description in the docs commit |
| Category colors on the canvas | Not shown, as in the Hi-Fi. A colored dot appears on hover only |
| Moving doors | Not in this release |
| Disabled Save color differs between setup and editor | Separate token for now, ask the designer |
| Booths in the lobby (Beyond has 14) | Allowed; the lobby is walkable floor |
| What the round feature in the Hi-Fi's middle is | Not in the mock data. Nothing to build |
* * *
## Out of scope

*   Review mode marks. `LayoutObject.reviewState` is added and set to `.detected` by the mapper, but nothing shows or changes it yet. A "Confirm all" control and dashed outlines for unconfirmed objects come with the project screen work.
*   Marquee selection and group move.
*   Editing the hall and lobby polygons, walls, and closed areas.
*   Moving doors along walls.
*   The project screen and layout cards (`ProjectOverview`).
*   Persisting layouts (backend PR, `ProjectRepository`).
*   Export.
* * *
## PR description outline

**What and how**
*   Domain: `Layout`, `LayoutObject`, `LayoutObjectKind` with per-kind facts, `Placement`, `OpenSides`, `DoorFlow`, geometry, open-side inference, validation, door advice.
*   Import: `BazaarLayoutDTO` decodes every mock key, `MockLayoutMapper` builds layouts, `ScriptedImportQueue` returns them, drafts and the session carry `[Layout]`.
*   Editor: `LayoutEditorView`, `LayoutEditorViewModel`, `InspectorDraft`, edit history, `CanvasTransform`, hit testing, six renderers, inspectors per kind, `SegmentedTabs`.
*   Navigation: review shows the editor with the sidebar hidden, toolbar back and layout picker, menu commands.
*   Defaults used for each design gap.
*   Any linter warning left, with one sentence each.

**Testing**
*   Manual: open both mock layouts, select and move booths, rotate, toggle open sides, change category, save, undo and redo, delete and duplicate, add a booth from the context menu, switch to Flow, change a door's direction and width, use the tip, check the unsaved-changes dialog, zoom and pan, check warnings by overlapping two booths.
*   Automated: the suites listed in Tests.

**Checklist**
- [ ] Builds with no SwiftLint errors
- [ ] Fast test plan passes
- [ ] New logic has tests, and a bug fix has a regression test
- [ ] No layer rule is broken
- [ ] New shared components have previews and use design tokens
- [ ] The ClickUp task is linked
