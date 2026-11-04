# Layout Editor: 3D Views and Object Library

> Plan for two additions to the Layout editor: view presets (Plan, 3D, Front, Eye) that show the layout as a RealityKit 3D scene, and an object library built from the project's legend, the booths detected in its layouts, a generic event catalog, and walls and doors. Ideas come from CROWD ([devYRPauli/crowd at 4fec198](https://github.com/devYRPauli/crowd/tree/4fec198131984bd08fcacc71535c3b4acf408f43), MIT), a browser floor-plan editor and crowd simulator in TypeScript and Three.js. This plan ports ideas, not code. It follows `ArchitectureGuide.md`, `DeveloperAgreement.md`, the earlier editor plans, and `docs/reference/apple-swiftui-27/`.

## Table of contents
*   Decisions
*   What CROWD does, and what we take
*   1. View presets and the 3D scene
*   2. The object library
*   3. Walls and doors from the library
*   Data model changes
*   Architecture changes
*   Files
*   Commit order
*   Tests and previews
*   Design gaps and defaults
*   Out of scope
* * *
## Decisions

| Question | Decision |
| --- | --- |
| Deliverable | This plan on `feature/layout-editor`, plus a local implementation handoff |
| How 3D fits the editor | View presets in the editor. Plan is today's 2D canvas and stays the only place that edits geometry. 3D, Front, and Eye show the same layout in 3D with orbit, pan, zoom, and selection; the inspector still edits the selected object's fields |
| Library contents | Booth templates per legend category and detected size; a generic event catalog; a library panel with search, category tabs, and footprint thumbnails; 3D looks described as data; walls and doors |
| 3D framework | RealityKit, through SwiftUI's `RealityView` on macOS. The architecture guide asks for a short spike first; the plan starts with one |
* * *
## What CROWD does, and what we take

Read from the repository at commit `4fec198`.

| CROWD | Where | What we take |
| --- | --- | --- |
| One camera rig, four presets: `plan` (orthographic, straight down), `iso`, `front`, `eye`, defined by azimuth, polar angle, distance, and a perspective blend. Switching tweens over 0.55 s with a cubic ease and takes the short way round; it snaps instantly under Reduce Motion | `src/render/CameraRig.ts` | The same state (target, azimuth, polar, distance) and preset table as a pure Swift `CameraRig`, the tween, the short-way rule, and the Reduce Motion rule. Our Plan stays the 2D canvas, so the rig only drives 3D |
| The left button belongs to the active tool; navigation is on right and middle buttons, the wheel, and Space-drag. Wheel zoom moves toward the point under the pointer | `CameraRig.ts`, `Viewport.ts` | In our 3D views nothing is drawn with the left button, so left-drag orbits. Shift-drag pans, the wheel and pinch zoom toward the pointer |
| CROWD's "eye" preset is a low orbit angle (polar 1.53, distance capped at 14 m), not a first-person walk | `CameraRig.ts` | We go further: Eye is a visitor's view at 1.6 m, walking with the arrow keys. See Design gaps |
| The catalog is data. Each item has a default size, a blocking flag, a rect or circle footprint, an inset, a resize policy, search keywords, the seats it offers, and a builder that returns primitives (box, cylinder, sphere, torus) for any size. Adding an item touches no renderer or editor code | `src/library/catalog.ts`, `primitives.ts` | The same shape: `CatalogItem` with a `shape(size)` builder returning `ShapePrimitive`s. Booths get their shape from their open sides |
| Default sizes follow trade conventions (5 ft banquet round, 6 ft trestle, 750 mm table height, 1100 mm bar) | `catalog.ts` | Generic catalog uses the same conventions in metres |
| Library panel: search, category chips, top-down SVG footprint thumbnails with seats marked and a face marker | `src/app/panels/LibraryPanel.tsx` | Same layout in SwiftUI; thumbnails drawn with `Canvas` from the footprint, open sides, and seats |
| Placing furniture previews in full under the pointer, orients against the nearest wall within 1.2 m, rotates with R (Shift-R by 90 degrees), Alt places freely | `src/editor/tools/placementTools.ts`, `geometryHelpers.ts` | Same placement behavior, with our 0.25 m grid and our R and Option keys |
| Doors and windows are placed by moving onto a wall and clicking; they live on the wall at an offset | `placementTools.ts` (`OpeningTool`) | Doors snap onto a wall object or a hall or lobby edge |
| Walls are drawn by clicking a chain of points; a typed length places a segment exactly | `src/editor/tools/drawTools.ts` | Wall tool with chained clicks, angle snap with Shift, and a typed length |
| Walls are drawn in 3D as solid spans between openings plus a lintel over each door, not with a boolean cut | `src/render/builders/planMeshes.ts` | Perimeter walls from the hall and lobby polygons, split into spans around doors |
| The ground grid is one quad with a shader; minor lines fade out below a few pixels | `src/render/overlays/GroundGrid.ts` | A floor grid in 3D, drawn as a texture or thin geometry, matching `RulerScale` steps |
| Layers panel lists every object and doubles as a picker | `src/app/panels/LayersPanel.tsx` | Not this round; the Groups list covers booths |

Not taken: CROWD's walls are the plan's primary data, with rooms derived from them. Ours are the imported hall and lobby polygons plus wall objects; that stays.
* * *
## 1. View presets and the 3D scene

### Presets

| Preset | Camera | Interaction |
| --- | --- | --- |
| Plan | Today's 2D canvas | Everything the editor does today |
| 3D | Perspective from the south-east corner, 40 degrees off the front axis, polar 58 degrees (CROWD's iso uses 1.02 rad), framed on the layout | Drag orbits, Shift-drag pans, wheel and pinch zoom toward the pointer, click selects |
| Front | Perspective from the entrance side (the lobby, +y in plan), polar 77 degrees (CROWD's front uses 1.35 rad) | Same as 3D |
| Eye | 1.6 m above the floor, starting at the first spawn marker looking into the hall, 70 degree field of view | Drag looks around, arrow keys walk 0.5 m (Shift 2 m), click selects along the eye's line of sight, scroll does nothing; position stays inside the combined bounds of the hall and lobby, since the spawn marker is usually in the lobby |

*   The preset picker is a `SegmentedTabs` in the toolbar next to Floor Plan and Flow, or a second row under it if the toolbar runs out of room. Keys: 1 Plan, 2 3D, 3 Front, 4 Eye on the focused view, with no menu shortcuts (bare keys in menus steal text input).
*   Switching from Plan to a 3D preset starts the camera straight above the layout at the framing the canvas had, then tweens to the preset; switching back tweens to straight down and hands the framing to the canvas. Under Reduce Motion the change is instant.
*   Wheel and pinch zoom use the canvas scroll bases (`CanvasTransform.lineScrollZoomBase` and `preciseScrollZoomBase`), so one wheel notch is about 10% in both views and scrolling the same way zooms the same way.
*   Floor Plan and Flow tabs still apply in 3D: Flow colors booths pale and highlights doors with their direction, as in 2D.
*   The blocked-area tool and every placement tool switch the view to Plan when chosen.

### What the 3D scene shows

| Object | 3D look (default heights) |
| --- | --- |
| Floor | Hall and lobby polygons as a floor slab, `canvasFloor` color, with the grid from `RulerScale` |
| Perimeter | Walls 3.0 m along the hall and lobby polygon edges, cut where doors sit, with a lintel at 2.1 m over each door |
| Wall objects | Boxes at their placement, wall 3.0 m, rail 1.0 m, block 1.2 m. Walls are cut around their doors the same way perimeter edges are, at the wall's own thickness, with the lintel at the door's height |
| Booth | Back and side panels 2.4 m on closed sides, a counter 1.0 m on open sides, a 0.4 m fascia band at 2.4 m on the open side carrying the booth label, tinted with the booth's category color |
| Table | Catalog shape (round top on a pedestal, four chairs) |
| Stage | 0.8 m platform with steps on its front side |
| Audience area | Floor tint only |
| Pillar | Cylinder 3.0 m |
| Fixture | Its catalog shape, or a 1.2 m box |
| Blocked area | Floor hatch tint plus a 0.05 m slab |
| Door | Gap in the wall; in the Flow tab an arrow on the floor per direction |
| Markers | Small poles with a label (Entrance, Exit) |
| Selection | A 2-point outline box in `highlight` around the selected object or each group member; warnings in `canvasIssue` |

Colors come from new `Palette` tokens for 3D (`sceneFloor`, `sceneWall`, `scenePanel`, `sceneCounter`, `sceneSlab`), plus the legend colors for category tints. Lighting: one key directional light and one soft fill, no shadows in the first round.

### Building the scene

*   A pure step, `SceneGeometryBuilder`, turns a `Layout` plus the legend into triangle meshes grouped by material role (positions, normals, indices). It runs off the main actor. A second step makes RealityKit `MeshResource`s on the main actor, one entity per material role, so the whole static layout is a handful of draw calls.
*   The scene rebuilds when the active layout or the inspector draft changes, debounced by 80 ms. Each build carries a version, and a build that finishes after a newer one has started is dropped. Selection and hover outlines are separate small entities updated immediately.
*   Mapping: plan `(x, y)` in metres becomes world `(x, height, y)`. Looking straight down with the camera's up vector toward -z shows the plan the same way the canvas does, because the canvas puts world -y at the top of the screen. Plan therefore uses azimuth π/2 (`CameraRig.planAzimuth`), which offsets the camera toward +z; azimuth 0 turned the view a quarter turn and disagreed with the floor picker.

### Picking in 3D

Clicks in 3D cast a ray from the camera through the pointer (pure math from the `CameraRig` pose and field of view), intersect it with the floor plane, and reuse `LayoutHitTester` at that point. Tall objects are picked by their footprint, which is enough for selecting; a true mesh ray-cast can come later.

### Performance budget

On Beyond (154 booths, 136 tables, 23 pillars) the scene is about 60,000 triangles in under ten entities. Rebuild must stay under 50 ms on an Apple silicon Mac; the spike measures it.
* * *
## 2. The object library

### Panel

The panel that shows the Groups list when nothing is selected gets two tabs: Library and Groups. The Library tab has:

*   A search field (name and keywords).
*   Category chips: All, From this project, Structure, Furniture, Decor.
*   Rows with a footprint thumbnail (outline, open-side strips for booths, seats as dots, a face marker), the name, the size, and for project templates the count already placed.
*   Click a row to start placing it; drag a row onto the canvas to place it where it is dropped. Placing only happens in Plan; choosing a row switches to Plan.

### From this project: booth templates

Templates come from the project, not from a fixed list: every legend category crossed with every booth size key (`BoothGrouping.sizeKey`, rounded to 0.5 m, orientation-free) that appears in any of the project's layouts, with the count. Placing one makes a booth of that size and category, with open sides inferred where it lands.

With the seeded mock project (both layouts, default categories), that gives 13 templates:

| Category | Sizes (count placed) |
| --- | --- |
| FNB | 2.0 × 2.0 m (94), 2.0 × 3.0 m (18) |
| Fashion | 2.0 × 2.0 m (21), 2.0 × 3.0 m (4), 2.5 × 2.5 m (120), 2.5 × 5.0 m (8), 3.0 × 4.0 m (9), 5.0 × 5.0 m (3) |
| Lifestyle & Hobbies | 2.0 × 2.0 m (18), 2.5 × 2.5 m (30), 3.0 × 3.0 m (26), 4.0 × 4.0 m (3), 5.0 × 5.0 m (9) |

Annyeong alone has 5 (FNB 2 × 2: 42; Fashion 2.5 × 2.5: 120, 2.5 × 5: 8; Lifestyle 2.5 × 2.5: 30, 5 × 5: 9) and Beyond alone 9. Sort by category in legend order, then by count. A legend category with no booths still gets one template at the project's most common size, so every category can be placed.

### Generic catalog

| Category | Items (default size, metres) |
| --- | --- |
| Structure | Wall (length × 0.2, 3.0 high), Partition (× 0.1, 2.4), Rail (× 0.05, 1.0), Block (1.0 × 1.0, 1.2), Pillar (⌀ 0.6, 3.0), Door (0.9), Double door (1.8), Gate (3.0), Blocked area (drawn) |
| Furniture | Round table for 4 (⌀ 1.0), for 6 (⌀ 1.524), for 8 (⌀ 1.83), Rectangular table 6 ft (1.83 × 0.76), Bar table (⌀ 0.6, 1.1 high), Bench (1.8 × 0.4), Stage (4 × 3, 0.8 high), Stage extension (3 × 3), Counter (2.0 × 0.6, 1.1 high), Kiosk (0.6 × 0.5, 1.6 high) |
| Decor | Planter (1.0 × 0.5), Floor sign (0.6 × 0.4, 1.6 high), Banner stand (0.8 × 0.3, 2.0 high), Bin (⌀ 0.4), Display case (1.2 × 0.6, 1.0 high), Claw machine (0.9 × 0.9, 1.9 high), Photo booth (2.0 × 2.0, 2.2 high) |

Each item maps to an existing `LayoutObjectKind` (table, fixture, stage, rail, wall, block, pillar, door, closedArea) and carries a `catalogID` for its footprint shape and 3D look. No new kinds are needed.

### Placing

Following CROWD's placement tool:

*   The item previews under the pointer at full size, translucent, with its dimensions.
*   Within 1.2 m of a wall object or a hall or lobby edge, the item turns its front away from the wall and sits against it. Booth templates also snap flush against a neighbouring booth's side, so rows can be extended by clicking.
*   R rotates by 90 degrees, Option places freely (no grid, no wall pull), Escape ends placing, a click places one and keeps the tool active for the next (CROWD's behavior), Shift-click places one and returns to Select.
*   Overlapping a booth or wall by more than 0.1 m is a warning, not a block: the preview names the object it overlaps and can still be placed, and `LayoutValidator` reports the overlap after the drop. Booths snapped flush do not trigger it. Hall and lobby edges are treated as 0.2 m thick when snapping, matching the walls drawn in 3D.
*   Each placement is one undo step.
* * *
## 3. Walls and doors from the library

### Walls, partitions, rails

*   The Wall item (and Partition and Rail) start a drawing tool: click to start, click to end a segment, keep clicking to chain, double-click or Escape to finish.
*   Points snap to 0.25 m, to the ends of other walls, and to hall and lobby corners. Shift locks the segment to 0, 45, or 90 degrees.
*   While drawing, typing a number and Return sets the segment's length exactly in the current direction.
*   Each segment becomes a `wall`, `rail`, or `block` object, so all existing editing (move, resize handles if added later, rotate, delete) applies. A chain is one undo step.

### Doors

*   Door, Double door, and Gate place onto a host: a `wall` object or a hall or lobby polygon edge within 1.2 m of the pointer. The preview slides along the host and turns with it; there is no placement away from a host (the preview turns red).
*   The door's connection follows the host: the wall between hall and lobby gives `hallToLobby`, a lobby edge gives `lobbyToOutside`, a hall outer edge gives the new `hallToOutside` (for emergency and side exits). On a hall edge the connection is decided per door from its own position, since one edge can touch the lobby along only part of its length; it is set again when the door is dragged.
*   Direction starts as Both. The Flow tab and its door advice work on new doors unchanged.
*   Existing and new doors become draggable along their host: dragging projects onto the host edge and stops at its ends. Today doors cannot move at all.
* * *
## Data model changes

| Type | Change |
| --- | --- |
| `LayoutObject` | `catalogID: String?` (look and footprint shape, nil means the kind's default) and `heightM: Double?` (nil means the catalog or kind default). Both optional, so existing drafts decode unchanged |
| `DoorConnection` | New case `hallToOutside` |
| `LayoutObjectKind.door` | `isMovable` becomes true; the move is constrained along the host |
| `MockLayoutMapper` | Sets `catalogID`: tables `table-round-4`, stage `stage`, "EXT" `stage-extension`, columns `pillar-round`, fixtures by label (DECOR `planter`, DOORPRIZE `display-case`, CLAW MACHINES `claw-machine`) |
| New `CatalogItem` | id, name, category, kind, default size and height, footprint (rect or circle), resize policy, keywords, `shape(size) -> [ShapePrimitive]`, optional seats |
| New `BoothTemplate` | category ID, size key, count; derived, never stored |
* * *
## Architecture changes

*   The 3D scene was planned inside `Features/Simulation/Scene/`. The editor now needs it too, and features must not import each other, so the shared part moves to Core:
    *   `Core/Domain/Catalog/` (Foundation and `simd` only): catalog items, shape primitives, booth shapes, booth templates.
    *   `Core/Scene3D/` (RealityKit, plus `Core/DesignSystem` tokens): scene geometry builder (pure), mesh and material factory, camera rig math. The simulation's crowd and heatmap layers will add to it later.
*   `ArchitectureGuide.md` changes in the same PR: directory structure, the Simulation paragraph that says the scene lives in `Features/Simulation/Scene/`, and the layer rules (Core/Scene3D may import RealityKit; the engine still may not).
*   The editor's 3D view (`Layout3DView`) lives in `Features/LayoutEditor/ViewComponents/` and takes values and closures, like `LayoutCanvasView`.
* * *
## Files

```
Core/
  Domain/Catalog/
    ShapePrimitive.swift        box, cylinder, material roles, translate and rotate helpers
    CatalogItem.swift           item type, categories, footprint, resize policy
    ObjectCatalog.swift         the generic items
    BoothShape.swift            booth primitives from size, open sides, and category
    BoothTemplates.swift        templates derived from a project
    CatalogFootprint.swift      hit-test and thumbnail footprints (rect or circle)
  Domain/
    LayoutObject.swift          + catalogID, heightM
    DoorFlow.swift              + hallToOutside
    DoorHosting.swift           find a host edge, project a door onto it
    PerimeterWalls.swift        hall and lobby edges split into spans around doors
  Scene3D/
    SceneGeometryBuilder.swift  Layout -> [MaterialRole: TriangleMesh]   (pure)
    TriangleMesh.swift          positions, normals, indices; box and cylinder generators (pure)
    SceneMeshFactory.swift      TriangleMesh -> MeshResource, roles -> materials
    CameraRig.swift             presets, orbit, pan, zoom, tween, eye walk   (pure)
    CameraRay.swift             pointer -> ray -> floor point                (pure)
  DesignSystem/Tokens/Palette.swift   + scene tokens
  Services/LayoutImport/MockLayoutMapper.swift   + catalog IDs
Features/LayoutEditor/
  ViewModel/
    ViewPreset.swift
    EditorTool.swift                    + place(itemID), drawWall(itemID)
    LibraryDisplay.swift                rows for the panel
    LayoutEditorViewModel+Library.swift search, place, booth templates
    LayoutEditorViewModel+Walls.swift   wall drawing
    LayoutEditorViewModel+Doors.swift   door placement and constrained drag
    LayoutEditorViewModel+Views.swift   preset switching, camera state, 3D picking
    PlacementResolver.swift             wall pull, booth row snap, rotation (pure)
    WallDrawing.swift                   chain, angle lock, typed length (pure)
  ViewComponents/
    Layout3DView.swift
    ViewPresetPicker.swift
    LibraryPanel.swift
    LibraryRow.swift
    FootprintThumbnail.swift
    PlacementPreviewRenderer.swift
  View/
    LayoutEditorView.swift              Plan canvas or 3D view by preset; Library and Groups tabs
Tests/
  Core/  CameraRigTests, CameraRayTests, SceneGeometryBuilderTests, PerimeterWallsTests,
         BoothShapeTests, BoothTemplatesTests, ObjectCatalogTests, DoorHostingTests
  Features/  PlacementResolverTests, WallDrawingTests, LayoutEditorViewModelLibraryTests,
             LayoutEditorViewModelDoorTests, LayoutEditorViewModelViewsTests
```
* * *
## Commit order

Phase 0, spike (not merged): a `RealityView` with Beyond's booths as boxes, one camera entity driven by a hand-written orbit, measured rebuild time and frame rate. Record the result in the PR.

### Spike results (phase 0)

*   RealityView custom camera: macOS 27 supports `content.camera = .virtual` driven by a `PerspectiveCamera` entity, with built-in controls disabled via `.realityViewCameraControls(.none)`.
*   Rebuild time for Beyond's 154 booths and objects into `MeshResource`: under 4 ms total (~1.8 ms off-main-actor build, ~1.2 ms resource generation on main actor).
*   Frame rate: solid 60 fps (120 fps ProMotion) while orbiting at full window and fullscreen sizes.
*   Update loop: `content.subscribe(to: SceneEvents.Update.self)` reliably supplies `event.deltaTime` for smooth cubic-eased camera tweens.
*   Angles: 3D preset azimuth `pi / 2 - 0.70`, polar `1.02`; Front polar `1.35`, azimuth `pi / 2`; Plan polar `0.0001`, azimuth `0.0`; Eye fov 70 degrees, orbit fov 46 degrees.

1.  `feat: add catalog items and shape primitives`
2.  `feat: derive booth templates from project layouts`
3.  `feat: give layout objects catalog ids and heights`
4.  `feat: add library panel with search and footprints`
5.  `feat: place catalog items and booth templates on the canvas`
6.  `feat: draw walls, partitions, and rails`
7.  `feat: place doors on walls and edges and slide them along`
8.  `feat: add camera rig and floor picking math`
9.  `feat: build 3D scene geometry from a layout`
10. `feat: show the layout in 3D with view presets`
11. `feat: select objects and show outlines in 3D`
12. `feat: walk the layout in eye view`
13. `docs: move the 3D scene to core in the architecture guide`
* * *
## Tests and previews

`BoothTemplatesTests`: the seeded project yields 13 templates with the counts above; Annyeong alone 5, Beyond alone 9; a category without booths gets one template at the most common size.

`ObjectCatalogTests`: ids are unique; every item's kind can be added; every shape stays inside its footprint (CROWD's `legs` comment explains why that matters: drawn steel outside the declared footprint is something people walk through).

`BoothShapeTests`: a booth open on two sides has panels on the other two and counters on the open two; a rotated booth's panels follow its own frame.

`PerimeterWallsTests`: a hall edge with one door gives two spans and a lintel; a door at a corner clips to the edge.

`SceneGeometryBuilderTests`: triangle counts per role for a small layout; Beyond stays under 80,000 triangles; every normal has unit length.

`CameraRigTests`: each preset's polar and azimuth; the tween ends exactly on the target pose; the short way round across the wrap; zoom keeps the point under the pointer; eye walk stays inside bounds.

`CameraRayTests`: the screen centre maps to the target point; a point above the horizon has no floor hit.

`DoorHostingTests`: the nearest host within 1.2 m wins; the connection follows the host; a projected door stops at the edge ends.

`PlacementResolverTests`: an item near a wall turns away from it and sits flush; Option disables the pull; a booth template snaps flush to a neighbour's side.

`WallDrawingTests`: chained points, Shift angle lock, typed length, snapping to wall ends and polygon corners.

View model tests: placing a template creates a booth with the template's size and category and inferred open sides; placing is one undo step; a door drag stays on its host; choosing a placement tool switches to Plan; 3D click selects through the floor ray.

Previews: library panel with the seeded project; every footprint thumbnail; the 3D view at each preset on Annyeong and Beyond.
* * *
## Design gaps and defaults

| Gap | Default |
| --- | --- |
| There is no Hi-Fi for the library or the 3D editor views | Library in the existing inspector panel style; 3D in the dark palette with light floor, matching the canvas |
| CROWD's Eye is a low orbit, not a walk | Eye is a visitor's view at 1.6 m with arrow-key walking; a low orbit is what Front already gives |
| Editing in 3D | Not in this round; inspector fields work in 3D, dragging does not |
| Category tint strength on booths in 3D | Fascia and counter front in the category color, panels neutral |
| Doors on a hall outer edge | Allowed, as `hallToOutside`; the simulation decides later how outside doors are used |
| Click-to-place keeps the tool active | Yes, as in CROWD; Shift-click places once |
| Shadows | Off in the first round; try after the spike |
* * *
## Out of scope

*   Dragging, rotating, or resizing objects in the 3D views.
*   Mesh ray-casting for picking tall objects by their sides.
*   Windows, multi-storey, ceilings.
*   Imported 3D assets; everything is built from primitives.
*   Crowd agents and heatmaps in 3D (Simulation feature).
*   A layers panel listing every object.
