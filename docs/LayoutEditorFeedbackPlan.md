# Layout Editor: Feedback Round 1

> Plan for five changes asked for after the tool rail, snapping, and coalesced undo landed (`ae39de9` to `14274fd`). Findings come from reading the code on `feature/project-setup-reading`, not from running the app. It follows `ArchitectureGuide.md` and `DeveloperAgreement.md`.

## Decisions already made

| Question | Decision |
| ---| --- |
| Where the chair count lives | In the table's catalog item (`table-2`, `table-4`), so `LayoutObject` and saved projects keep their shape |
| Default chairs on imported tables | 4, or the count the extractor found around the table when it found any |
| Default open sides | One per booth, the side facing the most open floor |
| Existing layouts | Not rewritten. The new defaults apply to imports, placements, and Reset open sides |

## 1. Tables with 2 or 4 chairs

Rectangular tables show no chairs because `e2c7466` drew chairs only around round tables. The mock data has no chair counts (`beyond-market-layout.json` tables are bare 0.8 m squares), and `table-rect-6ft` has six fixed seat offsets for a 1.83 x 0.76 m top, which do not fit other sizes.

1. `TableChairs` in `Core/Domain/`: given a table placement and a count of 2 or 4, returns chair placements just outside the table edges. Two chairs sit on the two long sides (opposite sides for a square). Four chairs take one per side. Unit tests for both counts, a square, a long table, and a rotated table.
2. Catalog items `table-2` ("Table for 2") and `table-4` ("Table for 4"), rectangular and freely resizable. `table-4` becomes `defaultItemID(for: .table)` and the catalog ID the mock mapper sets. `table-rect-6ft` stays as it is.
3. 2D: `SeatingRenderer` draws the chairs from `TableChairs` for these two items. 3D: `ObjectShapes` adds a chair box per position.
4. Inspector: a Chairs control (2 or 4) on tables, which swaps the catalog ID through the existing edit path so it can be undone.
5. Extractor: expose `chairs` on `PlanItem` (the seat layer already counts chairs around each table), carry it through `DetectedItem`, and map 1 or 2 chairs to `table-2` and 3 or more to `table-4`.

## 2. Clicking a booth asks to save

Root cause: `InspectorDraft.init` fills `heightM` with a default (2.4 m for a booth) when the object has none, and `applied(to:)` always writes `updated.heightM = heightM`. A booth with `heightM == nil` therefore differs from its own draft the moment it is selected, `hasUnsavedInspectorChanges` is true, and the next click raises the save prompt. The test "Selecting an imported booth leaves Save disabled" catches this and already fails on this branch.

1. `applied(to:)` leaves `heightM` nil when the original is nil and the draft still holds the default height.
2. Run the 17 tests that already fail on this branch afterwards. Some of them ("Save is disabled until the draft changes", "Redo with unsaved changes asks first") may share this cause. Fix only those that do, and list the rest.

## 3. One open side per booth by default

`OpenSideInference.infer` returns every side whose 0.3 m strip is clear, so a booth in an aisle gets two or more open sides.

1. `OpenSideInference.defaultSide(for:in:)`: among the sides `infer` finds open, picks the one with the most clear floor in front of it, probing outward in 0.5 m steps up to 3 m. Ties go in `OpenSides.ordered` order. A booth with no open side gets none.
2. Imports (`MockLayoutMapper`, `ExtractedLayoutMapper`), placement (`PlaceTool`, the library paths), Reset open sides, and the group reset use `defaultSide`. `infer` stays for the open-side warnings.

Tests: an aisle booth with two clear sides gets the wider one, a corner booth gets one side, a boxed-in booth gets none.

## 4. Edit and Delete per layout in setup

Today Continue opens the editor on the first layout. The plan rows in setup already have a three-dots menu with Delete and a disabled Edit (`PlanFileRow`, `onEdit` never passed in `ProjectSetupView`).

1. `ProjectSetupViewModel.editLayout(fileID:)`: writes the draft the same way Continue does, sets the active layout to that file's layout (layout IDs equal file IDs for both mappers), and asks the router to open the editor.
2. `ProjectSetupView` passes `onEdit` for finished floor plan rows. Edit is enabled only when the row is done.
3. Continue no longer opens the editor. Its destination depends on open question 1.

Tests: `editLayout` writes the draft and selects the right layout. Edit is unavailable on a row that is still reading.

## 5. Doors and blocked areas in the library

The catalog already holds Door, Double door, the other door items, and Blocked area under Structure, and `startPlacing` already handles them. The tool rail also has separate Door (D) and Blocked Area (X) buttons.

1. Remove Door and Blocked Area from `ToolRail`. Placing either starts from the library. The D and X shortcuts open the library filtered to Structure.
2. Check that Structure appears in the library chips and that a door picked there places on a wall the same way the rail tool did.

Tests: none beyond the existing door and blocked area placement tests; a preview of the rail.

## Order

2 first (smallest, unblocks clicking around), then 3, 5, 1, and 4. Each numbered task is one commit.

## Open questions

1. Where Continue goes once it no longer opens the editor. The project overview screen (`Features/ProjectOverview`) is empty today.
2. Whether "on the libraries" in item 5 means removing the rail buttons, or only making sure doors and blocked areas are visible in the library. The code already lists them.
