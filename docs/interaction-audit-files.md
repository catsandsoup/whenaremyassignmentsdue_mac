# Files as academic objects, Mac documents and AI inputs

Research and local code/evidence audit: 15 October 2026. This is a scope and acceptance specification, not an implementation claim. It does not change the deadline view. Counts come from the earlier local read-only Canvas probes, not a new API session. No credentials, student identifiers, private feedback text or filenames are reproduced here.

## The central distinction

A student does not primarily want an `application/pdf` attachment. They want **the brief that tells them what to do**, **the rubric that tells them what good work looks like**, **the exact version they submitted**, or **the lecturer's comments that explain a result**. The UI should name that purpose and keep its assignment, author/source, attempt and date visible. A familiar filename still matters when matching the document to Finder, an email, a group conversation or an AI upload.

A computer has a file reference (remote ID, URL, metadata), a byte sequence (possibly absent locally), a uniform type/MIME and extension, and perhaps a derived text representation. An AI may receive only copied text, an uploaded binary, a screenshot, a local file exposed by its client, or an explicitly authorized tool result. These are different capabilities. Having a file URL or a SwiftData record does not mean the PDF bytes are downloaded or that an AI can read it.

Keep these layers distinct:

1. **Academic object:** course, assignment, document role, lecturer/student provenance, submission attempt and relevant version.
2. **Remote reference:** Canvas file ID, display/original name, source association, content type, size and update date; a download/preview URL is transport, not stable identity.
3. **Local original:** validated bytes in managed storage, hash, actual size, completed-download state. One byte object may serve several separate academic references.
4. **User-owned export:** a named copy in Downloads or another chosen folder; subsequent user edits are independent of the managed original.
5. **Derived representation:** copied rubric/feedback text, PDF extracted text, OCR, thumbnails and AI summaries. Preserve source and scope; a derivative must never silently replace the original.

## What is actually known

| Evidence class | Confirmed observation | Boundary |
| --- | --- | --- |
| Assignments and own submissions | 27 own submission records across four enrolled academic subjects | A record is not necessarily a submitted file or a released grade. |
| Current submitted files | 11 current file references: 5 PDFs, 5 DOCX, 1 MP4 | Per-course references are 1, 2, 4 and 4. This is not a full course-material inventory. |
| Submission history | 33 history/attempt records containing 17 attachment references | These include current attempts and repeated references. Do not add 17 to the 11 current files. Historical references are not proof of 17 downloadable revisions. |
| Feedback | Four comment records; three PDF attachment references with distinct file IDs | The three downloaded PDFs have only two distinct content hashes. Preserve all three assignment/comment associations. |
| Structured rubric | Eight definitions; 39 criteria; 147 rating levels, with 146 nonempty long rating descriptions | None of the probed own submissions returned a structured assessed rubric. Definition is not lecturer assessment. SIEN feedback PDFs contain criteria. |
| Assignment instruction links | 26 anchor occurrences in assignment HTML, of which 23 have file-looking Canvas paths; 21 distinct href strings across all anchors | These are syntactic links, not verified files. Different URLs can identify one file, and some links may be unavailable. |
| Module/course resources | Module metadata observed: 15 FINC6001, 12 FINC6017, 14 IBUS6020 and 21 SIEN6007 modules. Selected linked-file metadata was returned despite denied course-wide file lists | Not an exhaustive module-item or file count. A module may contain pages, files, links or external tools. |
| Download proof | Four selected downloads validated previously: three PDFs and one DOCX | These prove only the selected samples. They do not prove blanket downloads, annotated-PDF export, media or external-tool access. |
| Media/annotations | One current submitted MP4 reference. No media-comment object in the four returned comments | Full video downloads, transcripts, Canvas DocViewer annotations, Turnitin feedback, recordings and external tools remain unproven. A `canvadoc_session_url` field is not evidence of a downloadable annotated PDF. |

The deeper probe recorded 63 GETs: 48 success, 12 permission denials and 3 not found. Dedicated rubric endpoints were denied while assignment responses supplied rubric definitions. Feature design must follow accessible resources rather than make an unavailable endpoint a prerequisite. Canvas documents that submission `html_url` and `preview_url` require login; therefore those browser URLs do not meet this app's offline, no-login PDF promise. Its documentation also warns that requesting `read_status` marks submissions read. [Canvas submissions](https://developerdocs.instructure.com/services/canvas/resources/submissions)

## Importance and access frequency

The frequencies below are design hypotheses for student work, not telemetry. Validate them with task-based testing; do not automatically download a course archive because a row is labelled important.

| Document/information class | Student question | Importance and expected frequency | Place and action |
| --- | --- | --- | --- |
| Assignment brief/instructions | What exactly must I deliver? | Critical; repeatedly while planning and drafting | Assignment-specific context; selectable instructions and Copy Instructions when retrieval/presentation is added. Linked brief keeps original name. |
| Marking rubric/criteria | What will be assessed? Have I met every criterion? | Critical; repeated before and during work and before submission | Existing rubric section; complete Copy Rubric includes collapsed ratings and source, without opening every disclosure. |
| Lecturer feedback / feedback PDF | Why this result? What should I improve? | High; intense immediately after release, then during related work | Existing feedback section; Open/Quick Look; copy text comments separately from PDF contents. |
| Current own/group submission | What actually went through? Which version? | High around submission, lower later | Submission disclosure; current attempt/date first; file type and original filename. Group association is not proof every member completed individual requirements. |
| Previous submission attempts | Was my revision received? What changed? | High when resolving a dispute or mismatch, otherwise occasional | Nested history; explicit attempt and date, never merge solely by filename. |
| Supporting workbook/data/slide deck | What inputs or supporting evidence are required? | High when referenced by the brief; repeated while preparing | Assignment-linked resources, separate from feedback; no global downloads dashboard in this scope. |
| Readings/lecture slides | Where is the source for this topic? | Variable; often weekly, occasionally while drafting | Later course-resource scope or existing Canvas; avoid populating feedback with every lecture file. |
| Videos/audio | What was said or demonstrated? | Variable; large files and playback time change the task | Later native playback/Quick Look feasibility; preserve source and duration if known. Do not label a media link available offline without verified bytes. |
| Annotated submission / external marking report | Where exactly did the marker comment? | High after release; occasional later reference | Future capability test; original submission and annotated feedback are distinct roles, even when their page images look identical. |
| Administrative templates/agreements | Which required form must I complete? | Important at a specific milestone; infrequent otherwise | Keep attached to its real academic assignment rather than filtering it out because the filename sounds administrative. Course exclusion is different from excluding a required assessment form. |

## Concrete interaction journeys

Use a consistent file row: native document icon; human role/name; original filename accessible without hover-only dependence; type and useful size; completed/offline state. Put the principal action in the row and secondary actions in its native context menu. Hover help explains an icon, but never hides the only access to an important action. Double-click and Space require a clearly focusable/selectable file target; do not make the entire surrounding reader intercept Space while the user is reading or typing.

| Journey and pointer/keyboard target | Expected result | Failure, lifecycle and test requirement |
| --- | --- | --- |
| Select assignment in sidebar, then point to its document | The reader replaces the preceding assignment's content; relevant file names, source and actions belong only to the selected identity | Switching during a download must not open the preceding file unexpectedly or update a different row. Keep independent download ownership. |
| Click **Quick Look** or focus the file and press Space | System preview of validated local content; close with Space/Escape, then return focus to the originating row | No browser redirect for a cached PDF. On unavailable bytes explain download need while leaving all cached academic text visible. |
| Click **Open** / choose Open from context menu | Open local content in the user's chosen default app | Managed originals are now set to owner-read-only (`0400`) on commit and verified obtain. The default app should offer its native Duplicate/Save workflow when an edit requires a writable document; that OS/app-specific interaction remains unverified. Permissions reduce accidental edits but are not immutable storage: an owner can still change permissions or move files. Test actual default-app behaviour and recovery. |
| Click **Save a Copy…** | Native save dialog with meaningful original name, type and chosen location; overwrite confirmation belongs to the system | Cancel leaves no partial export or UI error; app selection survives the panel. A saved export is not auto-synced back to Canvas. |
| Drag the document icon/name to Finder or an AI client's attachment target | Native file transfer of a named copy; receiver sees a document, not the opaque content-hash filename or remote API link | Export is read-only with respect to the managed original. Cancelled/rejected drag leaves source untouched. Cached transfer works offline. Uncached drag should have an explicit obtain-first path rather than a misleading drag ghost. |
| Right-click / Control-click file | Standard context menu: Open, Quick Look, Save a Copy…, Share as appropriate | Context menu acts on the clicked file, not a previously selected one. Keyboard menu invocation and VoiceOver expose equivalent names. |
| Choose **Show in Finder** | Current context-menu action reveals the cached original, including its opaque hash filename | This is implemented, with a remaining usability risk: the name is not meaningful and a user can move/delete the file. Read-only file permissions do not prevent a directory owner from moving it. Prefer revealing a tracked user-owned export in a future document-library design; export destinations are not tracked today. |
| Choose **Share…** | System share UI for the local Transferable copy | User chooses recipient/app. No automatic academic upload, no token-bearing URL in a share item. Apps offered vary by system. |
| Select text and Command-C, or **Copy Rubric/Feedback** | Selected text copies normally; complete-copy action includes full academic scope and provenance regardless of collapsed display | Structured text is not PDF transcription. If rubric exists only inside a PDF, state that limitation and offer the original file. Do not silently OCR or invent an assessed mark. |
| Relaunch offline or after key expiry | Previously saved content, rubrics and PDFs remain usable with quiet stale/update warning | Test missing cache bytes separately from expired credentials; neither should replace the whole reader with a connection screen. Never repeat interactive Keychain prompts. |
| Refresh after file changes | Commit a validated new revision before associating it; preserve useful last-known-good bytes on failure | A delayed old download must not overwrite newer metadata. Same hash across references does not erase distinct provenance. |
| Local file moved, missing or corrupt | Row no longer claims it is saved; offer redownload if authorized; retain metadata/text | Hash/size/path validation is infrastructure, not a replacement for an understandable file-specific recovery message. |

Apple's first-party model is a strong baseline: Finder selects a file, Space previews it, Escape/Space dismisses preview, and Open hands it to an app. Preview is for sustained reading and editing; Quick Look is for checking without committing to another app. [Apple's file-preview guidance](https://support.apple.com/guide/mac-help/preview-a-file-mchlgtd_prev01/mac)

## PDF contents and AI usefulness

A visually readable PDF can contain selectable text, raster page images, vector shapes, fonts with unusual encodings, annotations, embedded attachments or forms. Extracted text may omit reading order, table alignment, ticks, highlights, marginal notes or the relationship between a comment and its location. A PDF extension and a successful `PDFDocument` parse do not establish that all academic information is extractable. PDFKit supplies document, search and selection primitives; a separate text-recognition pass is needed when content is an image. [PDFKit](https://developer.apple.com/documentation/pdfkit), [PDFDocument.string](https://developer.apple.com/documentation/pdfkit/pdfdocument/string)

For the current app, `containsRubric` and `containsResult` are heuristic flags from embedded PDF text. They help identify a possible document role; they are not a transcription, assessed rubric or released structured score. Preserve that boundary in copied text and accessibility labels. The existing complete-copy exporter correctly excludes token URLs, raw transport metadata and claims that attachment contents were copied.

A future **Copy Document Text** action should report source filename, assignment, extraction method and page boundaries; distinguish empty text, partial extraction and OCR; preserve the original alongside it. OCR confidence and table/annotation limitations matter for rubrics. Apple Vision supplies on-device recognition, but using its native API does not remove the need to verify reading order and academic accuracy. [Apple text recognition](https://developer.apple.com/documentation/vision/recognizing-text-in-images)

A student often wants to drag the brief, rubric and draft together into an AI client. The first increment should make each existing document and complete structured text easy to transfer, with clear source context. A later explicit **Copy Assignment Context** could combine instructions, rubric and selected feedback, clearly enumerate included/omitted documents and avoid old attempts by default. It should not silently include an entire course or private teammate work. MCP is a separate integration: a structured resource contract and permissions are required; a readable PDF cache does not make an MCP server or grant an agent access automatically. Siri/App Intents are also a separate command surface, not an automatic consequence of using SwiftUI.

## Native implementation boundary and acceptance gates

Current code already has CoreTransferable `FileRepresentation` exporting a named writable copy (`0600`) in a system-managed replacement directory, while managed originals are set read-only (`0400`) on commit/verified obtain. It also has native Quick Look, native Save, Show in Finder for the cached original, local PDF validation, complete feedback/rubric text export, per-revision checks and SwiftData provenance. The parent implementation is running permission/transfer regression tests; this audit does not assert their result or that native Duplicate/Save prompts have been manually verified. Verify actual controls before declaring a new capability complete; source presence alone is not a passed UI journey. The initial scope deliberately does not implement a full file browser, annotation renderer, OCR engine, transcript downloader, Siri integration or MCP server.

Prefer `Transferable`/`FileRepresentation`, `.draggable`, `ShareLink`, `quickLookPreview`, system file dialogs and selection-aware native context menus. Context7's SwiftUI documentation lookup confirmed Transferable export and ShareLink/system file presentation; direct Apple references supply the framework contracts. `FileRepresentation` expresses file transfer without homebuilt drag payloads. [CoreTransferable file representation](https://developer.apple.com/documentation/coretransferable/filerepresentation), [SwiftUI ShareLink](https://developer.apple.com/documentation/swiftui/sharelink), [Quick Look](https://developer.apple.com/documentation/quicklook)

Required file tests: selected-file identity after assignment switch; collapsed full-rubric copy; source-labelled comments versus PDF content; focus/Space/Escape and focus return; Open with alternate default handler; named drag to Finder and an available receiving app; cancelled drag/save/share; duplicate-byte references; changed revision during download; actual missing/corrupt local bytes; keyless/offline restart; long Unicode names; large file limit; native light/dark/increased text with no clipped filename/action; VoiceOver document role/state/action names. No empirical tests were run as part of this document-only audit.

Success is fewer decisions and fewer trips back to Canvas: the student can identify the right academic object, inspect it, reuse it and trust its source while keeping the calm deadline agenda unchanged. More controls, more file types and more AI integrations are not themselves evidence of a better utility.
