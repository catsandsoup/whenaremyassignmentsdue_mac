import Foundation
import SwiftData

// A lossless value snapshot is paired with typed, ordered rubric relationships.
// This keeps unsupported Canvas fields while making criteria/rating identity explicit.
enum FeedbackSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [Record.self, Criterion.self, Rating.self, Checkpoint.self] }
    @Model final class Record {
        @Attribute(.unique) var key: String
        var userID: Int
        var courseID: Int
        var assignmentID: Int
        var course: String
        var title: String
        var checkedAt: String
        var payload: Data
        @Relationship(deleteRule: .cascade) var criteria: [Criterion] = []
        init(_ value: FeedbackItem, payload: Data) {
            key = value.id; userID = value.userID; courseID = value.courseID; assignmentID = value.assignmentID
            course = value.course; title = value.title; checkedAt = value.checkedAt; self.payload = payload
        }
    }
    @Model final class Criterion {
        @Attribute(.unique) var key: String
        var remoteID: String
        var position: Int
        var text: String
        var longDescription: String
        var maximum: Double?
        var usesRange: Bool
        @Relationship(deleteRule: .cascade) var ratings: [Rating] = []
        init(key: String, value: FeedbackCriterion, position: Int) {
            self.key = key; remoteID = value.id; self.position = position; text = value.description
            longDescription = value.longDescription; maximum = value.points; usesRange = value.usesRange
        }
        var value: FeedbackCriterion {
            FeedbackCriterion(id: remoteID, description: text, longDescription: longDescription, points: maximum, usesRange: usesRange, ratings: ratings.sorted { $0.position < $1.position }.map(\.value))
        }
    }
    @Model final class Rating {
        @Attribute(.unique) var key: String
        var remoteID: String
        var position: Int
        var text: String
        var longDescription: String
        var points: Double?
        init(key: String, value: FeedbackRating, position: Int) {
            self.key = key; remoteID = value.id; self.position = position; text = value.description; longDescription = value.longDescription; points = value.points
        }
        var value: FeedbackRating { FeedbackRating(id: remoteID, description: text, longDescription: longDescription, points: points) }
    }
    @Model final class Checkpoint {
        @Attribute(.unique) var key: String
        var userID: Int
        var checkedAt: String
        var courseIDs: String
        init(userID: Int, checkedAt: String, courseIDs: [Int]) { key = "active-account"; self.userID = userID; self.checkedAt = checkedAt; self.courseIDs = courseIDs.map(String.init).joined(separator: ",") }
    }
}
enum FeedbackMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [FeedbackSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
@ModelActor actor FeedbackRepository {
    typealias Record = FeedbackSchemaV1.Record
    typealias Criterion = FeedbackSchemaV1.Criterion
    typealias Rating = FeedbackSchemaV1.Rating
    typealias Checkpoint = FeedbackSchemaV1.Checkpoint
    static func open(directory: URL, allowsSave: Bool = true) throws -> FeedbackRepository {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let schema = Schema(versionedSchema: FeedbackSchemaV1.self)
        let configuration = ModelConfiguration(schema: schema, url: directory.appendingPathComponent("Feedback.store"), allowsSave: allowsSave, cloudKitDatabase: .none)
        // Never catch this by deleting a store. Failed migrations/opening remain recoverable.
        let container = try ModelContainer(for: schema, migrationPlan: FeedbackMigrationPlan.self, configurations: [configuration])
        return FeedbackRepository(modelContainer: container)
    }
    func load() throws -> [FeedbackItem] {
        let checkpoint = try modelContext.fetch(FetchDescriptor<Checkpoint>()).first
        let active = checkpoint?.userID
        let courses = Set((checkpoint?.courseIDs ?? "").split(separator: ",").compactMap { Int($0) })
        return try modelContext.fetch(FetchDescriptor<Record>()).filter { (active == nil || $0.userID == active) && (courses.isEmpty || courses.contains($0.courseID)) }.map { record in
            var value = try JSONDecoder().decode(FeedbackItem.self, from: record.payload)
            value.rubric = record.criteria.sorted { $0.position < $1.position }.map(\.value)
            return value
        }
    }
    func lastCheckedAt() throws -> String? { try modelContext.fetch(FetchDescriptor<Checkpoint>()).first?.checkedAt }
    func merge(_ input: FeedbackFetchResult) throws -> [FeedbackItem] {
        modelContext.autosaveEnabled = false
        do {
            let records = try modelContext.fetch(FetchDescriptor<Record>())
            var byKey = Dictionary(uniqueKeysWithValues: records.map { ($0.key, $0) })
            var wrote = false
            for course in input.courses {
                for incoming in course.items {
                    guard incoming.userID == input.userID, incoming.courseID == course.courseID else { throw FeedbackError.invalidData }
                    let old = try byKey[incoming.id].map { try JSONDecoder().decode(FeedbackItem.self, from: $0.payload) }
                    let value = Self.preservingDownloads(incoming, old: old)
                    let data = try JSONEncoder().encode(value)
                    let record = byKey[value.id] ?? Record(value, payload: data)
                    if byKey[value.id] == nil { modelContext.insert(record); byKey[value.id] = record }
                    record.title = value.title; record.course = value.course; record.checkedAt = value.checkedAt; record.payload = data
                    synchronizeRubric(value.rubric, record: record)
                    wrote = true
                }
            }
            if wrote {
                if let checkpoint = try modelContext.fetch(FetchDescriptor<Checkpoint>()).first {
                    checkpoint.userID = input.userID
                    checkpoint.courseIDs = input.courses.map { String($0.courseID) }.joined(separator: ",")
                    if input.courses.allSatisfy({ $0.warning == nil }) { checkpoint.checkedAt = input.checkedAt }
                } else { modelContext.insert(Checkpoint(userID: input.userID, checkedAt: input.checkedAt, courseIDs: input.courses.map(\.courseID))) }
            }
            try modelContext.save()
            return try load()
        } catch { modelContext.rollback(); throw error }
    }
    func updateAttachment(itemID: String, file: FeedbackAttachment, expected: FeedbackAttachment) throws -> [FeedbackItem] {
        modelContext.autosaveEnabled = false
        do {
            guard let record = try modelContext.fetch(FetchDescriptor<Record>()).first(where: { $0.key == itemID }) else { throw FeedbackError.invalidData }
            var value = try JSONDecoder().decode(FeedbackItem.self, from: record.payload)
            guard let current = value.previewFiles.first(where: { $0.id == file.id }), current.sameRevision(as: expected) else { throw FeedbackError.unavailable("This attachment changed while downloading. Select it again to open the current version.") }
            for c in value.comments.indices {
                for f in value.comments[c].attachments.indices where value.comments[c].attachments[f].id == file.id {
                    value.comments[c].attachments[f].localPath = file.localPath
                    value.comments[c].attachments[f].contentHash = file.contentHash
                    value.comments[c].attachments[f].cachedSize = file.cachedSize
                    value.comments[c].attachments[f].containsRubric = file.containsRubric
                    value.comments[c].attachments[f].containsResult = file.containsResult
                }
            }
            for index in value.submissionFiles.indices where value.submissionFiles[index].id == file.id {
                value.submissionFiles[index] = file
            }
            record.payload = try JSONEncoder().encode(value)
            try modelContext.save()
            return try load()
        } catch { modelContext.rollback(); throw error }
    }
    private func synchronizeRubric(_ source: [FeedbackCriterion], record: Record) {
        let old = Dictionary(uniqueKeysWithValues: record.criteria.map { ($0.remoteID, $0) })
        var updated: [Criterion] = []
        for (position, value) in source.enumerated() {
            let key = record.key + ":criterion:" + value.id
            let criterion = old[value.id] ?? Criterion(key: key, value: value, position: position)
            if old[value.id] == nil { modelContext.insert(criterion) }
            criterion.position = position; criterion.text = value.description; criterion.longDescription = value.longDescription; criterion.maximum = value.points; criterion.usesRange = value.usesRange
            let oldRatings = Dictionary(uniqueKeysWithValues: criterion.ratings.map { ($0.remoteID, $0) })
            var ratings: [Rating] = []
            for (index, value) in value.ratings.enumerated() {
                let rating = oldRatings[value.id] ?? Rating(key: key + ":rating:" + value.id, value: value, position: index)
                if oldRatings[value.id] == nil { modelContext.insert(rating) }
                rating.position = index; rating.text = value.description; rating.longDescription = value.longDescription; rating.points = value.points; ratings.append(rating)
            }
            for old in criterion.ratings where !ratings.contains(where: { $0.key == old.key }) { modelContext.delete(old) }
            criterion.ratings = ratings; updated.append(criterion)
        }
        for old in record.criteria where !updated.contains(where: { $0.key == old.key }) { modelContext.delete(old) }
        record.criteria = updated
    }
    static func preservingDownloads(_ incoming: FeedbackItem, old: FeedbackItem?) -> FeedbackItem {
        guard let old else { return incoming }
        var result = incoming
        if !incoming.submissionComplete {
            result = old
            result.rubric = incoming.rubric; result.rubricTitle = incoming.rubricTitle
            result.hideRubricPoints = incoming.hideRubricPoints; result.hideRubricTotal = incoming.hideRubricTotal
            result.sourceAssignment = incoming.sourceAssignment
        }
        for c in result.comments.indices {
            for f in result.comments[c].attachments.indices {
                let new = result.comments[c].attachments[f]
                if let previous = old.attachments.first(where: { $0.sameRevision(as: new) }) {
                    result.comments[c].attachments[f].cachedSize = previous.cachedSize
                    result.comments[c].attachments[f].localPath = previous.localPath
                    result.comments[c].attachments[f].contentHash = previous.contentHash
                    result.comments[c].attachments[f].containsRubric = previous.containsRubric
                    result.comments[c].attachments[f].containsResult = previous.containsResult
                }
            }
        }
        for index in result.submissionFiles.indices {
            let new = result.submissionFiles[index]
            if let previous = old.submissionFiles.first(where: { $0.sameRevision(as: new) }) {
                result.submissionFiles[index].cachedSize = previous.cachedSize
                result.submissionFiles[index].localPath = previous.localPath
                result.submissionFiles[index].contentHash = previous.contentHash
            }
        }
        return result
    }
}
