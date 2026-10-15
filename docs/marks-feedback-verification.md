# Marks & Feedback verification — 15 October 2026

## UI-first acceptance

The approved Option 1 revised rubric mockup was translated to native SwiftUI before API/persistence integration. Captures were reviewed at 1100×760 logical points. The sidebar occupies 30.9% versus 31.2% in the image reference. Search, course sections, reader title/result, attachment actions, comments, rubric and quiet metadata follow the reference hierarchy. Attachment padding was refined after the first review.

Native macOS 27 window controls and toolbar chrome, semantic text styles and system active/inactive selection deliberately remain native. An image-generated mockup is not a platform control specification; this is a close native translation, not a claim that every raster pixel is identical. No fixed accent or forced production appearance is used.

CUA runtime verification covered light and dark appearance, active blue and inactive grey selection, arrows, PDF-to-no-PDF selection replacement, search clearing a hidden selection, criterion rating expansion, submission disclosure resetting, window close/reopen and saved selection. Actual downloaded feedback opened in native Quick Look and in the default Preview app. Save opened the native sheet with the original filename and cancellation returned to the same assignment. Real-data captures are kept outside the public repository.

## API and persistence evidence

A read-only live import used the installed Keychain credential and the production API implementation: four academic subjects, 27 assignments, eight rubric definitions, 39 criteria, 147 rating levels, four comments and three feedback PDF records. All PDFs were downloaded and validated. A separate-process offline probe reopened the production SwiftData store with all records, rubric relationships and local PDF metadata present. Duplicate bytes remain separate attachment records.

The account currently supplies rubric definitions and PDF rubrics; a complete structured assessed rubric was not available for live UI verification. Awarded zero, fractions, hidden points and rating descriptions are covered with synthetic API fixtures. No Canvas writes or mark-read requests were made.

## Automated checks

`./test.sh` passes nine executables:

- Existing deadline grouping/countdown, academic enrolment filtering, bearer pagination and error handling.
- Existing deadline cache survives missing/expired keys, permissions, throttling, server/network/JSON failure, restart and passing due dates.
- Identity-based feedback selection, filter clearing, released zero versus unavailable mark, rubric source states.
- Own-user GET-only mapping; rubric descriptions/ranges/fractions, partial and malformed detail fallback, submission endpoint failure, 401 classification and external-pagination rejection.
- Disk SwiftData reopen, ordered rubric relationships, idempotent merge, failed-course preservation, stale attachment revision rejection and read-only save rollback.
- HTML/PDF validation, atomic content-addressed files, duplicate identity, missing files/path escape and cross-origin authorization stripping.
- Shared credential cache reads once, remembers denial and updates on explicit key replacement. A real credential probe reused the existing key for 51 reads without approval or exposing its value.
- Feedback coordinator missing/expired key, 403/429/500 failure and reopen preserve marks, comments, rubrics and last-success time.

The read-only save test deliberately produces a SwiftData permission diagnostic before confirming rollback; that diagnostic is expected. A fresh review identified partial-resource and async-action races; regression tests and fixes were added before release.

## Limits

No claim of universal HIG or accessibility certification is made. VoiceOver names/selection/disclosure are exposed through native accessibility and inspected through AX, but a full human VoiceOver audit and all custom system accent/accessibility combinations remain untested. Delayed external PDF action cancellation is enforced in code; a deliberately slowed real-server action was not manually induced. The first versioned schema is supplied; future schema changes require migration fixtures before release.


Credential follow-up: repeated approvals were caused by independent Keychain reads combined with changing ad-hoc app identities. Reads now share one locked process cache, with legacy Keychain UI and LA interaction disabled. The existing item's decrypt ACL was inspected without reading its secret and already trusts Apple's stable `/usr/bin/security`; the app uses that helper only when this existing trust and an unlocked keychain are confirmed. It does not widen permissions on reads. This retains the existing Keychain item rather than exporting it to an unprotected file. Apple's [authentication UI guidance](https://developer.apple.com/documentation/security/ksecuseauthenticationuifail) and [designated requirements](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements) explain these behaviours.
