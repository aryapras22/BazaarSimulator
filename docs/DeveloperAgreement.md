# Developer Agreement

# Developer Agreement
> This document defines the team's agreed workflows for branching, pull requests, naming conventions, commit messages and code quality. Every contributor follows these rules to keep the codebase clean and collaborative. The technical rules (layers, file and function limits, tests, reusable components) are explained in `Architecture.md`. This page says which of them block a merge.

## Branching strategy

We use three long-lived branches and short-lived working branches.

| Branch | Purpose | Deploys to |
| ---| ---| --- |
| `main` | Stable, release-ready code | External TestFlight, final submission and demo builds |
| `test` | Integration testing | Internal TestFlight |
| `dev` | Active development | None |

Nobody commits directly to `dev`, `test` or `main`. Every change arrives through a pull request.
### Working branches

*   Create one feature branch per ClickUp task.
*   Naming format: `<type>/<short-description>` in lowercase with hyphens. The type says what the branch is for.

| Branch prefix | When to use | Example |
| ---| ---| --- |
| `feature/` | New functionality or user-facing change | `feature/floor-plan-reading`, `feature/crowd-simulation` |
| `fix/` | A bug fix | `fix/empty-floor-plan-crash` |
| `refactor/` | Restructuring with no behavior change | `refactor/split-simulation-view-model` |
| `chore/` | Tooling, config, dependencies or other non-code work | `chore/add-swiftlint-config` |
| `docs/` | Documentation only | `docs/update-architecture-engine-protocol` |
| `tests/` | Adding or updating tests with no production change | `tests/visitor-mix-edge-cases` |
| `hotfix/` | Urgent fix for a build already given to external testers | `hotfix/crash-on-launch` |

*   Branch off from `dev` and merge back into `dev`. The exception is `hotfix/`: branch off from `main`, open the PR into `main`, then merge `main` back into `dev`.
*   Use `tests/`, not `test/`. Git cannot keep a branch named `test` and a branch named `test/something` at the same time.

### Git flow

```bash
feature/floor-plan-reading ──→ dev ──→ test ──→ main
feature/crowd-simulation   ──↗
```

## Pull request rules

### Before opening a PR

1. Pull the latest `dev` into your local copy.
2. Rebase your commits on top of `dev`. Do not merge `dev` into your feature branch.
3. Build the app, fix every SwiftLint error, and run the fast test plan. All of it passes locally before you push.

```bash
git checkout dev
git pull origin dev
git checkout feature/your-feature
git rebase dev
git push --force-with-lease origin feature/your-feature
```

Resolve all conflicts during the rebase before opening a PR. Never push a branch with unresolved conflicts. After a rebase, push with `--force-with-lease`, never plain `--force`.

### PR description format

Every pull request has three sections: What and how, Testing, and Checklist.

#### What and how

Describe what was implemented and which frameworks, services, models or patterns were used. Break it down by component.
If a linter warning is left in the code, say in one sentence why the code is fine as it is.

#### Testing

List the manual steps taken to verify the feature works, based on the acceptance criteria in the ClickUp task. List the automated tests you added. New logic comes with unit tests. A bug fix comes with a regression test that failed before the fix.
#### Checklist
- [ ] Builds with no SwiftLint errors
- [ ] Fast test plan passes
- [ ] New logic has tests, and a bug fix has a regression test
- [ ] No layer rule is broken (see Code quality rules)
- [ ] New shared components have previews and use design tokens
- [ ] The ClickUp task is linked

### Example PR description

**What and how**

Implemented floor plan import and reading with a vision language model.

*   `PDFImportService`: renders the PDF page to an image and extracts the legend text.
*   A reader backend behind `FloorPlanReaderProtocol`: sends the image and text to the model and returns an `ExtractedVenue` draft (walls, doors, gates, booths).
*   `VenueImportViewModel`: manages the import, loading and error states, and exposes the draft to the view.
*   `ExtractedVenueEditor`: lets the user edit, delete and confirm each detected object before the mapper converts the draft to a `Venue` in metres.

**Testing**

*   Import a sample floor plan and verify the detected objects appear on the venue canvas.
*   Delete a wrongly detected object and confirm it is removed from the venue.
*   Import an empty or unreadable file and confirm the app shows an error instead of crashing.
*   Added `VenueMapperTests`: pixels convert to metres, and a missing scale asks for calibration.

**Checklist**
- [x] Builds with no SwiftLint errors
- [x] Fast test plan passes
- [x] New logic has tests, and a bug fix has a regression test
- [x] No layer rule is broken
- [x] New shared components have previews and use design tokens
- [x] The ClickUp task is linked

### Review and merge
*   At least one teammate reviews every PR before it is merged into `dev`.
*   The author does not merge their own PR without a review.
*   Review comments name the smell and the fix, for example "Data Clump, suggest a parameter object".
*   A linter error or a failing test blocks the merge. A linter warning needs a fix or one sentence in the PR explaining why the code is fine.
## Code quality rules
These rules summarize `Architecture.md`. When the two disagree, fix the disagreement in the same PR.
### Layer rules
1. Views only talk to their own ViewModel. They never call a service, repository or the engine directly.
2. ViewModels use services, repositories, the engine and `ProjectSession` through protocols. They never reference another feature's ViewModel.
3. The simulation engine imports Foundation and `simd` only. Never SwiftUI, AppKit or SwiftData.
4. Domain types are plain `Sendable` structs. SwiftData `@Model` classes never reach the engine. A repository maps between them.
5. Services and the engine are injected through `init`, not created inside ViewModels.
6. Feature A never imports Feature B. Logic that two features need goes in `Core/`.
7. `Core/DesignSystem` imports SwiftUI only. It never imports Domain or a feature.
8. Only one floor plan reader model is loaded at a time. Load it lazily and unload it after extraction.
### Size limits
The limits are the SwiftLint defaults, written out in `.swiftlint.yml` at the repository root.

| Measure | Warning | Error |
| ---| ---| --- |
| Line length | 120 characters | 200 |
| Function body | 50 lines | 100 |
| Type body | 250 lines | 350 |
| File length | 400 lines | 1000 |
| Cyclomatic complexity | 10 | 20 |
| Parameters per function or initializer | 5 | 8 |

A warning means stop and look for a second concern. An error blocks the merge. Do not shave lines to get under a limit. Split the code by concern instead.
### Tests
*   Test behavior through the public interface, not implementation details.
*   One behavior per test, laid out as Arrange, Act, Assert.
*   Tests are fast, isolated and repeatable. No shared mutable state, no real network, no real model calls in the fast plan.
*   The engine takes a seed and a fixed step, so engine tests are deterministic. Never use `Date()` or the system random generator inside the engine.
*   Tag slow tests (`.slow`, `.model`) so they stay out of the fast plan.
*   Fix or delete a flaky test quickly.
### Reusable components
*   Components take values, not models. Actions are closures, editable state is a `Binding`.
*   No hard-coded colors, spacing or radii. Use design tokens.
*   Every shared component has `#Preview`s for the normal case, long text, empty value, dark mode and disabled state.
*   Extract a component when a second feature needs it, not before.
## Definition of done
A ClickUp task moves to done when all of these are true:
*   The acceptance criteria in the task are met and checked by hand.
*   The PR is reviewed and merged into `dev`.
*   Tests for the new logic exist and pass.
*   The linter shows no errors.
*   `Architecture.md` or this agreement is updated if the change altered a rule or a structure they describe.
## Naming conventions

| Element | Convention | Example |
| ---| ---| --- |
| Files and folders | `UpperCamelCase` | `FloorPlanView.swift`, `ViewComponents/` |
| Variables | `lowerCamelCase` | `venueName`, `isLoading` |
| Functions | `lowerCamelCase` | `loadFloorPlan()`, `startSimulation()` |
| Classes, structs and enums | `UpperCamelCase` | `SimulationEngine`, `Persona` |
| Protocols | `UpperCamelCase` with `Protocol` suffix | `FloorPlanReaderProtocol` |
| Views | Feature name plus `View` | `VenueEditorView` |
| ViewModels | Feature name plus `ViewModel` | `VenueEditorViewModel` |
| Test suites | Type name plus `Tests`, in a file with the same name | `VisitorMixTests.swift` |
| Test display names | A sentence about the behavior | `@Test("Egress empties the venue")` |
| Reusable components | Named by purpose, not appearance | `MetricTile`, not `BlueBox` |
| Branches | `<type>/<short-description>` in lowercase with hyphens | `feature/crowd-simulation` |

## Commit messages

Use the [Conventional Commits](https://www.conventionalcommits.org/) format:

```gherkin
<type>: <short description>
```

| Prefix | When to use | Example |
| ---| ---| --- |
| `feat:` | A new feature or user-facing functionality | `feat: add floor plan reading view` |
| `fix:` | A bug fix | `fix: resolve crash on empty floor plan` |
| `refactor:` | Code restructuring with no behavior change | `refactor: extract queue metrics into MetricsCollector` |
| `chore:` | Tooling, config or non-code changes | `chore: update .gitignore for Xcode user data` |
| `test:` | Adding or updating tests | `test: add unit tests for VisitorMix` |
| `docs:` | Changes to documentation only | `docs: update [Architecture.md](http://Architecture.md) engine protocol` |

Keep the description under 72 characters. If more context is needed, add a blank line followed by a body paragraph.
*   One logical change per commit.
*   A commit that changes behavior includes its tests.