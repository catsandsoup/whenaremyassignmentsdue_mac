# Technical guide

Assignment Dates is a native SwiftUI/AppKit menu bar app. The current build targets Apple Silicon and macOS 27, uses University of Sydney Canvas, and groups dates in the Australia/Sydney time zone. Build output is locally ad-hoc signed.

## Build and checks

```sh
./test.sh
./build.sh
./test-windows.sh
```

The window checks require a logged-in Mac session. They run with network refresh disabled and a separate feedback store. They cover opening/reusing windows, native minimisation, Dock restoration, last-window close, Module Files and reading-size menu registration.

Use `ASSIGNMENT_DATES_OUTPUT_DIR=/absolute/path ./build.sh` to choose the deliverable folder. A clean build bundles the empty `Seed.example.json`; an optional, ignored local `Seed.json` supplies a startup snapshot. Never distribute a personal seed unintentionally.

## Canvas access and local data

The base URL is currently `https://canvas.sydney.edu.au`. Requests use bearer authentication and the student's own accessible course data. Academic enrolments are filtered by active student enrolment, academic unit code, course availability and term dates. Published assignments use their effective `due_at`; opening/closing times are not substituted for deadlines.

The saved token remains in macOS Keychain. Deadlines, feedback and downloads use the existing shared cached credential reader, including caching a failed read. Background operations do not replace the token, widen its Keychain permissions or repeatedly request consent.

Local academic records and downloads live beneath `~/Library/Application Support/AssignmentDates/`:

- `Snapshot.json`: last successful deadline snapshot.
- `Feedback/`: versioned SwiftData records and content-addressed attachments.
- `AssignmentMaterials/`: cached assignment requirements and ready material copies.
- `ModuleMaterials/`: module catalogues, page text and original teaching files.

These records, credentials and downloaded documents are not repository content. An unsuccessful refresh preserves usable cached information. Archived academic records can remain stored even when the default view follows current enrolments.

## Collection and export

Assignment materials collect the available brief, full rubric, syllabus, supplied outline link and explicitly linked Canvas pages/files. External sites remain source links. Student work and lecturer feedback are excluded from default requirement bundles and remain separately reusable.

Module collection paginates both modules and module items, follows bounded course-local page references, deduplicates explicit file references in discovery order, and preserves module order. Files hidden from the Files index can still be downloaded when explicitly linked and unlocked; locked resources remain unavailable. The individual-file endpoint is a fallback for explicitly referenced IDs when the course-scoped endpoint denies access or cannot find them.

A shared queue caps requests at four. Up to three module collections can overlap; module item listing, file metadata and file downloads use bounded task groups. Transient failures receive bounded retries. Canvas 429 and rate-limit 403 responses trigger a shared cooldown, honour Retry-After and temporarily reduce parallelism. Ordinary permission failures and invalid credentials are not blindly retried as transient failures. Cancellation propagates through queued and active work.

Original files are validated and cached with content hashes. PDFs must be valid PDFs; unexpected login HTML is rejected. Module HTML teaching files are accepted when the expected metadata identifies them as HTML. The current per-file download limit is 100 MB; automatic assignment collection also has a 300 MB visit budget. Unavailable/oversized resources are explained rather than represented as successfully downloaded files.

Exports copy available materials into a new named Downloads folder with source links and collection notes. Existing export folders are preserved. File transfers provide named copies; managed originals remain protected. Full rubrics include collapsed descriptions and available assessed comments. PDF-only results are retained as source documents, rather than converted into invented structured Canvas grades.

## Verification boundaries

Synthetic checks exercise API scope/pagination, cached-data preservation, error classification, module/page discovery, linked-only and locked files, long/duplicate names, exact export bytes, typed native receivers, queued cancellation, bounded overlap and throttle timing. Real native checks have exercised live fetching, Quick Look, individual saves, per-week/all-module exports and 200% reader/module layouts.

A completed pointer drag to Finder remains unverified because the automation left an unfinished macOS drag session. Receiver-path tests are distinct from a successful pointer gesture. Full VoiceOver traversal, numerical contrast across appearances/Increase Contrast and trackpad usability testing remain open.

## Design references and future scope

See [native interaction comparison](native-interaction-comparison.md), [student experience scope](student-experience-scope.md), [assignment materials](assignment-assist-plan.md) and the [2.0 design research](design-research-2.0.md). Older versioned verification documents record historical behaviour; the README and this guide describe the current interface.

Selected-course onboarding downloads and opt-in hourly/daily/weekly material checks are future scope. Existing deadline updates run every 30 minutes while the menu bar app runs, after wake, and after an agenda open when the last attempt is older than five minutes. Planned material checks must handle sleep/wake and must not imply a quit app can check for updates.
