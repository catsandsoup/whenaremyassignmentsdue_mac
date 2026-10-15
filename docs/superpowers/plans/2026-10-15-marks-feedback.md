# Marks and feedback Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Ship Option 1 with rubrics, local PDF access and SwiftData persistence, preserving deadlines.
**Architecture:** SwiftUI view projects selected immutable feedback records; an actor owns a versioned SwiftData repository. Canvas GET-only client supplies value DTOs and authenticated file downloads; coordinator merges by remote identity. Native window scene reuses one window.
**Tech Stack:** macOS 27, SwiftUI, SwiftData, URLSession, QuickLook, AppKit only for platform integration.
**Spec:** docs/marks-feedback-scope.md and docs/marks-feedback-interactions.md

## Global Constraints

Deadline view/cache unchanged except Marks & Feedback menu command. UI perfected before production backend. Use synthetic public fixtures; no personal evidence in Git. Native light/dark/accent. Preserve committed offline records/files on failure. Scope and interactions accepted by user's implementation request; execute continuously without an extra approval gate.

## Review Focus

- Switch from PDF record to no-PDF record: remove old file/comment/rubric and reset disclosures.
- Hidden/unposted grades, numeric zero and comment-only rubric assessments remain distinct.
- Download redirects may leave Canvas: never forward Authorization to another origin.
- Partial refreshes, cancellation and missing PDF files must not delete saved feedback.
- SwiftData opening and migrations must not silently delete or recreate failed storage.

### Task 1: UI and interaction contract

Files: FeedbackModels.swift, FeedbackView.swift, FeedbackReader.swift, FeedbackDesignFixture.swift, FeedbackChecks.swift; docs as above.
Interface: FeedbackItem values, FeedbackSelection.selectionID, filtered groups; FeedbackWindowView receives FeedbackStore-compatible observable data.
- [ ] Write failing selection-projection tests (contrasting items), grade/rubric state tests and search/selection invariants.
- [ ] Implement value models/selection state and test until green.
- [ ] Build native design-only window with review fixture, use semantic selection and .id(selectedID) reader reset. Compare reference and screenshots via CUA; refine before Task 2.
- [ ] Test actual native selection replacing pane and search/disclosures; inspect light/dark reference screenshots. Commit UI.

### Task 2: Canvas and durable offline storage

Files: FeedbackAPI.swift, FeedbackPersistence.swift, FeedbackStore.swift, FeedbackFiles.swift; tests FeedbackAPIChecks.swift, FeedbackPersistenceChecks.swift.
Interfaces: FeedbackAPI.fetch course outcomes to Sendable values; FeedbackRepository actor load/merge; FeedbackFiles local validated URL; FeedbackStore publishes immutable items/status.
- [ ] Write failing API/error/pagination and SwiftData disk/merge tests; compile/run and observe failures.
- [ ] Implement GET-only course/assignment/submission fetch with own user identity, rubric flags and complete payload preservation. Merge independent course outcomes without erasing failure records.
- [ ] Implement disk ModelContainer with versioned schema and immutable DTO conversion, explicit save/rollback and content-addressed PDF metadata/files. Validate PDF bytes; handle redirects and missing files. Separate models never cross actors.
- [ ] Test 401/403/429/500/malformed/partial refresh, posted zero versus nil, all rubrics, file failure and duplicate provenance, disk reopen and persistence save failures. Commit backend.

### Task 3: Integrate, native verification, install and publish

Files: AssignmentDates.swift (scene/menu only), MenuBarController.swift, build.sh, test.sh, README.md.
- [ ] Connect production store to window; add one entry to existing menu actions and context menu. Add native open/save/preview actions and keyboard shortcuts. Keep deadline body untouched.
- [ ] Run full existing and new tests. Perform live own-account download into separate SwiftData store. Verify real feedback and rubric inventory, cached PDFs, offline/expired-key restart.
- [ ] CUA light/dark screenshots; verify selection, no stale reader, search/empty state, criterion descriptions, PDF open/Quick Look/Save cancellation, close/reopen, deadline unchanged. Record executed checks and limitations.
- [ ] Whole-diff review and fixes; rerun meaningful tests. Build signed bundle/zip, install verified build, restart normal mode. Commit and push main with lease; verify remote and clean checkout.
