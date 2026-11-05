# Layout Editor: Structure and Booths Layers, Easier Walls, 3D Floor

> Plan for six asks: remove the Front and Eye views, edit in two layers (structure first, booths second), make drawing and editing walls easy, let the user add a floor, make the 3D floor white, and give the layers the job the Floor Plan and Flow tabs have today. It replaces the three-layer split in `LayoutEditorLayersPlan.md` and builds on `LayoutEditorCrowdInteractionPlan.md` (tools, snapping, undo, screen layout) and the fixes already landed from `LayoutEditorFeedbackPlan.md` (save prompt, one open side, chairs, library routing, edit per layout). Findings about our code come from reading `feature/project-setup-reading` at `976bed0`, not from running the app. Findings about other products come from the sources listed in the research table.

## Decisions already made

| Question | Decision |
| ---| --- |
| Layers | Two. Structure (walls, doors, blocked areas, floor) comes first. Booths (booths, tables, chairs) comes second |
| Floor Plan and Flow tabs | Replaced by the layers. Door direction moves into the door inspector. Spawn and exit markers and door arrows become a "Show visitor flow" toggle |
| Plan and 3D | Stay as the way you look. Layers are what you edit. They are independent |
| Front and Eye views | Removed, with the walk-through keys that only Eye used |
| Saved data | No change for walls, doors, booths, and layers. The floor is the one open decision (question 1) |
| Look | Dark Hi-Fi tokens stay |

## What is wrong or missing today

### The 3D floor is probably not drawn at all

`TriangleMesh.appendFloorPolygon` decides winding from the sign of a cross product of the first three hall points, then writes the triangles `A, B, C` when the product is positive. Positions are `(x, height, z)` with `z` taken from the plan's `y`. For the points `(0,0)`, `(1,0)`, `(0,1)` the triangle `A, B, C` has a normal pointing down (right-hand rule gives `(0, -1, 0)`). I computed the same test on the first three points of both mock halls (`annyeong-market-layout.json` and `beyond-market-layout.json`): the cross product is positive in both, so both floors are wound to face down. RealityKit culls back faces by default, so from above the floor would not be drawn and the viewer sees the background. The vertex normals say up, which hides the problem from lighting.

This is arithmetic, not a render. My earlier "white floor" fix (`67ecf60`) changed the material to unlit white, which cannot help a face that is culled. That fix was a guess and was wrong about the cause. The hall polygon the extractor mapper builds (top-left, top-right, bottom-right, bottom-left) has the same winding, so imported layouts are affected too.

### Walls are hard to edit

- Each wall segment is a separate rectangle object (`WallDrawing.objects`). Nothing records that two segments meet.
- `Snapper` lets a new wall start on another wall's face, but the two walls stay unconnected. Moving one leaves the other behind.
- A chain can only start where the pointer snaps to an endpoint, a wall face, a booth edge, or the grid. Starting at the middle of an existing wall means starting next to it, not on it.
- There is no way to split a wall, bend it, or drag a corner with its neighbours.
- Segment lengths are shown only for the wall being drawn.
- Corners of two thick walls leave a notch, because each rectangle ends square.

### Tabs and views

- `EditorTab` (floorPlan, flow) is read in about 20 files. Only doors are in Flow.
- `ViewPreset` has plan, threeD, front, and eye. Eye brings `EyePose`, walk keys in `Layout3DView`, and an eye field of view in `CameraRig`.

## Research: making walls easy

| Source | What it shows | What we take |
| ---| --- | --- |
| Coohom ([help](https://www.coohom.com/helpcenter/floor-plan-edit-walls-split,-merge,-and-align)) | A preference splits walls automatically where a new wall crosses an existing one. Splitting at a chosen point by click or typed distance. A wall's connection endpoints cannot be split | Starting or ending on a wall splits it for you. Typed distance to place a node |
| Archilogic ([split a wall](https://help.archilogic.com/knowledge/how-to-split-a-wall)) and SmartDraw ([adjust walls](https://www.smartdraw.com/support/smarthelp/floor%20plans/adjustfloorplan.html)) | A separate Split Wall command: pick it, then click the spot | A midpoint dot on every wall that splits or bends it, so no separate command is needed |
| Sweet Home 3D ([walls guide](https://sbcode.net/sh3d/drawing-walls/), [forum](https://www.sweethome3d.com/support/forum/printthread_thread,7551_printall,yes)) | Walls join only at their ends. Drawing onto an existing wall does not join them, so there is a "Join walls" command. Magnetism snaps angles to 15 degree steps. Double-click ends a chain, and a wall's start and end are edited in a dialog | The weakness to avoid: users need a Join command because joining is not automatic. We join by position and split on contact |
| Revit ([wall joins](https://help.autodesk.com/cloudhelp/2016/ENU/Revit-Model/files/GUID-6B18982C-1FBA-4E5C-AE30-6FAE4022CE35.htm), [joining tips](https://ukcommunity.arkance.world/hc/en-us/articles/24816739749906-Revit-2025-Wall-Joining-Tips)) | Walls that meet are joined automatically, as a butt join by default, and the plan view cleans up the edges between them. A miter option exists. Forum users say mitered corners make endpoint snapping easier | Automatic joins. A miter-style corner drawn without changing the stored rectangles |
| Cities: Skylines ([Paradox road tools](https://paradoxinteractive.com/games/cities-skylines-ii/features/road-tools)) | Roads that cross create intersections automatically. Right-click cancels each build step | Contact makes a junction without a command. Right-click or Escape cancels the chain |
| CROWD (`ToolController`, `selectTool.ts`, read at `4fec198`) | Wall endpoints are handles you drag. Typing a wall length moves its far end. A length can be typed while drawing | Node handles, a Length field in the inspector, typed length while drawing (we already have typed length while drawing) |

Common pattern: the better tools treat a wall as an edge between nodes. A node is where edges meet, and dragging a node moves everything attached to it.

## Wall design

### Nodes are derived, not stored

`WallGraph` is a pure type that reads the wall objects and returns nodes. Two wall ends that lie within 0.05 m are one node. A wall end that lies on another wall's centerline within 0.05 m is a T node. Nothing is added to `LayoutObject`, so saved projects are unchanged. A wall that is drawn onto another wall is split into two real objects at the node, which makes the T explicit in the data.

### Start anywhere on a wall

- With the Wall tool active, hovering a wall shows a dot at the nearest point on its centerline (a new snap kind, `wallBody`, between endpoint and face in priority).
- Clicking starts a chain at that dot. On commit, the host wall is split at the dot in the same batch edit, so undo removes the chain and the split together.
- Ending a chain on a wall does the same. Closing on the first node ends the chain and closes the shape.
- Typing a distance with the pointer over a wall places the dot at that distance from the nearest end of that wall.

### Dots you can see and use

- In the Structure layer with the Wall or Select tool, nodes of walls near the pointer (within 60 pt) and of selected walls show as solid dots. Midpoints of the selected wall show as hollow dots.
- Drag a solid dot: every wall end at that node moves with it, neighbours stretch. Option-drag detaches the dragged wall from the node.
- Drag a hollow dot: the wall bends. It splits at the midpoint and the new node follows the pointer.
- Drag the body of a selected wall: the wall moves sideways and the ends of its neighbours stretch to follow.
- Dots use screen-space hit tolerance (10 pt), the same rule as `Snapper`.

### Measure while you work

- Every segment of a selected wall, and every segment of the chain being drawn, shows its length.
- Return on a selected wall opens its length for typing. The far end moves, the near end stays, and neighbours stretch.
- The inspector gets a Length field for walls.
- Angle steps while drawing: 90 degrees on Shift, as today, and a toggle for 15 degrees.

### Corners

A joined corner is drawn with each end extended by half the other wall's thickness, so thick walls meet cleanly. This is a drawing rule in the 2D renderer and in `PerimeterWalls`/`SceneGeometryBuilder` for 3D. The stored rectangles do not change. A T node needs no extension.

### Doors

Door hosting reads walls by position, so splitting or stretching a wall should leave doors where they are. A unit test covers a door on a wall that is split through the middle of the door's span: the door must stay on whichever half holds its center. While hovering with the Door tool, the distance from the door's edges to the wall's ends is shown.

### Room tool

Drag a rectangle and four connected walls are inserted as one batch. Walls use the catalog item currently selected in the library.

## Floor

The hall polygon is the only floor today, and it comes from the layout, not from anything the user draws.

| Option | What it is | Cost |
| ---| --- | --- |
| A | The Floor tool edits `layout.hall`: add, move, and delete corners | No data change. One hall only. Walls auto-generated from hall edges (`PerimeterWalls`) move with it |
| B | A new `LayoutObjectKind.floor`: a rectangle the user draws, white in 2D and 3D, drawn below everything, counted as walkable | Adds an enum case to saved data, so this needs a decision. Also changes `isPlacementInsideWalkableFloor`, the validator, and the 3D builder |
| C | Detect a floor from each closed loop of connected walls | Uses `WallGraph`. No data change. Fills only closed shapes. Harder to get right with the extractor's loose walls |

Recommend B for adding a white floor on request, with A as a later hall editor. B is also the only option that lets a second room have its own floor.

## Layers

| Layer | Kinds | Tools | Library | Inspector |
| ---| --- | --- | --- | --- |
| Structure | wall, rail, block, pillar, door, closedArea, stage, audienceArea, floor (if B) | Select, Wall, Room, Door (from the library), Area, Floor | Structure items, doors, blocked area, stage | Size, rotation, wall length, door direction and connection |
| Booths | booth, table, fixture | Select, Booth, Row, Fill (from `LayoutEditorLayersPlan.md`) | Booth templates, furniture, decor | Category, open sides, chairs, group editing |

Behaviour, taken from AutoCAD's lock and fade ([Chron](https://smallbusiness.chron.com/difference-between-freezing-layers-turning-layers-off-autocad-32425.html), [Bricsys forum](https://forum.bricsys.com/discussion/comment/34572)):

- Only the active layer can be selected, moved, resized, or deleted. Marquee selects only active-layer objects.
- The other layer draws at 35% opacity with no handles or hover. It still supplies snap candidates, so booths snap to walls.
- Each layer has an eye toggle.
- Switching with unsaved inspector edits asks first, through a `.switchLayer` case in `PendingNavigationAction`.
- Clicking a locked object shows "Walls are locked on this layer" in the hint strip.
- The editor opens on Structure for a new import, so walls and doors are checked first. The extractor reads booths best and walls and doors worst.

### What replaces Flow

- Door direction and connection move to the door inspector in Structure.
- A "Show visitor flow" toggle, available on both layers, draws door arrows and the spawn and exit markers that `MarkerRenderer` shows on the Flow tab today.
- The Flow-only colours in the renderers go away.

### Chairs

Chairs are a property of a table, as they are now (`TableChairs`, catalog IDs for 2 and 4 chairs). The Booths layer adds:

- A Chairs control in the group inspector, so a selection of tables changes together.
- Chairs drawn dimmed on the Structure layer with their table.

Chairs do not become separate objects. Each chair would need an ID, a hit test, and a place in the validator, for no editing the table control does not already give.

## Removing Front and Eye

1. Delete `front` and `eye` from `ViewPreset`, and `EyePose`, the eye branch in `CameraRig`, the walk keys and `onWalk` in `Layout3DView`, and the Front and Eye entries in `ViewPresetPicker`.
2. Keys 3 and 4 no longer switch views. Keys 1 and 2 stay.
3. The picker becomes Plan and 3D.
4. Update `CameraRigTests` and any view model tests that select those presets.

## Phases and commits

Each numbered line is one commit. The editor works after each phase.

0. Independent fixes
   1. Floor winding: choose the index order from the signed area so triangles face +Y for any polygon, with a test using clockwise and counter-clockwise polygons and both mock halls. After this, decide whether the unlit floor material from `67ecf60` should stay (pure white regardless of light) or go back to a lit material.
   2. Remove Front and Eye.
1. Two layers
   1. `EditorLayer` (structure, booths) with the kind mapping and tests; `LayoutObjectKind.layer` replaces `.tab`.
   2. Hit testing and marquee by active layer.
   3. Renderers dim the inactive layer and drop Flow-only styling. The visitor flow toggle replaces the Flow tab.
   4. Layer tabs and eye toggles in the toolbar. Door direction in the door inspector. Remove `EditorTab` and port its tests.
   5. Tool rail and library follow the active layer. Layer shortcuts (Cmd-1, Cmd-2, to be checked against `AppCommands`).
2. Wall graph
   1. `WallGraph`: nodes, neighbours, T nodes, tolerance. Tests for shared ends, T contact, near misses, and a long chain.
   2. `WallEditing`: split at a point, move a node with its neighbours, detach, bend at the midpoint. Each returns a `LayoutEdit.batch`. Tests, including doors staying on their walls.
3. Drawing
   1. `wallBody` snap kind and the hover dot.
   2. Split on start and on end, close on first node, and one undo step for the whole gesture.
   3. Segment lengths while drawing, and typed distance.
   4. Room tool.
4. Editing
   1. Node dots and node drag, with Option to detach.
   2. Midpoint dots and bend.
   3. Wall body drag with neighbour stretch.
   4. Length field in the inspector and Return-to-type.
   5. Corner extension in 2D and 3D.
5. Floor, after question 1
   1. The chosen model, its tool, 2D and 3D rendering, and tests.
6. Booths layer
   1. Chairs control in the group inspector.
   2. Row and Fill, from `LayoutEditorLayersPlan.md` phase 5.
7. Docs
   1. `ArchitectureGuide.md`: the feature table row for the Layout editor, macOS specifics, and the removal of the two tabs and two views. Mark `LayoutEditorLayersPlan.md` as superseded for the layer split.

## Tests

- Floor triangles face up for clockwise and counter-clockwise polygons.
- Every `LayoutObjectKind` belongs to exactly one layer (parameterized over `allCases`).
- `WallGraph` finds shared nodes within tolerance and T nodes on a centerline.
- Splitting keeps the total length and thickness, keeps catalog ID and height, and keeps doors attached.
- Moving a node moves every end at it and nothing else.
- Starting a chain on a wall body splits the host, and undo restores one wall.
- Switching layers with unsaved edits asks first.

## Risks

- Joining by position can join walls that only happen to touch, and the extractor produces many loose segments (115 walls on plan 6). A 0.05 m tolerance is small against the extractor's pixel noise at the assumed scale. A "Join nearby walls" action may be needed for imports, and is not in this plan.
- Splitting creates new objects and changes the count. Selection, the group list, and door hosting must follow the new IDs. Each split keeps the original ID on the first half.
- Dots on every wall would clutter a busy plan, so they appear near the pointer and on selected walls only.
- Removing the tab touches about 20 files. It is split into five commits for that reason.
- If the floor is a new kind (option B), older builds cannot read projects that use it.
- The right-click behaviour from `LayoutEditorLayersPlan.md` still needs a trackpad test before it ships.

## Open questions

1. Floor model: A, B, or C above? Recommend B for a floor the user adds, because it is the only one that gives a second room its own floor. It changes saved data, so I'm waiting for your decision before phase 5.
2. Do stage and audience area belong in Structure? Recommend yes. They are hall features, not booths.
3. Should the Flow tab become the "Show visitor flow" toggle, or be dropped completely? Recommend the toggle, because door arrows and spawn and exit markers are the only way to see flow at a glance, and removing them leaves the simulation's entry and exit points invisible.
