# Marks and feedback interaction and acceptance contract

## Purpose and jobs to be done

J1 When I want my results, open a focused native window from the menu bar without opening Canvas. J2 Find an assignment by subject/title and immediately know which record I am reading. J3 Read released marks without confusing zero, unavailable, unposted or previous-attempt grades. J4 Read lecturer comments and open the exact attached feedback PDF. J5 Inspect marking criteria before submission and assessed rubric feedback after release, without inventing scores. J6 Confirm submission time, attempt and filenames. J7 Keep results, criteria and downloaded PDFs usable after token expiry and app restart. J8 Save a document to a chosen folder and return to the same assignment. J9 Navigate/search/read using keyboard or assistive technology. J10 Return to the deadline agenda with its content and layout unchanged.

## Interaction mode

A nonmodal, resizable, two-pane document reader. The left native sidebar List owns one optional stable assignment selection. The right reader is a pure projection of that selected record. System accent and inactive selection appearances are supplied by macOS; blue is only the default accent, never hard-coded. Data is read-only in Canvas. Disclosure controls, search and local document actions are the only editing-like operations.

## Functional requirements and observable behaviour

| ID | Trigger | Required visible behaviour and state change |
| --- | --- | --- |
| F01 | Marks & Feedback menu command or keyboard shortcut | Activate/reuse one window, preserve current selection, start an independent background refresh when stale. Deadline popover closes; its data/layout do not change. |
| F02 | Click Progress Presentation 2 | That row becomes the sole accent-highlighted selection. Reader title/course/result/comment/file/rubric/submission all belong to Presentation 2 in the same render. |
| F03 | Click another assignment | Remove previous reader immediately; reset its disclosure, preview URL, file errors and scroll position using selected-record identity. Show new cached data, or a neutral assignment-specific empty/loading state, never the old assignment under the new title. |
| F04 | Prior request finishes after F03 | Merge by account/course/assignment/attempt identity only. No direct network callback may overwrite a selected reader or reselect an old assignment. |
| F05 | Up/Down in list | Native single selection advances; reader follows exactly as F02/F03. Focus remains in list. Tab advances through standard focusable controls. |
| F06 | Reopen window | Restore a valid saved selection; otherwise select the most recent available feedback, then first rubric-bearing record. No arbitrary numeric-index restoration. |
| F07 | Command-F or click search | Focus search. Filter locally by case-insensitive course code and assignment title. Nonmatching selected item is deselected and its reader cleared. Empty query restores list; no matches displays an explicit empty state. |
| F08 | Collapse/expand subject | Hide/reveal its rows. Clear selection if its selected row is hidden. Course headers are never assignment results. |
| F09 | Refresh | Keep cached content and selection visible; show small progress, suppress duplicate refresh; update last-success time only after committed data. Failure gives a warning, never an empty replacement screen. |
| F10 | Released structured grade | Show supplied grade and points, preserve explicit zero/fraction. If not posted, show unavailable; workflow graded alone is not a mark. Previous-attempt label accompanies a grade not matching current submission. |
| F11 | Read comments | Preserve original text, author/time/order, selectable text, related files and metadata. External HTML never executes. No read_status inclusion or mark-read writes. |
| F12 | Feedback PDF row | Friendly display name and exact source filename on demand. Open PDF, Save and per-file state shown. Saved on this Mac only after valid local bytes exist. |
| F13 | Open PDF | Open validated cached file in the system PDF handler; otherwise download using API authentication, show per-file progress, commit valid bytes, then open. Failure stays on this row; do not open a login HTML page as a PDF. |
| F14 | Space on attachment / Preview action | Native Quick Look of selected cached attachment. Selecting another assignment dismisses prior preview. No assumed browser session. |
| F15 | Save | Native save panel prefilled with source filename. Cancel changes nothing; successful export writes a copy and leaves selection/read position unchanged. |
| F16 | Missing local PDF | Do not claim saved. Redownload if authorised; if offline show unavailable download action/details without removing feedback. |
| F17 | Rubric definition | Always fetch via permitted assignment responses; show all criteria in source order, maximum points only if permitted. Expanding criterion reveals every rating and full descriptions, including ranges/fractional points. |
| F18 | Assessed rubric | Join by criterion ID and attempt. Display awarded zero, fractional score and text comments when present. No invented rating selection. Hidden points remain hidden; peer/provisional assessment is not a released teacher grade. Unmatched IDs remain visible as unlinked feedback. |
| F19 | Rubric exists in PDF only | Say rubric may be in the feedback document unless locally verified. Preserve original document and Open PDF. No automatic OCR grades promoted to Canvas marks. |
| F20 | No rubric / denied / malformed refresh | Distinguish absence from update failure. Retain last downloaded definition, with warning if stale. Denied rubric endpoints never block assignment-embedded criteria. |
| F21 | Submission disclosure | Expand own current attempt, history, Sydney timestamp, status and source filenames. Future unsubmitted is not missing. Group membership is not proof of teammate completion. |
| F22 | Same bytes on two assignments | Two distinct source attachment records; storage may deduplicate bytes. Duplicate note identifies source assignment, never copies a PDF mark into another result. |
| F23 | Window close / Command-W | Close this window, leave menu bar app and deadline agenda running. Reopening restores selection. |
| F24 | Warning / Retry | Reveal concise error and retry. Key replacement remains an explicit existing settings action; no automatic login prompt. |
| F25 | Course refresh partly fails | Preserve failed course records and all local documents; successful independent resources may commit. Display partial-update warning. |

## Nonfunctional requirements

N01 Native SwiftUI split/list/toolbar/disclosure/file controls, semantic fonts/colours and system accent; PDF opening, native file panels and menu-bar mouse handling may bridge to AppKit. N02 Initial visual target is Option 1 revised rubric image, 1508x1042 reference pixels; match proportions at fixed native logical size and compare captured pixels. Do not fake native controls with a screenshot. N03 Independently verify light/dark, active/inactive and narrow-window wrapping; content must scroll instead of clip. N04 Accessible names, values, selection and disclosure state; VoiceOver-readable hierarchy; no status solely encoded by colour. N05 Interactive selection and search use local memory/SwiftData and never wait for network. N06 Long text selectable, structured rubrics losslessly preserve descriptions/order/IDs/ranges. N07 Explicit disk-backed local SwiftData versioned schema, stable scoped identities, explicit saves and rollback; no destructive reset on open/migration errors. N08 Managed PDF files outside DB; atomic content writes and checksum, no credentials/signed URLs in logs; scope authentication to Canvas and strip it on cross-origin redirect. N09 Offline/401/403/429/500/malformed data preserve the last committed records; last-success timestamp cannot advance on failure. N10 Actor-isolated persistence; Sendable network/value data cross actor boundaries, no PersistentModel instances. N11 No app data, user work, API keys or downloaded feedback committed to GitHub; public fixtures synthetic. N12 Bound request concurrency and pagination, cancellation/retry, cache validation, avoid duplicate auto-sync; no high-frequency polling. N13 Deadline source/view/cache/tests remain intact apart from one menu action. N14 Native UI tests prove selection replacement, rubric expansion, search empty state, PDF actions, persistence across restart, light/dark screenshots; automation captures plus code tests are evidence, not certification of universal HIG/accessibility compliance.

## Visual and test gates

UI first: render native SwiftUI with synthetic/local read-only review data before production API/persistence wiring. Compare sidebar split, search, section and row spacing, title, file row/actions, comments, rubric and metadata to reference. Record material native/adaptive differences. Only proceed once the reader is coherent and the visual comparison has been inspected.

Backend: test released/nil/zero grades, rubric hide flags, all rating descriptions, async stale-result safety, GET-only API and pagination/error classification, atomic file validation and cross-origin redirects, SwiftData separate-process reopen, resource merge preservation and duplicate provenance. Keep all existing deadline tests green. UI runtime tests exercise F02/F03 with contrasting records (PDF and no PDF) so stale attachment/comment/rubric leakage is observable.

Sources: [Apple split views](https://developer.apple.com/design/human-interface-guidelines/split-views), [SwiftUI identity](https://developer.apple.com/documentation/swiftui/view/id(_:)), [NavigationSplitView](https://developer.apple.com/documentation/swiftui/navigationsplitview), [SwiftData ModelContext](https://developer.apple.com/documentation/swiftdata/modelcontext), [Canvas submissions](https://developerdocs.instructure.com/services/canvas/resources/submissions).
