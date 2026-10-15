import Foundation

struct FeedbackRating: Codable, Sendable, Identifiable {
    var id: String
    var description: String
    var longDescription: String
    var points: Double?
}
struct FeedbackCriterion: Codable, Sendable, Identifiable {
    var id: String
    var description: String
    var longDescription: String
    var points: Double?
    var usesRange: Bool
    var ratings: [FeedbackRating]
}
struct FeedbackAssessment: Codable, Sendable {
    var points: Double?
    var comments: String?
    var ratingID: String?
}
struct FeedbackAttachment: Codable, Sendable, Identifiable {
    var id: Int
    var name: String
    var url: String
    var contentType: String
    var size: Int
    var updatedAt: String? = nil
    var cachedSize: Int? = nil
    var localPath: String? = nil
    var contentHash: String? = nil
    var containsRubric = false
    var containsResult = false
    func sameRevision(as other: Self) -> Bool {
        id == other.id && name == other.name && size == other.size && updatedAt == other.updatedAt
        && URL(string: url)?.host == URL(string: other.url)?.host
        && URL(string: url)?.path == URL(string: other.url)?.path
    }
    var isPDF: Bool { contentType == "application/pdf" || name.lowercased().hasSuffix(".pdf") }
}
struct FeedbackComment: Codable, Sendable, Identifiable {
    var id: Int
    var author: String
    var text: String
    var createdAt: String?
    var attachments: [FeedbackAttachment]
}
enum FeedbackRubricState: String { case criteria, assessed, document, unavailable }
struct FeedbackItem: Codable, Sendable, Identifiable {
    var id: String
    var assignmentID: Int
    var courseID: Int
    var userID: Int
    var course: String
    var title: String
    var originalTitle: String
    var pointsPossible: Double?
    var score: Double?
    var grade: String?
    var postedAt: String?
    var submittedAt: String?
    var attempt: Int?
    var workflowState: String
    var late = false
    var missing = false
    var gradeMatchesCurrent = true
    var comments: [FeedbackComment] = []
    var submissionFiles: [FeedbackAttachment] = []
    var rubric: [FeedbackCriterion] = []
    var rubricTitle = "Marking criteria"
    var hideRubricPoints = false
    var hideRubricTotal = false
    var assessments: [String: FeedbackAssessment] = [:]
    var assessmentType: String? = nil
    var assessmentAttempt: Int? = nil
    var history: [FeedbackAttempt] = []
    var checkedAt: String
    var archived = false
    var submissionComplete = true
    var sourceAssignment: Data? = nil
    var sourceSubmission: Data? = nil
    var attachments: [FeedbackAttachment] {
        var seen = Set<Int>()
        return comments.flatMap(\.attachments).filter { seen.insert($0.id).inserted }
    }
    var markLabel: String? {
        guard postedAt != nil else { return nil }
        if let grade, !grade.isEmpty, Double(grade) == nil { return grade }
        guard let score else { return grade }
        return FeedbackFormat.number(score) + (pointsPossible.map { "/" + FeedbackFormat.number($0) } ?? "")
    }
    var rubricState: FeedbackRubricState {
        if !assessments.isEmpty { return .assessed }
        if !rubric.isEmpty { return .criteria }
        if attachments.contains(where: \.containsRubric) { return .document }
        return .unavailable
    }
    var subtitle: String {
        if markLabel != nil { return "Released" }
        if attachments.contains(where: { file in
            guard file.containsResult else { return false }
            if title.hasPrefix("Progress Presentation"),
               let source = file.name.range(of: "[0-9]+(?=of[0-9]+)", options: .regularExpression),
               let selected = title.range(of: "[0-9]+$", options: .regularExpression) {
                return file.name[source] == title[selected]
            }
            return true
        }) { return "Result in PDF" }
        if !attachments.isEmpty { return "Feedback attachment" }
        if !comments.isEmpty { return "Lecturer feedback" }
        return "Mark not available"
    }
    var recentDate: Date { comments.compactMap { $0.createdAt.flatMap(Deadlines.date) }.max() ?? postedAt.flatMap(Deadlines.date) ?? .distantPast }
}
struct FeedbackAttempt: Codable, Sendable, Identifiable {
    var attempt: Int
    var submittedAt: String?
    var state: String
    var files: [FeedbackAttachment]
    var id: Int { attempt }
}
enum FeedbackFormat {
    static func number(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(0...2))) }
    static func time(_ value: String?) -> String { value.flatMap(Deadlines.date).map(Deadlines.label) ?? "Not available" }
    static func groups(_ items: [FeedbackItem]) -> [(String, [FeedbackItem])] {
        Dictionary(grouping: items, by: \.course).map { key, rows in
            (key, rows.sorted { $0.recentDate == $1.recentDate ? $0.assignmentID < $1.assignmentID : $0.recentDate > $1.recentDate })
        }.sorted { a, b in
            let ad = a.1.map(\.recentDate).max() ?? .distantPast, bd = b.1.map(\.recentDate).max() ?? .distantPast
            return ad == bd ? a.0 < b.0 : ad > bd
        }
    }
}
struct FeedbackSelection {
    var selectionID: String?
    var search = ""
    var collapsedCourses = Set<String>()
    func visible(_ items: [FeedbackItem]) -> [FeedbackItem] {
        let term = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return items.filter { !collapsedCourses.contains($0.course) && (term.isEmpty || ($0.course + " " + $0.originalTitle + " " + $0.title).localizedCaseInsensitiveContains(term)) }
    }
    func item(in items: [FeedbackItem]) -> FeedbackItem? { visible(items).first { $0.id == selectionID } }
    mutating func select(_ id: String?, in items: [FeedbackItem]) { selectionID = visible(items).contains { $0.id == id } ? id : nil }
    mutating func reconcile(in items: [FeedbackItem]) { if item(in: items) == nil { selectionID = nil } }
}
