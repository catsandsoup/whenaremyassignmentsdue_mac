# Marks and feedback window scope

Option 1 is the approved visual direction. This scope preserves its two-pane window, course-grouped assignment list, search, reader, attachment actions, and quiet last-update status. Rubric retrieval is a required part of the feature. This document records the preimplementation design and feasibility scope. The resulting implementation and actual test coverage are recorded in [verification](marks-feedback-verification.md).

## Intended outcome

Open results, lecturer feedback and marking criteria without browser navigation or a fresh login. Retain previously downloaded information when the token expires. The deadline popover remains unchanged except for one Marks & Feedback command in its action menu and the status-item context menu.

## Visual contract

The source of truth is the first generated Option 1 image, with the approved two-pane hierarchy. The revised review image adds the rubric section to the existing reader. Reference canvas is 1508 by 1042 pixels. Use the corresponding layout proportions at an initial window size around 1100 by 760 points, with a roughly 340-point sidebar and resizable divider; minimum usable size is to be verified on the target Mac. Pixels and SwiftUI points must not be confused.

- Sidebar: search field; native course section headings and disclosure; assignment title, a short source/status subtitle, optional released mark aligned at the trailing edge. Retain subject sections with unavailable marks, because those assignments can still have useful rubrics. Search filters titles and course codes locally.
- Reader: course label, assignment title, result/source subtitle, feedback and file row, lecturer comments, rubric, collapsed submission details, last successful update.
- Default selection: restore the last selected assignment if it still exists; otherwise select the most recent available feedback. Preserve scroll position while refreshing.
- Each assignment remains a separate data identity. FINC6001 report and video may sit beneath one visual group as in the concept, but expanding/selecting them must expose their distinct rubrics and marks. Equal due dates do not imply one result.
- Course order follows most recent available feedback, with a stable course-code tie break. Within each section use most recent released feedback first, with a stable assignment-ID tie break. Assignments with rubric criteria but no feedback remain reachable below available results.
- Window controls, toolbar, refresh icon, native selection, spacing rhythm, typography hierarchy and restrained colours follow Option 1. No third column, grade dashboard, course totals, unread counters, notifications or extra navigation tabs.

Implement with SwiftUI Window, NavigationSplitView, selectable List and Section, searchable, ToolbarItem, ScrollView, DisclosureGroup, Button, ProgressView and native file actions. Use system semantic font styles and colours. Native material is limited to navigation/chrome; reading surfaces remain comfortable. Preserve the design hierarchy rather than rasterising mock controls. Light/dark, inactive/active windows, increased contrast, reduced transparency and user text sizing necessarily alter native rendering.

“Pixel perfect” is an acceptance target at one agreed window size, appearance, display scale and content state, not a promise of identical pixels across settings. The image is a concept, not proof of native rendering or HIG compliance. Compare actual native screenshots against the reference after implementation, concentrating on geometry, alignment, hierarchy and affordances, then test the adaptive states separately.

## Rubric behaviour

Always retrieve assignment rubric definitions during refresh, whether or not an assignment has a mark. Request the current student's rubric assessment with submission details. Retain rubric settings, original criterion/rating identifiers, order, descriptions, long descriptions, maximum points, fractional points, rating ranges, free-form comment settings, and hide-points/hide-total flags.

The reader's Rubric section has four source-aware states:

1. **Marking criteria**: native vertically stacked criteria showing the criterion title and description, plus maximum points when allowed. Each criterion has a disclosure for all rating levels and full descriptions. This avoids squeezing long text into a wide matrix. No awarded score is invented.
2. **Assessed rubric**: when actually returned for the student's submission, show awarded points and lecturer criterion comments alongside the definition. Include the relevant attempt and assessment type; distinguish teacher grading, peer review and provisional data, never treating all as the released grade. Preserve explicit zero, comments without points, unmatched criterion IDs and score-hidden rubrics.
3. **Rubric in PDF**: preserve and cache the original feedback PDF, show the original document as the authority, and point to the Open PDF action already above. SIEN6007 currently uses this state. Do not convert PDF ticks or extracted numbers into structured Canvas grades automatically.
4. **Rubric not available from Canvas**: a calm explanatory line. Distinguish an explicit absent definition from a fetch failure or a denied endpoint. Keep any last downloaded rubric visible after failed requests.

Never attach a rubric solely by title, list position or matching point total. Scope identities by Canvas host, enrolled user, course, assignment and rubric; criterion/rating IDs may repeat across different rubrics. Preserve original source relationships and submission attempt.

## Marks, comments and submission details

Released structured grades use Canvas's visible score/grade and the assignment's points possible. Missing values stay unavailable, not zero. A graded workflow state alone is not evidence of a released numeric result. Display descriptive grade strings as supplied; do not force every grade into a percentage. Changes to a current submission may leave a prior-attempt grade; expose that distinction.

Keep lecturer comments in their original order with author/time and attachments. Preserve text and a sanitised presentation of any supported rich content; do not execute remote HTML. Long comments are readable and selectable. Rubric data and feedback text are separate sources even when one is absent.

Submission details reveal timestamp in Sydney time, attempt/history, file names, status and Canvas late/missing indicators. Distinguish future unsubmitted, not available and actual missing. A student's effective group submission can be shown; this does not prove individual teammate completion. Keep personal peer-review and AI-log submissions separate from shared group slots.

## PDFs and offline behaviour

The file row retains the friendly name, original filename on demand, file type/size, Open PDF, Save and download state. Open PDF uses the local copy with the macOS file handler; Space can provide native Quick Look. Save exports a copy via the native save panel. No browser login is required for cached content.

Automatically attempt to cache feedback PDFs during refresh so PDF-based rubrics are retained. Metadata becoming available is not proof that the file finished downloading. Only label a file Saved on this Mac after its bytes have been committed and checked. An uncached file cannot be promised available when the key expires.

Use a temporary download, validate the file, calculate a content hash, move the completed file atomically into Application Support, then commit the SwiftData record. Keep existing copies until replacement succeeds. A crash between filesystem and database operations can leave an orphan; reconcile on next launch rather than deleting referenced files. A changed file is a new content revision. Keep distinct attachment records when the same bytes appear on different submissions; deduplicate bytes only. The observed SIEN6007 duplicate must remain attached to its original records with a factual duplicate note.

A failed API request, permission denial, malformed response, expired key or offline launch must not erase saved content. Show a small warning with details on demand and preserve last-successful timestamps. Do not infer deletion from an empty or partial failed refresh; distinguish a successful explicit absence and retain provenance of older downloads.

## SwiftData design

Use an explicit disk-backed ModelContainer with a versioned schema and local-only configuration. SwiftData holds relationships and metadata; PDFs remain managed files on disk. Keychain remains the credential store. The current deadline JSON snapshot stays in place for this first scope; replacing its proven persistence is a separate migration.

Candidate entities: course, assignment, submission attempt, comment, rubric definition/revision, criterion, rating level, assessed criterion, attachment reference and sync checkpoint. All remote identities include the host and user as appropriate. Separate an attachment's submission provenance from its content hash/local file. Store criterion/rating order explicitly because relationship arrays are not an ordering guarantee.

Network tasks decode into Sendable value types. A dedicated model actor owns persistence mutations; views use their main-actor context and Query. Do not move model instances between actors. Validate a refresh before merging; use explicit saves and rollback with per-resource checkpoints. A feedback failure must not invalidate a successful rubric download. Avoid delete-and-recreate sync. Preserve last-known-good revisions and distinguish current data, archived source revisions and unavailable updates.

Supply SchemaMigrationPlan as the schema evolves. Back up before migration; a migration failure must not trigger silent store deletion. Require explicit data validation before retiring an older store. Disk-full, corrupt-store recovery, multi-actor integration and migration from the existing deadline JSON are not proven by the feasibility spike.

## Live API evidence

The deeper student-account probe issued 63 read-only GET requests: 48 HTTP 200, 12 HTTP 403 and 3 HTTP 404 responses. Every own-submission detail was checked. No read_status inclusion or mutation endpoint was used.

| Subject | Rubric definitions | Criteria | Rating levels | Assessed rubric returned |
| --- | ---: | ---: | ---: | --- |
| FINC6001 | 2 | 14 | 66 | No |
| FINC6017 | 3 | 19 | 54 | No |
| IBUS6020 | 3 | 6 | 27 | No |
| SIEN6007 | 0 | 0 | 0 | No; PDF feedback contains criteria |

There are 39 criteria and 147 rating levels, with 146 nonempty long rating descriptions. Fractional points and range-based criteria are present. Course rubric lists and all eight dedicated rubric detail requests returned 403; definitions remain available in the permitted assignment responses. Do not make the denied endpoints a prerequisite for displaying rubrics.

Useful requests:

```text
GET /api/v1/courses/{course}/assignments?include[]=submission&per_page=100
GET /api/v1/courses/{course}/assignments/{assignment}/submissions/self
    ?include[]=rubric_assessment&include[]=full_rubric_assessment
    &include[]=submission_comments&include[]=submission_history
```

The probe also retrieved assignment-group weights, 11 announcements across the four courses and one nonempty course page per subject. Syllabus HTML was empty in every course. Quiz listing returned 404 in three subjects and an empty list in SIEN6007; this does not prove quiz content cannot exist elsewhere. Earlier checks proved selected linked-file downloads despite denied course-wide file lists. None of those additional content categories enters the initial Option 1 interface.

[Canvas rubrics](https://developerdocs.instructure.com/services/canvas/resources/rubrics) and [submissions](https://developerdocs.instructure.com/services/canvas/resources/submissions) document the definitions, assessment types, inclusion parameters and read-status side effect. Enhanced rubric exports are not an assumed student permission. Annotation/media systems and external tools need their own entitlement and endpoint checks; they remain unproven.

## Existing alternatives

| Product | Published capability and useful lesson | Fit for this request |
| --- | --- | --- |
| [Canvas by Instructure](https://apps.apple.com/us/app/canvas-by-instructure/id480883488?platform=mac) | Official grades, course content and offline downloads; the Mac listing says Designed for iPad and supports Apple Silicon Macs. | Strong existing full Canvas client. It does not replace the chosen focused native two-pane design. |
| [Canvas Downloader](https://github.com/BrkBuilds/Canvas-Downloader) | Developer advertises local macOS/Windows backups including grades, rubric assessments, comments and attached files. | Strong candidate for a separate semester archive. Do not rebuild bulk backup or media conversion inside Option 1. Advertised coverage has not been executed against this account. |
| [Canvas Course Downloader](https://github.com/jasp-nerd/canvas-course-downloader) | Browser-session extension advertises assignment rubric definitions, linked files, module structure, personal grades and differentiated student/teacher exports. | Useful manual export alternative. Browser-session dependency does not meet this app's autonomous token-based workflow. Teacher-only rubric exports are not evidence of student access. |

No alternative was installed, authenticated or given the user's token. Published feature claims are comparison evidence, not live-tested compatibility. No third-party code is proposed for reuse.

## Test gates

Completed API checks: all 27 own-submission detail requests; assignment and user identity checks; eight rubric definitions; criterion/rating identifiers and descriptions; fractional/range points; all no-assessment responses; expected rubric permissions; supplementary content response boundaries; GET-only requests with no read-status side effect parameter. The saved API evidence is local to the research directory, outside this public repository.

Completed isolated SwiftData checks: a disk-backed synthetic graph with rubric criteria, ratings and attachment references; nil versus explicit zero mark; separate-process reopen with no API; explicit stable-key merge with no duplicate graph; interrupted transaction plus rollback; local attachment path and separate source references sharing one content file; a V1 to V2 lightweight schema migration in separate processes. The spike uses a synthetic file fixture, not a PDF viewer or production migration. Actor integration has not been tested.

Before declaring implementation complete, verify:

- Native screenshot comparison with the approved reference at one fixed size, plus light/dark and active/inactive states. Verify no content clipping at supported narrow sizes and with long titles and all 147 real rating descriptions.
- Keyboard: arrows select list rows, Tab reaches controls, Command-F searches, Space previews a selected attachment, Command-W closes only this window, and focus returns correctly after native file panels.
- VoiceOver labels for course, assignment, result source, rubric criterion/max/awarded values, expand/collapse, file download state and warning details. Test increased contrast, reduced transparency and text scaling; selection and result source never depend on colour alone.
- All four rubric states; synthetic assessed rubrics with zero, fractional, comments-only, hidden scores, peer-review versus grading types, unknown criteria and previous attempts. The current account supplies no positive structured-assessment fixture.
- End-to-end offline restart with real cached PDFs and rubrics, expired/missing key, 403/429/500, cancellation, malformed JSON, partial courses, interrupted downloads, missing local files, changed attachments, disk-full and failed schema migration. Last-known-good information must remain recoverable.
- Search and selection stability; distinguish group and individual submissions, duplicate attachment provenance and nil/zero/unposted marks.
- Open/Save/Quick Look uses validated local files and native UI, including when browser authentication has expired. No credential travels to an unrelated download origin.
- No changes to Canvas submission/comment/read state, and no regression in the existing deadline and cache tests.

HIG and SwiftData adherence are engineering requirements with verification gates, not a certification furnished by a concept image. The implementation status and remaining verification limits are recorded in the verification report; the original scope gates above are retained for traceability.
