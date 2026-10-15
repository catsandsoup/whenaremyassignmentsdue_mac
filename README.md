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

The API key lives in the macOS Keychain. The cache lives in `~/Library/Application Support/AssignmentDates/Snapshot.json`. Neither is part of this repository. `Seed.json` is an optional local, ignored startup snapshot; a clean build uses the empty `Seed.example.json`.

## Verification

`./test.sh` checks pagination, bearer-only requests, course and term filtering, HTTP error classification, Sydney AEST/AEDT dates, date grouping, and preservation of all submission links. The test fixture is synthetic and contains no real student or course IDs.

For a separate inspection window, launch with `--preview`. This does not force a colour scheme.

## Research and future scope

See [design research](docs/design-research.md) and [Canvas capability scope](docs/canvas-scope.md). Grades, feedback, and downloads are scoped only; they are not implemented.
