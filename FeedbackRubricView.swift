import SwiftUI
import AppKit

struct FeedbackRubricView: View {
    let item: FeedbackItem
    var copied: (String) -> Void = { _ in }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Rubric").feedbackFont(.headline)
                Spacer()
                if FeedbackExport.hasRubric(item) {
                    Button("Copy Rubric", systemImage: "doc.on.doc") {
                        copied(FeedbackClipboard.copy(FeedbackExport.rubric(item), confirmation: "Rubric copied"))
                    }.buttonStyle(.borderless).help("Copy every criterion and rating description, including collapsed sections")
                }
            }
            switch item.rubricState {
            case .document:
                Text("Included in the feedback PDF")
                Text("Criteria and assessor ratings are in the PDF above.").feedbackFont(.subheadline).foregroundStyle(.secondary)
            case .unavailable:
                Text(item.attachments.contains(where: \.isPDF) ? "A rubric may be included in the feedback PDF above." : "A rubric is not available from Canvas for this assignment.").foregroundStyle(.secondary)
            case .criteria, .assessed:
                Text(item.rubricState == .assessed ? "Assessed rubric" : "Marking criteria").feedbackFont(.subheadline).foregroundStyle(.secondary)
                if let type = item.assessmentType, type != "grading" { Text("Assessment type: " + type).feedbackFont(.subheadline) }
                if let attempt = item.assessmentAttempt {
                    Text("Rubric for submission attempt \(attempt)").feedbackFont(.subheadline).foregroundStyle(.secondary)
                }
                ForEach(item.rubric) { criterion in
                    VStack(alignment: .leading, spacing: 10) {
                        DisclosureGroup {
                            VStack(alignment: .leading, spacing: 14) {
                                if !criterion.longDescription.isEmpty { Text(criterion.longDescription) }
                                ForEach(criterion.ratings) { rating in
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(alignment: .firstTextBaseline) {
                                            Text(rating.description).feedbackFont(.subheadline, weight: .semibold)
                                            Spacer(minLength: 12)
                                            if !item.hideRubricPoints, let points = rating.points { Text(FeedbackFormat.number(points)).feedbackFont(.subheadline) }
                                        }
                                        Text(rating.longDescription).feedbackFont(.subheadline)
                                    }
                                }
                            }.padding(.top, 12)
                        } label: {
                            HStack(alignment: .firstTextBaseline) {
                                Text(criterion.description).feedbackFont(.body, weight: .semibold)
                                Spacer(minLength: 12)
                                if let score = score(criterion) { Text(score).feedbackFont(.subheadline).fixedSize() }
                            }
                        }.accessibilityLabel(criterion.description + (score(criterion).map { ", " + $0 } ?? ""))
                        if let comment = item.assessments[criterion.id]?.comments, !comment.isEmpty {
                            Text(comment).textSelection(.enabled)
                        }
                    }.padding(.vertical, 10)
                    Divider()
                }
                ForEach(item.assessments.keys.filter { id in !item.rubric.contains { $0.id == id } }.sorted(), id: \.self) { id in
                    VStack(alignment: .leading) {
                        Text("Additional criterion feedback").feedbackFont(.subheadline, weight: .semibold)
                        if let comment = item.assessments[id]?.comments { Text(comment).textSelection(.enabled) }
                    }
                }
            }
        }
    }
    private func score(_ criterion: FeedbackCriterion) -> String? {
        guard !item.hideRubricPoints else { return nil }
        if let awarded = item.assessments[criterion.id]?.points {
            return FeedbackFormat.number(awarded) + (criterion.points.map { "/" + FeedbackFormat.number($0) } ?? "")
        }
        return criterion.points.map { "Up to " + FeedbackFormat.number($0) }
    }

}
