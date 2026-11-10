# Layout Editor: Interaction Modelled on CROWD

> Plan to bring the editing model and screen layout of CROWD (github.com/devYRPauli/crowd, MIT, read at `4fec198`, 30 Sep 2026) to the Layout editor. CROWD is TypeScript and three.js, so nothing is copied; its structure is ported to SwiftUI and AppKit. It follows `ArchitectureGuide.md` and `DeveloperAgreement.md`. Findings about our code come from reading it, not from running the app.

## Decisions already made

| Question | Decision |
| ---| --- |
| What to take | The editing structure (tools, snapping, undo) and the screen layout |
| Look | Keep the dark Hi-Fi tokens. Take CROWD's structure, not its light theme |
| Order | Pointer behaviour first, then the tool structure, snapping, undo, and the screen layout, one slice at a time. The editor keeps working between slices |
| One camera for 2D and 3D | Deferred. It is the riskiest part and does not change how editing feels |
| Right-click | Keeps the context menu. CROWD uses the right button to orbit, but our menu is the only canvas route to Rotate, Duplicate, and Delete today |
| Option while dragging | Stays "move without snapping". CROWD uses Alt to duplicate; ours keeps its current meaning |
| Multi-selection | Booths only, because `GroupSelection` and the group inspector are built for booths |

## How CROWD's editor works

```
App (top bar / tool rail / side panel / stage / inspector / playback bar)
  → ToolRail                     one button per tool, one-key shortcut
  → Viewport                     left button → active tool; right, middle, wheel, Space-drag → camera
    → ToolController             routes events to the active tool, builds a ToolContext
      → Tool (Select, Wall, Room, Door, Furniture, Zone…)
        → ctx.snap               candidates from the plan, tolerance in screen pixels
        → ctx.setDraft           preview shapes and labels, no document change
        → ctx.apply(mutate, label, coalesceKey)
          → editorStore.apply    the only place the document changes
            → history.commit     same coalesceKey merges a gesture into one undo step
  → InspectorPanel               edits through the same apply()
```

Each pointer event carries the floor point, screen point, buttons, modifiers, the object under the pointer, and metres per pixel. The select tool turns a press into a gesture: a press on an object becomes "maybe drag" and only becomes a move after 4 px, so a click stays a click. Shift-click toggles, a press on empty floor starts a marquee, Shift during a move locks one axis, arrows nudge by the grid (Shift for 1 m), and Escape cancels.

## Where our editor stands

- `LayoutCanvasView` uses one `DragGesture(minimumDistance: 0)`. A press on a movable object starts a drag at once, and `handleDragEnded` returns on the drag branch, so a click on a movable object appears never to reach `handleClick`. If so, Shift-click and double-click on booths only work through other paths. This needs confirming in the running app before slice 1 starts.
- A left drag on empty floor pans. There is no marquee, no Space-drag pan, and no middle-button pan.
- Modifiers are read from `NSEvent.modifierFlags` when an event is handled, not passed in with it.
- `nudgeSelected(by:)` exists and is tested but no key calls it.
- Snapping reach is in metres (`PlacementResolver`: 1.2 m to a wall, 0.6 m to a booth, 0.25 m grid), so it changes with zoom.
- `LayoutEditHistory` records inverse edits with no coalescing.
- The inspector floats over the canvas (340 pt). The tool choice is in the toolbar, with two primary tools.

## Slice 1: pointer and select gestures

1. `SelectGesture` in `Features/LayoutEditor/ViewModel/`: pure helpers for the 4 pt drag threshold, axis lock (keep the larger component of a delta), and the booths a marquee rectangle touches. Unit tests for each.
2. Click or drag: `LayoutCanvasView+Interactions` starts an object drag only past the threshold. Below it the press is a click and goes to `handleClick`. Resize handles still start at once.
3. Marquee: a drag from empty floor draws a dashed rectangle (`CanvasDragState`, `CanvasSceneRenderer`) and on release selects the booths it touches through a new `selectBooths(_:)` on the view model, with a `PendingNavigationAction.selectBooths` case so unsaved inspector edits still ask first. Shift adds to the current selection.
4. Pan: Space-drag (via `onKeyPress(.space, phases:)`) and middle-drag (an `.otherMouseDragged` monitor next to the scroll monitor in `CanvasScrollCatcher`). Two-finger scroll keeps panning, pinch and Cmd-scroll keep zooming. Left drag on empty floor no longer pans.
5. Shift during a move locks one axis. Arrow keys call `nudgeSelected(by:)` with the grid step, Shift for 1 m.

Tests: `SelectGestureTests`, and view model tests for `selectBooths` with and without unsaved changes.

## Slice 2: pointer event and tool structure

1. `CanvasPointerEvent`: world point, view point, button, modifiers, hit object, points per metre. Built once in `LayoutCanvasView` and the only thing tools receive.
2. `EditorToolHandling` protocol with press, move, release, double-click, key, and cancel. `SelectTool`, `WallTool`, `PlaceTool`, `DoorTool`, and `BlockedAreaTool` each own their gesture state, which today is spread over `@State` in the canvas and view model extensions.
3. The view model routes events to the active tool and gives it a context with `apply`, preview, and selection calls. Tools never reach the session or the view.

Tests: each tool driven by synthetic `CanvasPointerEvent`s, with no view and no `NSEvent`.

## Slice 3: snapping in screen points

1. `Snapper`: candidates from wall endpoints, wall faces, booth edges and centres, alignment with nearby objects, and the grid. The closest within 10 pt wins, in that priority order. Returns the point, the kind, and guide lines.
2. The canvas draws the guides. Option suspends snapping for one move.
3. `PlacementResolver` and wall drawing use `Snapper` in place of their metre reaches.

Tests: priority order, the tolerance holding at two zoom levels, Option off.

## Slice 4: one undo step per gesture

1. `LayoutEditHistory.record(_:coalesceKey:)`: a `.replace` with the same key as the last entry merges into it. Releasing the pointer seals the step.
2. A drag commits as it moves under one key, and a run of arrow presses on one selection is one step, keyed by the selection.

Tests: merge, seal, undo after a merged run returns to the state before the gesture.

## Slice 5: screen layout

1. A top bar with the project and layout name, undo and redo, view presets, and the Floor Plan and Flow tabs.
2. A tool rail on the left with one-key shortcuts shown in tooltips: V select, W wall, D door, B booth from the library, X blocked area, Space held to pan.
3. A side panel for the library and booth groups, collapsible.
4. A fixed inspector column on the right in place of the floating panel. `excludedTrailingWidth` goes away because the canvas no longer sits under it.
5. A hint strip at the bottom left with the active tool's instruction.
6. Update `ArchitectureGuide.md` (macOS specifics, Components the Hi-Fi already needs) in the same change.

Tests: none for layout itself; previews for the rail, side panel, and inspector column.

## Out of scope

One camera for 2D and 3D, Option-drag to duplicate, a rotate handle, typed lengths on the canvas, and CROWD's room detection from walls. The 17 test failures already on this branch (validator and editor view model tests) are not part of this plan.

## Risks

- SwiftUI gestures do not report the middle button. Slice 1 relies on an `NSEvent` monitor, the same approach the scroll catcher uses.
- Space is also a likely future play and pause key in the simulation. It is only read while the canvas has focus.
- Slice 2 touches most files in `Features/LayoutEditor/ViewModel/`. Each tool moves in its own commit so the editor stays usable.
- A fixed inspector column departs from the Hi-Fi's floating panel. Slice 5 waits for confirmation of that change.
