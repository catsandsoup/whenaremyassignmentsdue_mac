import SwiftUI
import AppKit
import QuickLook

struct AssignmentMaterialsView: View {
    let item: FeedbackItem
    @ObservedObject var store: FeedbackStore
    @State private var plan: AssignmentAssistPlan?
    @State private var materials: [AssignmentMaterial] = []
    @State private var fetching = true
    @State private var saving = false
    @State private var progress = "Fetching from Canvas…"
    @State private var notice = ""
    @State private var refreshID = 0
    @State private var preview: URL?
    @State private var saveTask: Task<Void, Never>?
    private var exportMaterials: [AssignmentMaterial] {
        materials.filter { !(item.rubricState == .document && $0.id == "02-Marking-rubric.txt" && $0.url == nil) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack { title; Spacer(); saveAllButton }
                VStack(alignment: .leading, spacing: 10) { title; saveAllButton }
            }
            ViewThatFits(in: .horizontal) {
                HStack { status; Spacer(); refreshButton }
                VStack(alignment: .leading, spacing: 8) { status; refreshButton }
            }
            ForEach(exportMaterials.filter { $0.url != nil }) { material in
                if let url = material.url {
                    NativeFileRow(name: material.name, detail: "Ready to drag · From Canvas", url: url, exportName: url.lastPathComponent,
                        preview: { preview = url }, save: { saveOne(url) }, open: { NSWorkspace.shared.open(url) })
                }
            }
            if let outline = plan.flatMap({ AssignmentAssistContent.cleanURL($0.outlineURL) }) {
                Link(destination: outline) { Label("Unit outline", systemImage: "link").frame(minHeight: 28) }
                    .draggable(outline).help("Open or drag the unit outline link")
            }
            let unavailable = exportMaterials.filter { $0.url == nil }
            if !unavailable.isEmpty || !(plan?.warnings.isEmpty ?? true) || (!fetching && plan?.outlineURL.isEmpty == true) {
                DisclosureGroup("Material availability") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(unavailable) { material in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(material.name + ": " + material.note)
                                if let source = material.source { Link("Open in Canvas", destination: source).frame(minHeight: 28) }
                            }
                        }
                        if !fetching && plan?.outlineURL.isEmpty == true { Text("Canvas hasn't supplied a unit outline link.") }
                        if let plan, !plan.warnings.isEmpty { Text(plan.warnings.joined(separator: "\n\n")) }
                    }.feedbackFont(.callout).textSelection(.enabled).padding(.top, 8)
                }.feedbackFont(.body)
            }
            Text("Drag a file into your AI or Finder. Saving materials excludes your submissions and feedback.")
                .feedbackFont(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if !notice.isEmpty { Text(notice).feedbackFont(.callout).textSelection(.enabled) }
        }
        .disclosureGroupStyle(ComfortableDisclosureStyle())
        .quickLookPreview($preview)
        .task(id: item.checkedAt + ":" + String(refreshID)) { await fetch() }
        .onDisappear { saveTask?.cancel() }
    }
    private var title: some View { Text("Assignment materials").feedbackFont(.headline).accessibilityAddTraits(.isHeader) }
    private var status: some View {
        HStack(spacing: 8) {
            if fetching { ProgressView().controlSize(.small) }
            Text(fetching ? progress : "\(exportMaterials.filter { $0.url != nil }.count) files ready · From Canvas")
                .feedbackFont(.callout).foregroundStyle(.secondary)
        }
    }
    private var refreshButton: some View {
        Button { refreshID += 1 } label: { Label("Refresh Materials",systemImage:"arrow.clockwise").feedbackFont(.body).frame(minHeight:28).contentShape(Rectangle()) }
            .controlSize(.large).disabled(fetching || saving).help("Fetch this assignment's materials from Canvas")
    }
    private var saveAllButton: some View {
        Button { saveAll() } label: {
            if saving { ProgressView().controlSize(.small) }
            else { Text("Save All Materials").feedbackFont(.body).frame(minHeight:28).contentShape(Rectangle()) }
        }.controlSize(.large)
            .disabled(fetching || saving || !exportMaterials.contains(where: { $0.url != nil }))
            .help("Save the available assignment materials to a new folder in Downloads")
            .accessibilityLabel("Save all assignment materials to Downloads")
    }
    @MainActor private func fetch() async {
        fetching = true; progress = "Fetching from Canvas…"; notice = ""
        defer { fetching = false }
        do {
            let cached = await store.cachedMaterialPlan(item)
            try Task.checkCancellation()
            plan = cached; materials = try await store.materialTexts(cached)
            for file in cached.files where cached.linkedFileIDs.contains(file.id) && file.localPath != nil {
                if let ready = try? await store.materialFile(file, plan: cached, cachedOnly: true) { try Task.checkCancellation(); materials.append(ready) }
            }
            let refreshed = try await store.prepareAssignment(item)
            try Task.checkCancellation()
            plan = refreshed; materials = try await store.materialTexts(refreshed)
            let linked = refreshed.files.filter { refreshed.linkedFileIDs.contains($0.id) }
            materials += linked.map { AssignmentMaterial(id: "file-\($0.id)", name: $0.name, note: "Downloading…", source: URL(string: "https://canvas.sydney.edu.au/courses/\(item.courseID)/files/\($0.id)")) }
            var total = 0
            for (index, file) in linked.enumerated() {
                try Task.checkCancellation()
                progress = "Downloading document \(index + 1) of \(linked.count)…"
                do {
                    guard total + file.size <= 300 * 1024 * 1024 else { throw FeedbackError.unavailable("Automatic downloads reached 300 MB; open this document in Canvas") }
                    let ready = try await store.materialFile(file, plan: refreshed)
                    try Task.checkCancellation()
                    total += ready.url.flatMap { try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize } ?? file.size
                    if let i = materials.firstIndex(where: { $0.id == ready.id }) { materials[i] = ready }
                } catch is CancellationError { throw CancellationError() }
                catch {
                    if let i = materials.firstIndex(where: { $0.id == "file-\(file.id)" }) { materials[i].note = "Unavailable: " + error.localizedDescription }
                }
            }
        } catch is CancellationError { }
        catch { notice = "Could not refresh materials. Cached files remain available. " + error.localizedDescription }
    }
    private func saveAll() {
        guard let plan else { return }
        let snapshot = exportMaterials
        saving = true
        saveTask = Task {
            defer { saving = false }
            do {
                let folder = try await store.saveMaterials(snapshot, plan: plan)
                let missing = snapshot.filter { $0.url == nil }.count
                notice = missing == 0 ? "Saved to Downloads." : "Saved available files to Downloads. \(missing) \(missing == 1 ? "material was" : "materials were") unavailable; see Collection notes.txt."
                NSWorkspace.shared.activateFileViewerSelecting([folder])
            } catch is CancellationError { }
            catch { notice = "Could not save to Downloads. " + error.localizedDescription }
        }
    }
    private func saveOne(_ source: URL) {
        let panel = NSSavePanel(); panel.nameFieldStringValue = source.lastPathComponent
        panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        guard let window = NSApp.keyWindow else { return }
        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let destination = panel.url else { return }
            do { try Data(contentsOf: source).write(to: destination, options: .atomic); notice = "Saved " + destination.lastPathComponent }
            catch { notice = "Could not save this copy. " + error.localizedDescription }
        }
    }
}
