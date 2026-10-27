# Submitted assignments in the agenda

Submitted assignment titles use SwiftUI strikethrough and retain their existing click targets and primary text colour. The course/time line also says “Submitted”; partial groups say “N of M submitted”. A group title is crossed out only when every member is submitted. Individual menu entries carry a Submitted label.

The deadline request includes the current user's submission in the existing paginated assignment request. A valid submitted timestamp or submitted/pending_review state establishes submission. A grade alone does not: missing work can receive a grade. Explicit unsubmitted state or a resubmission request remains actionable. Missing submission data in older caches remains compatible and is updated on the next successful refresh. The submission association is persisted in the existing offline snapshot. Refresh cadence, countdown selection and saved credentials are unchanged.

References checked through Context7 and official documentation:

- [SwiftUI strikethrough](https://developer.apple.com/documentation/swiftui/text/strikethrough(_:pattern:color:)) supplies the native visual treatment.
- [Apple HIG status](https://developer.apple.com/design/human-interface-guidelines/status) informs visible status feedback, paired here with readable text rather than colour alone.
- [Reminders completed items](https://support.apple.com/en-sg/guide/reminders/remndbeda47c/mac) separates completion from deletion. This agenda keeps submitted work in its existing date position as requested.
- [Canvas assignments](https://developerdocs.instructure.com/services/canvas/resources/assignments) documents `include[]=submission` as the requesting user's current submission.

Verification: synthetic API checks require the submission query association and validate decoding. Model checks cover submitted, pending-review and graded-with-submission states; missing/null associations; missing-work grades; reassignment; mixed and complete groups; and offline encode/decode. Native visual checks used isolated synthetic coursework without credential access: the submitted title visibly displayed a strikethrough and Submitted label, unsubmitted titles retained their normal appearance, and clicking the crossed-out title opened the selected assignment. The installed app successfully refreshed and persisted submission associations using its existing credential reader.
