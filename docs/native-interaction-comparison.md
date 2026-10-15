# Native interaction controls — research and implementation decisions

Reviewed 15 October 2026 using Context7's official Apple SwiftUI documentation, Apple HIG/support and public app source.

## Controls are semantic, not interchangeable arrows

| Intent | Native component | Behaviour in this app |
| --- | --- | --- |
| Reveal related information in place | `DisclosureGroup` | Rubric criterion heading expands its definition and rating levels. The score remains visible. Assessor comments remain visible when collapsed. Submission details are a separate, named disclosure. |
| Expand a sidebar category | `Section(isExpanded:)` inside `.sidebar` List | macOS supplies the indicator, expanded state, hit handling and accessibility. Collapsing a selected subject clears its reader. |
| Execute a command | `Menu`, `Button`, `ShareLink` | Copy, file actions and secondary reading commands. Primary Open PDF and Copy Rubric stay directly discoverable. |
| Choose one stored setting | `Picker` with menu style | Use for mutually exclusive preferences. A disclosure triangle is not a substitute for a value selector. |
| Operate on a clicked object | Selection-aware `contextMenu` | Right-click acts on the targeted assignment or attachment, regardless of another row's selection. |

The prior rubric repeated a second “Rating descriptions” trigger beneath every heading. The revised heading itself is the disclosure label. There is one expansion level per criterion, no hand-drawn indicator, no custom disclosure style and no manual hover/click state machine. Complete-copy exports remain independent of expansion state.

[Apple HIG disclosure controls](https://developer.apple.com/design/human-interface-guidelines/disclosure-controls), [pop-up buttons](https://developer.apple.com/design/human-interface-guidelines/pop-up-buttons), [pull-down buttons](https://developer.apple.com/design/human-interface-guidelines/pull-down-buttons), [SwiftUI Section](https://developer.apple.com/documentation/swiftui/section/init(isexpanded:content:header:)), [sidebar List style](https://developer.apple.com/documentation/swiftui/liststyle/sidebar).

## First-party comparisons

| Reference | Verified pattern | Adopt here |
| --- | --- | --- |
| [Apple Notes](https://support.apple.com/en-ph/guide/notes/apd1955d3b21/mac) | Headings organise long content and collapse their sections. | Make the meaningful criterion heading its disclosure label; avoid a generic second row. Notes' implementation framework is not asserted. |
| [Finder](https://support.apple.com/en-gb/guide/mac-help/mchle9f0a1b2/27/mac/27) and HIG's Finder example | Hierarchical disclosure and native file browsing/preview. | Preserve conventional selection, context actions, Quick Look, file transfer and Finder reveal. Framework internals are not asserted. |
| [Landmarks](https://developer.apple.com/documentation/swiftui/landmarks-building-an-app-with-liquid-glass) | Apple explicitly identifies this Mac/iPad/iPhone sample as SwiftUI, using NavigationSplitView and system toolbar glass. | Structural navigation and native toolbar grouping; retain a calm reading surface. This is the strongest verified SwiftUI implementation reference. |

## Third-party comparisons

| Reference | Source evidence | Lesson and boundary |
| --- | --- | --- |
| [Maccy](https://github.com/p0deje/Maccy), [AppDelegate source](https://github.com/p0deje/Maccy/blob/master/Maccy/AppDelegate.swift), [clipboard source](https://github.com/p0deje/Maccy/blob/master/Maccy/Clipboard.swift) | Public source imports SwiftUI/SwiftData and bridges platform windows/clipboard APIs. | Focused menu-bar workflow and actual pasteboard representations matter. Do not copy its clipboard monitoring or app-specific workarounds into an assignment reader. |
| [Ice](https://github.com/jordanbaird/Ice), [SwiftUI app entry](https://github.com/jordanbaird/Ice/blob/main/Ice/Main/IceApp.swift) | SwiftUI App/scene structure with AppKit delegate; entry point also calls a split-view swizzle. | Useful settings/menu-bar structure. Its source is not an endorsement of swizzling or a reason to bypass standard controls here. |

No app is labelled “perfect SwiftUI” or universally HIG compliant. Visible behaviour, implementation evidence and recommendations are distinguished. No third-party app or code was installed or run for this comparison.

## Code organisation

`FeedbackExport` produces academic text; `FeedbackCopyActions` is a small native pasteboard/action adapter; `FeedbackPDF` defines the native transfer representation; `FeedbackReading` owns text-style metrics and standard commands; the window owns optional selection; the reader owns per-selection file actions; the rubric view owns disclosure presentation. Cache, API and credential code are unchanged.

The standard Copy command remains focus-sensitive. Selected sidebar rows copy assignment feedback; text ranges use native text selection; named Copy Rubric always copies all criteria and ratings. Native fonts preserve their descriptor traits when enlarged, including heading weight. User accent and appearance are left to macOS.
