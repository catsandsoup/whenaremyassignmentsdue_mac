# System integration and award-quality interaction scope

Researched 15 October 2026. This is a design/research scope, not an implementation claim. The existing source has native text selection, PDF Transferable/ShareLink and complete-copy actions; no App Intents or MCP implementation was found in the Swift source audit. Preserve the deadline agenda and cached academic records.

## The useful jobs

| Job and context | Entry point and journey | Native mechanism / proposed result |
| --- | --- | --- |
| “I need the next deadline without changing tasks.” | Menu bar → read next course/date; keyboard or pointer opens agenda if needed. | Existing menu-bar agenda remains primary. A future read-only AppIntent can return the next cached deadline, including exact Sydney date/time and freshness. |
| “I want to open this assignment while using an external display.” | Spotlight or a custom shortcut → choose an unambiguous assignment → bring its reader to the active workspace. | `AppEntity`, entity query and an opening intent. Use stable account/course/assignment identity; direct navigation must select the exact row and replace the reader. Do not open a generic home screen. |
| “I am speaking or typing to Siri.” | Invoke Siri by the system’s available voice/typing mechanism → ask a short question → receive a compact answer or disambiguation. | App Intents expose supported actions. Spoken results must contain the critical date/time themselves, never “see the blue row.” An absent microphone in a Mac mini/external-display setup must not block keyboard/typed access. |
| “I want help understanding this rubric.” | Select text → Copy, or choose Copy Rubric → explicitly paste into the chosen AI app. | Native text selection and clipboard; complete export includes collapsed descriptions, course, assignment and criteria-versus-assessment status. This is useful before any automation integration exists. |
| “I want an AI to examine the feedback document.” | Find human-labelled feedback file → Preview to verify it → drag or Share to a chosen destination. | Quick Look, `Transferable`/`FileRepresentation`, ShareLink. Export actual file bytes, not a private application-support pathname or expired Canvas URL. Keep filename, assignment context and source attribution. |
| “I want repeatable automation.” | Shortcuts → add app action → choose assignment/course → inspect output → compose next action. | Typed AppIntent parameters and output. Start with “Get next deadline”, “Open assignment” and “Get rubric”; a complete rubric can be text/structured output, a document an `IntentFile`. No automatic AI destination. |
| “I want my agent to read selected academic context.” | App settings → intentionally enable local integration → select allowed courses/assignments → connect client → request a resource → inspect/revoke access. | A separately scoped MCP server, not a SwiftUI control or an automatic consequence of Siri support. Begin read-only and local with an explicit allowlist. |

Apple’s [Siri HIG](https://developer.apple.com/design/human-interface-guidelines/siri) recommends prioritizing frequent tasks, familiar terms, relevant content, succinct responses and audio-complete answers. The [Mac accessibility session](https://developer.apple.com/videos/play/wwdc2025/229/) emphasizes keyboard/mouse, VoiceOver and Voice Control together. Every pointer journey therefore needs an equivalent named, focusable action; hover tips must never be the sole instructions.

## Siri, Shortcuts and Ask Siri are different contracts

The system’s **Control-click → Ask Siri** can operate on selected content on supported systems; it is not evidence that Siri can query our SwiftData store. Apple documents the system interaction in [Use Siri on your Apple devices](https://support.apple.com/en-us/105020). Preserve system text services when selecting content; don’t construct a lookalike Ask Siri menu or assume it appears in every SwiftUI context.

For app-specific queries, use [App Intents](https://developer.apple.com/documentation/appintents). `AppEntity` provides identity and discoverable content; `AppIntent` defines the action. Associate the visible assignment using [`appEntityIdentifier` / `appEntityUIElements`](https://developer.apple.com/documentation/appintents/providing-contextual-cues-to-apple-intelligence-and-siri) only after deliberate data-exposure design. Spotlight indexing is a distinct step, not a prerequisite to Copy Rubric.

**Platform caveat:** the current [App Shortcuts HIG](https://developer.apple.com/design/human-interface-guidelines/app-shortcuts) says macOS supports App Intents actions and custom Shortcuts, while App Shortcuts themselves are unsupported. [WWDC25](https://developer.apple.com/videos/play/wwdc2025/260/) describes Mac Shortcuts/Spotlight integration. Build and test actual macOS actions against the installed SDK; do not advertise iPhone-style App Shortcut surfacing solely from generic framework documentation. Supported Siri behavior also depends on device, OS, language and system configuration.

Context7 confirmed that [`AppIntent.authenticationPolicy`](https://developer.apple.com/documentation/appintents/appintent/authenticationpolicy) defaults to `alwaysAllowed`, including a locked device. Decide per intent whether local-device authentication is required before exposing marks or feedback. This is a future intent policy, **not a reason to read Canvas Keychain credentials again**. Queries should read the existing local cache; refresh should be a separate explicit capability and retain the existing silent shared credential behavior.

## Proposed MCP boundary

MCP and Shortcuts are different interfaces. Native Apple features should handle the human workflow; MCP would make a limited data service available to compatible agents. The [MCP resource specification](https://modelcontextprotocol.io/specification/2025-11-25/server/resources) defines URI-addressed context; [tools](https://modelcontextprotocol.io/specification/2025-11-25/server/tools) support callable operations. Neither implies that every course or raw database should be exposed.

Proposed first resources: an allowed assignment summary, complete rubric, lecturer feedback text and an individually allowed feedback document. Return structured provenance: stable assignment identity, course, title, record freshness, source kind, rubric definition/assessment distinction and original document name. Resource identifiers must be opaque app identifiers rather than arbitrary filesystem paths. Retain raw PDFs as originals; extracted text must be identified as derived and may lack scanned text or PDF annotations.

No submission writes, comment posting, credential export, unrestricted filesystem reads or automatic agent sampling. Scope grants to the chosen client and academic records; show the active scope and a revoke control. A connection should not require approving every cached read again after the user has granted that specific scope. The host’s own consent rules still apply. The [MCP trust principles](https://modelcontextprotocol.io/specification/2025-11-25) require informed control and prevent unconsented onward disclosure; protocol support alone cannot enforce this product policy. Offline read-only does not mean content cannot leave the Mac after an external AI client receives it: explain the chosen sharing boundary clearly.

## Priorities and acceptance tests

These are proposed gates; they are not completed test results.

| Priority | Scope | Acceptance gate |
| --- | --- | --- |
| P0 | Complete text/file reuse through native actions | Copy Rubric includes every rating despite collapsed disclosure state; absent assessments remain “criteria”, zero stays zero. Paste into plain-text and AI editors preserves context. Drag/share yields readable PDF bytes when offline. |
| P0 | Accessible human interaction | Keyboard-only user can select assignment, read/copy content, disclose ratings, preview and save. VoiceOver names assignment, disclosure expanded state and file action. Focus returns sensibly after closing a sheet/preview. No hover-only action. |
| P0 | Readability across hardware | At supported larger reading sizes, minimum window and scaled external display: no cropped actions, overlapping columns or horizontal text scrolling. Verify light/dark, Increase Contrast, Reduce Transparency and non-default accent. Test clamshell display connect/disconnect; windows remain reachable. |
| P1 | App Intents proof of viability | Three synthetic actions appear in Shortcuts on the target Mac; a query handles two same-named assignments by course, opens the exact record, and works offline without a credential prompt. Locked-device behavior matches the chosen authentication policy. Test spoken and typed Siri separately; do not infer one from the other. |
| P1 | Explicit Spotlight scope | Only chosen/relevant entities indexed; result opens that assignment. Removed scope/account clears its index entries. No cached mark appears in unrestricted metadata by accident. |
| P2 | MCP prototype | Synthetic fixture server first. Allowed assignment succeeds; another account/course and arbitrary path fail. Revocation immediately blocks new reads. No secret in output/logs. Cached stale data carries freshness. Client knows whether it receives source PDF or derived text. |

## “App of the Year” as a quality bar

App Store Awards and Apple Design Awards are different editorial programs. Apple cites innovation, user experience and design for [App Store Awards](https://www.apple.com/au/newsroom/2025/12/apple-unveils-the-winners-of-the-2025-app-store-awards/); there is no published universal “utility checklist” that guarantees selection. HIG conformance and SwiftUI usage do not confer eligibility or an award.

The [2026 Design Awards](https://developer.apple.com/design/awards/) describe intuitive platform-tailored interaction, inclusivity, innovation and satisfying experiences. Apple’s discussion of Structured (a SwiftUI planner), Moonlitt (a SwiftUI utility) and Guitar Wiz offers relevant comparisons: easy scanning, simple core journeys, approachable onboarding and serious accessibility. These are design lessons, not a requirement to imitate their visuals or evidence that every part of an app uses SwiftUI.

Our measurable interpretation:

- **Utility:** with unfamiliar synthetic coursework, a student locates the next exact deadline within 5 seconds and the relevant rubric within 15 seconds; at least 4 of 5 moderated participants succeed without explanation. These are proposed study thresholds, not Apple requirements.
- **Calm:** participants can distinguish an upcoming deadline, released result and unassessed criterion without interpreting color or a tooltip. No urgency animation or notification exists merely to create engagement.
- **Delight:** complete rubric copy and PDF handoff each take one deliberate action after locating content. Success is confirmed quietly without stealing focus. At least 4 of 5 participants correctly predict disclosure/menu behavior before clicking.
- **Trust:** repeated offline launches and expired-token refresh preserve last-good data; every error leaves an obvious recovery path. Selection changes never display another assignment’s content or launch an old asynchronous PDF action.
- **Polish:** complete keyboard and VoiceOver passes; native control semantics; larger-reading-size/display matrix passes; repeated selection/disclosure/preview cycles have no focus traps or increasing memory trend.

These gates should guide what ships. Additional integrations are worthwhile only if they shorten a demonstrated student task without making the deadline agenda busier.
