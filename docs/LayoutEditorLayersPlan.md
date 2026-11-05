# Layout Editor: Layers and Build Tools

> Superseded for the layer split by `LayoutEditorStructureAndBoothsPlan.md`, which uses two layers (structure, booths) instead of three. The build behaviour (placement feedback, booth rows and fill, overlays) in this plan still applies.
>
> Plan to replace the Floor Plan and Flow tabs with three editing layers (walls and doors, areas, booths), give each layer its own tools and library, and add the build helpers that make Cities: Skylines easy to build in: live validity feedback, drag-out rows, and fill. It builds on `LayoutEditorCrowdInteractionPlan.md` (tools, snapping, undo, screen layout, all landed) and replaces section 5 of `LayoutEditorFeedbackPlan.md`. Findings about our code come from reading `feature/project-setup-reading` at `ea2239a`, not from running the app. Findings about other products come from the sources listed at the end.

## Decisions already made

| Question | Decision |
| ---| --- |
| Editing order | Walls and doors, then blocked areas, then booths. A suggested order, not a wizard: the user can switch layers at any time |
| Saved data | No change. Layers are view state over `LayoutObjectKind`; `Layout`, `LayoutObject`, and persisted projects keep their shape |
| Flow tab | Goes away. Door direction and connection move into the door inspector in the walls layer |
| Look | Dark Hi-Fi tokens stay. The Hi-Fi's two tabs are replaced, so `ArchitectureGuide.md` changes in the same work |
| Right-click | Context menu stays with the Select tool. Drawing tools use right-click to cancel the current step |

## Research: what to take from other editors

| Source | What it shows | What we take |
| ---| --- | --- |
| AutoCAD layers ([Chron](https://smallbusiness.chron.com/difference-between-freezing-layers-turning-layers-off-autocad-32425.html), [Bricsys forum](https://forum.bricsys.com/discussion/comment/34572), [NVCC CAD 201](https://pressbooks.nvcc.edu/cad201/chapter/layers/)) | A layer can be off (hidden), frozen (hidden and skipped on redraw), or locked. Locked objects stay visible, cannot be edited, and still work as snap targets. A forum thread mentions a "lock and fade" setting that dims locked layers | Active layer is editable. Other layers are visible, dimmed, locked, and still snap targets. Per-layer show and hide. No freeze, because redraw cost is not a problem at this size |
| Floorplanner manual ([2018 manual](https://cdn.floorplanner.com/static/brochures/Floorplanner+editor+manual+version+050718.pdf), [2019 post](https://floorplanner.com/blog/15-01-2019-kicking-off-2019-with-a-streamlined-interface)) | Sidebar modes Build (walls, rooms, doors, windows), Decorate, Furnish. Each mode has its own tools and library. The build mode was later split in two | A mode owns its tools and its library, so the library never lists something you cannot place on the current layer |
| Cities: Skylines road tools ([dev diary 1](https://forum.paradoxplaza.com/forum/threads/cities-skylines-dev-diary-1-roads.802639/page-2), [Paradox road tools](https://paradoxinteractive.com/games/cities-skylines-ii/features/road-tools)) | Straight, curved and freeform modes. A 90 degree snap. In Cities: Skylines II a Grid mode (three clicks set the corner, width and length, with the layout previewed) and a Parallel mode. Right-click cancels each build step | Straight and room (rectangle) wall modes. Booth rows and fill as the grid-mode equivalent. Right-click cancels a step |
| Cities: Skylines snapping ([player guide](https://prodigygamers.com/?p=25789), [Steam thread](https://steamcommunity.com/app/949230/discussions/0/4328601129273074437)) | Separate toggles for snap to existing geometry, to guidelines, to the zone grid, and to 90 degrees | Snap toggles in the hint strip, off by default only for the ones that fight a gesture |
| Cities: Skylines zoning ([dev diary 2](https://admin-forum.paradoxplaza.com/forum/developer-diary/cities-skylines-dev-diary-2-zoning.804803), [SegmentNext](https://segmentnext.com/cities-skylines-2-zoning), [GameSkinny](https://www.gameskinny.com/tips/cities-skylines-2-how-to-dezone-all-zone-types/)) | Roads create zone cells on both sides. The user fills them with Fill (a connected block), Marquee (a dragged rectangle that aligns to the grid), or Paint (one cell). In Cities: Skylines II right-click with a zoning tool erases | Structure produces the slots and the user fills them: rows along walls and aisles, fill for an open region. Right-click erases with a draw tool |
| Cities: Skylines info views ([dev diary 9](https://admin-forum.paradoxplaza.com/forum/developer-diary/cities-skylines-dev-diary-9-info-views.833752/post-18849702), [guide](https://gameplay.tips/guides/cities-skylines-ii-info-views-guide.html)) | Overlays colour the whole map by one measure, such as the busiest roads in red | Overlays for open sides and warnings, later aisle width |
| Placement preview colours | Not documented by any source I could reach. A building that follows the cursor, faces the road and turns red with a reason is from my own memory of the game | Same behaviour, with our own reasons |
| CROWD (`LayersPanel.tsx`, read at `4fec198`) | Its layers panel is an object list with show and hide checkboxes and per-object locks, not an editing layer | Kept as an idea for a later object list. Not part of this plan |

## How our editor is organised today

- `EditorTab` (floorPlan, flow) maps through `LayoutObjectTab` on `LayoutObjectKind.tab`. Only doors are in Flow. `LayoutHitTester` selects only objects whose kind is in the current tab, which is why a door can only be edited after switching tabs.
- The tab is read in about 20 files: the view model and its extensions, the hit tester, `CanvasSceneRenderer` and four renderers, `MarkerRenderer`, the toolbar, `SceneGeometryBuilder`, and five test files.
- `EditorTool` has five cases. `ToolRail` has five buttons (Select, Wall, Door, Library, Blocked Area). The library already lists doors and Blocked area under Structure.
- Tools are classes behind `EditorToolHandling` with a `ToolContext`. `Snapper` already gathers candidates from the whole layout, so a dimmed layer will keep snapping.
- `PlacementCandidate` already has `isValid` and `note`, so a reason can reach the hint strip without a new path.
- There is no room tool and no way to place several booths in one gesture.

## The three layers

| Layer | Kinds | Tools | Library | Inspector |
| ---| --- | --- | --- | --- |
| Walls and doors | wall, door, pillar, rail, block | Select, Wall (V, W), Room (R), Door (D, from the library) | Structure items | Size and rotation. Doors also get direction and connection (today's Flow tab) |
| Areas | closedArea, stage, audienceArea | Select, Area (A, drag a rectangle) | Blocked area, stage, audience | Size, rotation, label |
| Booths | booth, table, fixture | Select, Booth (B), Row, Fill | Booth templates, furniture, decor | Category, open sides, chairs, group editing |

Behaviour:

- Only the active layer can be selected, moved, resized, or deleted. Marquee selects only active-layer objects.
- Other layers draw at 35% opacity with no handles and no hover. They still provide snap candidates.
- Each layer has an eye toggle. A hidden layer is not drawn and gives no snap candidates.
- Spawn and exit markers draw on the walls layer.
- A layer tab shows a count when objects on it have warnings, so a booth overlapping a blocked area is visible from the areas layer.
- Layer switching uses Cmd-1 to Cmd-3. The plain number keys stay as view presets. Cmd-1 to 3 need checking against `AppCommands` before use.
- Switching layers with unsaved inspector edits goes through the existing `PendingNavigationAction` prompt, with a `.switchLayer` case in place of `.switchTab`.

## Build behaviour

### Validity preview

Every placing or drawing tool shows its preview in the accent colour when valid and in the warning colour when not, with the reason in the hint strip.

| Reason | Check | Existing code to reuse |
| ---| --- | --- |
| Outside the hall | Footprint not inside the walkable floor | `LayoutGeometry.isPlacementInsideWalkableFloor` |
| Overlaps a wall or booth | Footprint intersects a blocking object | `LayoutGeometry.intersects`, `LayoutValidator` |
| Blocks a door | Footprint inside a door's reach | `DoorHosting`, `LayoutValidator` |
| Aisle too narrow | Gap to the nearest blocker under the minimum | New, uses the `LayoutValidator` minimum |

A `PlacementProblem` enum carries the reason, and `PlacementCandidate.note` becomes the text for it. Invalid placements stay allowed with a click while Option is held, as free placement is today.

### Walls layer

- Wall tool keeps its chained segments, typed length and angle lock.
- Room tool: drag a rectangle and four walls are inserted as one batch edit, one undo step. It uses `Snapper` for both corners.
- Door tool: the door snaps to a wall and shows its swing and width while hovering, as `DoorHosting` already does. It starts from the library, not from a rail button.
- Right-click or Escape cancels the current chain or rectangle.

### Areas layer

- Area tool replaces the Blocked Area rail button. Drag a rectangle snapped to the grid and to walls. Option frees the snap.
- Right-click on an area with the Area tool erases it.

### Booths layer

- Booth tool places one booth with the existing `PlaceTool`, faced toward the nearest aisle.
- Row tool: press on a wall face or an aisle line, drag along it, and a row of booths of the chosen size is previewed along the drag, one per slot, each tinted by validity. Release inserts the valid ones as one batch. Each booth has a single open side facing away from the wall, which also gives the default of one open side (feedback item 3).
- Fill tool: drag a rectangle and booths are packed in back-to-back double rows with an aisle between rows. Aisle width starts at the validator minimum and is shown while dragging. Invalid slots are skipped and the count is shown ("14 booths, 2 skipped").
- A `BoothRowPlanner` in `ViewModel/` is a pure function from a line or rectangle, booth size, aisle width, and layout to placements and skipped slots. Tools only call it and show the result.
- Dragging across existing booths with the Select tool and a category chosen in the inspector changes their category in one edit. This is the Replace idea, and it reuses the group editing that exists.

### Right-click

`.contextMenu` currently catches every right-click on the canvas. The menu will show only for the Select tool. Whether an empty `.contextMenu` still swallows the click is not known, so the cancel and erase path is built on an `NSEvent` monitor for `rightMouseDown`, the way `CanvasScrollCatcher` handles scroll.

### Overlays

A picker in the toolbar chooses None, Warnings, or Open sides. Warnings colours objects with a `LayoutValidator` issue. Open sides colours each booth edge by whether it is open or blocked, from `blockedSidesByBoothID`, which already exists. Choosing a layer turns on its matching overlay (booths layer: Open sides) and the user can switch it off. An aisle-width heat map needs a distance field over the floor and is left for later.

## Phases and commits

Each numbered line is one commit. The editor works after each phase.

1. Layer model
   1. `EditorLayer` enum with the kind mapping, titles, and tests. `LayoutObjectKind.layer` replaces `LayoutObjectKind.tab`.
   2. Hit testing and marquee filter by active layer. Update `LayoutHitTesterTests`.
   3. Renderers dim non-active layers and drop Flow-only styling. Spawn and exit markers draw on the walls layer.
   4. Layer tabs and eye toggles replace the Floor Plan and Flow segmented control. Door direction and connection move into the door inspector. Remove `EditorTab` and the Flow tab tests, or port them.
2. Tools and library per layer
   1. `ToolRail` shows the tools of the active layer. Door and Blocked Area buttons are removed. D opens the library on doors, A starts the Area tool.
   2. The library lists only items of the active layer. Hint strip text per tool is updated.
   3. Layer shortcuts and the `.switchLayer` pending action.
3. Placement feedback
   1. `PlacementProblem` and the reasons in the table above, with unit tests for each.
   2. Preview tint and hint strip text for place, door, wall, and area tools.
4. Walls and areas tools
   1. Room tool with batch insert and tests.
   2. Area tool rename and right-click erase.
   3. Right-click monitor, and the context menu limited to the Select tool.
5. Booth building
   1. `BoothRowPlanner` with tests (row length, rotation, skipped slots, double rows, aisle width).
   2. Row tool.
   3. Fill tool.
   4. One open side per booth for rows and fill (feedback item 3, also covers the single-booth path).
6. Overlays
   1. Overlay picker with Warnings and Open sides.
7. Docs
   1. `ArchitectureGuide.md`: Layout editor row of the feature table, macOS specifics, tool list. Update the Hi-Fi note about the two tabs.

## Tests

- `EditorLayerTests`: every `LayoutObjectKind` belongs to exactly one layer (parameterized over `allCases`).
- Hit testing returns nothing for objects outside the active layer, and snapping still finds their edges.
- `PlacementProblem` reasons, one per behaviour.
- `BoothRowPlanner`: slots along a line, a rotated wall, a run that does not divide evenly, blocked slots skipped, double rows share a back.
- Room tool inserts four walls as one undo step.
- View model: switching layers with unsaved edits asks first.

## Order against the other open plans

1. `LayoutEditorFeedbackPlan.md` item 2 (the save prompt on clicking a booth) first. It affects every click while testing the layers.
2. Phases 1 and 2 of this plan.
3. Feedback items 1 (chairs), 3 (open sides, folded into phase 5), and 4 (edit per layout) are independent and can go at any point.
4. Phases 3 to 6.

## Risks

- Phase 1 touches about 20 files. The mapping is mechanical, but it is the largest single change. Splitting it in four commits keeps each reviewable.
- Dimmed locked layers can confuse a user who clicks a wall while on the booths layer and sees nothing happen. The hint strip should say "Walls are locked on this layer" when a click lands on a locked object.
- Fill can place hundreds of booths. The batch edit must stay one undo step, and the preview must stay under one frame, so the planner runs on the pointer move without validating against every object more than once.
- The right-click monitor may fight the system context menu on a trackpad two-finger click. Test on a trackpad before relying on it.
- Cmd-1 to Cmd-3 may collide with an existing menu command.

## Open questions

1. Is the grouping right: stage and audience with blocked areas, and rails, blocks, and pillars with walls? Recommend: yes. They are areas that change where people walk and structure that stays fixed.
2. Should the booth tools come before the layer split? Recommend: no. Rows and fill need the library and tool rail to be per layer, or the new tools have nowhere to live.
3. Which overlay matters most first? Recommend: Open sides, because the data exists and it shows the result of the one-open-side default.
