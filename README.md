# Assignment Dates for macOS

A small SwiftUI menu bar app that reads actual Canvas assignment due dates for active academic student enrolments.

## Requirements

- Apple Silicon Mac running macOS 27.
- Xcode with the macOS 27 SDK to build.
- A valid Canvas API access token.

## Build and run

```sh
./test.sh
./build.sh
open 'dist/Assignment Dates.app'
```

Click the calendar icon to see the agenda. Settings contains **Update API key** and **Launch at login**. The app uses the system appearance, standard SwiftUI text styles, and system controls. It has no browser login flow.

To choose another build output folder:

```sh
ASSIGNMENT_DATES_OUTPUT_DIR=/absolute/output/folder ./build.sh
```

## Canvas behaviour

- Uses bearer authentication directly with the Canvas API.
- Refreshes every 30 minutes, after the Mac wakes, and when the agenda opens after five minutes.
- Includes active student enrolments with an academic unit code consisting of four letters followed by four digits; excludes concluded courses and expired terms.
- Shows published assignments with the student's effective `due_at`. Opening and closing times are never used as deadlines.
- Groups assignments sharing a due minute, then groups the agenda by Sydney calendar day.
- Uses Sydney time, including daylight saving.
- Retains the last successful snapshot when Canvas or the network is unavailable.
- Saved rows stay visible across restarts and passing dates until a successful refresh updates the timetable. An expired key only adds a small yellow warning; details and key replacement are available by clicking it.
- Treats HTTP 401 as an invalid key. Permission failures, throttling, and server failures retain the cache without a login prompt.

The API key lives in the macOS Keychain. Deadlines, feedback and downloads share one cached read per launch, including a failed read. Keychain UI is disabled in the app. Existing authorised Apple credential-helper access is reused across app rebuilds; background refreshes never repeatedly ask for approval. The cache lives in `~/Library/Application Support/AssignmentDates/Snapshot.json`. Neither is part of this repository. `Seed.json` is an optional local, ignored startup snapshot; a clean build uses the empty `Seed.example.json`.

## Verification

`./test.sh` checks pagination, bearer-only requests, course and term filtering, HTTP error classification, Sydney AEST/AEDT dates, date grouping, and preservation of all submission links. The test fixture is synthetic and contains no real student or course IDs.

For a separate inspection window, launch with `--preview`. This does not force a colour scheme.

## Research and future scope

See [design research](docs/design-research.md) and [Canvas capability scope](docs/canvas-scope.md). Marks, lecturer feedback, rubrics and feedback PDF access are implemented in a separate native window. Broader course downloads and other Canvas features remain future scope.

### Menu bar countdown

The menu bar shows the next future deadline, for example **SIEN6007 in 6d**. On the due date it says **due today**. Calendar days use Sydney time; the label updates every minute without requiring Canvas access. After the exact deadline, the label advances to the next future deadline. If none remain, the calendar icon still opens your saved agenda.

Open **gear → Settings…**, **right-click / Control-click the menu bar label → Settings…**, or press **⌘,** to choose course and countdown, countdown only, or icon only, and optionally show the calendar icon. Settings use native SwiftUI controls and persist between launches. Launch at login and API key updates are also in Settings.


## Marks & Feedback

Open **gear → Marks & Feedback…**, the menu bar right-click menu, or **⌘⇧M**. A native SwiftUI split view groups assignments by enrolled subject. Selection replaces the reader immediately; search runs locally. The deadline agenda retains its existing layout and data source.

The reader shows released structured marks, lecturer comments, feedback attachments, complete rubric criteria/rating descriptions and assessed criterion feedback when Canvas supplies it. PDF-only results stay in the original document; the app does not turn PDF text into a Canvas grade. Identical attachments on different assignments retain their source identities and display a duplicate-source note.

**Open PDF** uses the default Mac PDF app. **Preview** uses native Quick Look; **Save…** uses the native file panel. Feedback PDFs download automatically after a successful refresh, are validated and saved on this Mac, and remain usable without Canvas access. Other comment attachments download on demand. Files over 100 MB are left available in Canvas.

Feedback uses a versioned, local SwiftData store at `~/Library/Application Support/AssignmentDates/Feedback/Feedback.store`. Ordered criteria/ratings have typed relationships; original API payloads remain local for lossless decoding. PDFs live in the adjacent `Files` directory with content hashes. Failed updates retain the last committed marks, comments, rubric and file copies. No automatic login screen replaces saved content. Old course records remain on disk; the default view follows the most recently confirmed academic enrolments.

See the [interaction requirements](docs/marks-feedback-interactions.md) and [verification report](docs/marks-feedback-verification.md). Tests include synthetic data only; real cache data, PDFs and credentials are excluded from this repository.

### Native reader refinements (1.3)

Copy Rubric includes every rating description, even when collapsed. Copy Feedback retains assignment/course context and released-result provenance; selected text remains individually copyable. The assignment list supports native Copy and selection-aware context menus. Criterion titles use native disclosure groups; course headings use collapsible sidebar sections.

Cached PDF icons support dragging named document copies; file context menus offer Quick Look, Open, Save, Show in Finder and Share. Managed originals are read-only, while exported copies are editable. Text Size in the toolbar menu supports 100–200%; View → Larger Text, Smaller Text and Actual Size use ⌘+, ⌘− and ⌘0. These preferences affect the reader, leaving the deadline agenda unchanged.

See the [complete student interaction scope](docs/student-experience-scope.md), [native control comparisons](docs/native-interaction-comparison.md) and [1.3 verification and remaining manual checks](docs/native-reader-verification.md). Siri/App Intents, MCP and a broader course-file library remain researched proposals.

### Assessment Quick Look (1.4)

Select an assessment in the results list and press **Space** to preview its feedback attachments and current submission files. **⌘Y** and the toolbar Quick Look button provide the same action. In search, **Return** or **Down Arrow** selects a result and moves into the list; Space remains ordinary typing while editing the query. Cached documents appear immediately, with additional available documents added to the native Quick Look collection. Closing preview or changing assessments cancels pending work.

**Open in Canvas** opens the selected assessment in the default browser for submission and other Canvas actions. Toolbar actions retain their positions when selection clears, download indicators retain the button's dimensions, and reader sections expose accessibility headings. The app includes its own document/calendar icon. Deadline layout and credential behaviour remain unchanged.

See the [1.4 interaction verification and motion review](docs/interaction-verification-1.4.md). VoiceOver testing was explicitly excluded from this release by the user; real receiving-app drag/drop and frame-level animation profiling are not claimed as passing.
