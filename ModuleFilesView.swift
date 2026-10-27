import SwiftUI
import AppKit
import QuickLook

struct ModuleFilesView: View {
    @ObservedObject var feedback: FeedbackStore
    let back: () -> Void
    @AppStorage("feedbackReadingSize") private var readingStep = 0
    @State private var courseID = 0
    @State private var modules: [CanvasModule] = []
    @State private var selectedID: Int?
    @State private var ready: [Int: [AssignmentMaterial]] = [:]
    @State private var plans: [Int: AssignmentAssistPlan] = [:]
    @State private var loading = false
    @State private var saving = false
    @State private var status = ""
    @State private var error = ""
    @State private var savedFolder: URL?
    @State private var preview: URL?
    @State private var actionTask: Task<Void,Never>?
    @State private var refreshID = UUID()
    @State private var service = ModuleMaterialService(directory: FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("AssignmentDates/ModuleMaterials"))
    private var token: String? { feedback.permitsAutomaticNetwork ? TokenStore.read() : nil }
    private var courses: [(id:Int,name:String)] {
        var seen = Set<Int>()
        let saved = (MenuBarAppDelegate.store?.snapshot?.courses ?? []).map { (id:$0.id,name:$0.academicCode ?? $0.course_code) }
        let available = saved + feedback.items.map { (id:$0.courseID,name:$0.course) }
        return available.filter { seen.insert($0.id).inserted }.sorted { $0.name < $1.name }
    }
    private var courseName: String { courses.first { $0.id == courseID }?.name ?? "Course" }
    private var selected: CanvasModule? { modules.first { $0.id == selectedID } }
    var body: some View {
        NavigationSplitView {
            VStack(alignment:.leading,spacing:12) {
                Button(action:back) { Label("Assignments",systemImage:"chevron.left").feedbackFont(.body).frame(minHeight:28).contentShape(Rectangle()) }.controlSize(.large)
                Picker("Subject",selection:$courseID) {
                    ForEach(courses,id:\.id) { Text($0.name).tag($0.id) }
                }.disabled(saving)
                Text("Modules & weeks").feedbackFont(.headline)
                List(modules,selection:$selectedID) { module in
                    VStack(alignment:.leading,spacing:4) {
                        Text(module.name).feedbackFont(.body).lineLimit(3).fixedSize(horizontal:false,vertical:true).help(module.name)
                        Text("\(module.items.count) Canvas items").feedbackFont(.callout).foregroundStyle(.secondary)
                    }.padding(.vertical,6).tag(module.id)
                }.listStyle(.sidebar).disabled(saving)
                Button { save(all:true) } label: {
                    Label("Save All Modules",systemImage:"square.and.arrow.down").feedbackFont(.body).frame(maxWidth:.infinity,minHeight:32).contentShape(Rectangle())
                }.disabled(modules.isEmpty || loading || saving).help("Collect all modules in this subject and save them to a new folder in Downloads")
                Text("All weeks, organised into module and page folders.").feedbackFont(.callout).foregroundStyle(.secondary)
            }.padding(16).navigationSplitViewColumnWidth(min:260,ideal:310,max:420)
        } detail: {
            VStack(alignment:.leading,spacing:16) {
                if let selected {
                    Text(courseName).feedbackFont(.callout,weight:.semibold).foregroundStyle(.secondary)
                    Text(selected.name).feedbackFont(.title,weight:.bold).textSelection(.enabled)
                    ViewThatFits(in:.horizontal) {
                        HStack { instructions; Spacer(); saveModule }
                        VStack(alignment:.leading,spacing:10) { instructions; saveModule }
                    }
                    Divider()
                    if loading || saving {
                        HStack { ProgressView().controlSize(.small); Text(status).feedbackFont(.body); if saving { Button("Cancel") { actionTask?.cancel() } } }
                    }
                    ScrollView {
                        LazyVStack(alignment:.leading,spacing:12) {
                            let materials = ready[selected.id] ?? []
                            if let plan = plans[selected.id] {
                                ForEach(ModuleMaterialService.groups(plan,materials:materials)) { group in
                                    ModulePageGroup(group:group,materials:materials.filter { group.materialIDs.contains($0.id) },
                                        preview: { preview = $0 },save:saveFile)
                                        .id("\(selected.id):\(group.id)")
                                }
                            }
                            if let plan = plans[selected.id], !plan.warnings.isEmpty {
                                DisclosureGroup("Collection notes (\(plan.warnings.count))") {
                                    ForEach(Array(plan.warnings.enumerated()),id:\.offset) { _,note in Text(note).feedbackFont(.callout).textSelection(.enabled).padding(.vertical,5) }
                                }.disclosureGroupStyle(ComfortableDisclosureStyle())
                            }
                            if !loading, ready[selected.id]?.isEmpty == true { Text("No downloadable files were supplied in this module.").foregroundStyle(.secondary) }
                        }.padding(.vertical,4)
                    }
                } else {
                    ContentUnavailableView(loading ? "Loading modules…" : "Select a module",systemImage:"books.vertical",description:Text("Download teaching files for one week or the whole subject."))
                }
                if !error.isEmpty { Label(error,systemImage:"exclamationmark.triangle").feedbackFont(.callout).textSelection(.enabled) }
                if let savedFolder {
                    HStack { Text("Saved to Downloads in module and page folders").feedbackFont(.callout); Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([savedFolder]) } }
                }
            }.padding(24).frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.topLeading)
            .navigationTitle("Module Files")
            .toolbar {
                ToolbarItem {
                    Menu {
                        FeedbackReadingActions(step:$readingStep)
                        Divider()
                        Picker("Text Size",selection:$readingStep) {
                            ForEach(0...FeedbackReadingSize.maximum,id:\.self) { Text("\(100+$0*10)%").tag($0) }
                        }
                    } label: { Label("Text Size",systemImage:"textformat.size").frame(minWidth:28,minHeight:28).contentShape(Rectangle()) }
                    .help("Adjust text size throughout the app").accessibilityLabel("Text Size")
                }
                ToolbarItem { Button { refreshID = UUID() } label: { Label("Refresh Modules",systemImage:"arrow.clockwise").frame(minWidth:28,minHeight:28).contentShape(Rectangle()) }.disabled(loading || saving).help("Refresh the selected subject’s module list") }
            }
        }
        .feedbackFont(.body)
        .quickLookPreview($preview)
        .onAppear { if courseID == 0 { courseID = courses.first?.id ?? 0 } }
        .task(id:"\(courseID)-\(refreshID)") { await fetchCatalog() }
        .task(id:selectedID) { await fetchSelected() }
        .onDisappear { actionTask?.cancel() }
    }
    private var instructions: some View { Text("Files are grouped by their Canvas page. Drag a file, save this module, or save all modules.").feedbackFont(.callout).foregroundStyle(.secondary) }
    private var saveModule: some View {
        Button { save(all:false) } label: { Label("Save This Module",systemImage:"square.and.arrow.down").feedbackFont(.body).frame(minHeight:32).contentShape(Rectangle()) }
            .disabled(selected == nil || loading || saving)
    }
    private func fetchCatalog() async {
        guard courseID > 0 else { return }
        loading = true; error = ""; status = "Fetching modules from Canvas…"; selectedID = nil; ready = [:]; plans = [:]; savedFolder = nil
        let id = courseID
        let cached = await service.cachedCatalog(courseID:id)
        do {
            guard let key = token, !key.isEmpty else { throw FeedbackError.unavailable("Canvas is unavailable; showing saved modules when available.") }
            let fetched = try await service.catalog(courseID:id,token:key)
            guard !Task.isCancelled else { return }; modules = fetched
        } catch {
            guard !Task.isCancelled else { return }; modules = cached ?? []; self.error = error.localizedDescription
        }
        loading = false; selectedID = modules.first?.id
        if modules.isEmpty && error.isEmpty { error = "Canvas returned no visible modules for this subject." }
    }
    private func fetchSelected() async {
        guard let module = selected, !saving else { return }
        if ready[module.id] != nil { return }
        loading = true; status = "Collecting " + module.name + "…"
        do {
            let token = self.token
            let plan = try await service.prepare(module,courseID:courseID,course:courseName,token:token)
            let (files,updated) = try await service.ready(plan,token:token)
            guard !Task.isCancelled else { return }; plans[module.id] = updated; ready[module.id] = files
        } catch { if !Task.isCancelled { self.error = error.localizedDescription } }
        if !Task.isCancelled { loading = false }
    }
    private func save(all: Bool) {
        let targets = all ? modules : selected.map { [$0] } ?? []
        guard !targets.isEmpty, !loading, !saving else { return }
        saving = true; savedFolder = nil; error = ""
        actionTask = Task {
            defer { saving = false }
            do {
                let token = self.token
                let cachedFiles = ready, cachedPlans = plans, subjectID = courseID, subject = courseName, collector = service
                var completed = 0
                let collected = try await CanvasParallel.map(targets,limit:3) { module -> (CanvasModule,[AssignmentMaterial],AssignmentAssistPlan) in
                    try Task.checkCancellation()
                    let files: [AssignmentMaterial], plan: AssignmentAssistPlan
                    if let cached = cachedFiles[module.id], let saved = cachedPlans[module.id] { files = cached; plan = saved }
                    else {
                        let prepared = try await collector.prepare(module,courseID:subjectID,course:subject,token:token)
                        (files,plan) = try await collector.ready(prepared,token:token)
                    }
                    await MainActor.run {
                        completed += 1; status = "Collected \(completed) of \(targets.count) modules"
                        ready[module.id] = files; plans[module.id] = plan
                    }
                    return (module,files,plan)
                }
                try Task.checkCancellation()
                let downloads = FileManager.default.urls(for:.downloadsDirectory,in:.userDomainMask)[0]
                let exportInput = collected
                let exportTask = Task.detached { try ModuleMaterialService.export(exportInput,course:exportInput.first?.2.course ?? "Course",to:downloads) }
                savedFolder = try await withTaskCancellationHandler { try await exportTask.value } onCancel: { exportTask.cancel() }
                let missing = collected.flatMap { $0.1 }.filter { $0.url == nil }.count
                if missing > 0 { error = "\(missing) files were unavailable. Available files were saved; see Collection notes.txt in each module folder." }
            } catch is CancellationError { status = "Cancelled. Ready files remain available." }
            catch { self.error = error.localizedDescription }
        }
    }
    private func saveFile(_ material: AssignmentMaterial) {
        guard let url = material.url, let window = NSApp.keyWindow else { return }
        let panel = NSSavePanel(); panel.nameFieldStringValue = AssignmentAssistContent.safeName(material.name)
        panel.beginSheetModal(for:window) { response in
            guard response == .OK, let destination = panel.url else { return }
            do { try Data(contentsOf:url).write(to:destination,options:.atomic) }
            catch { self.error = error.localizedDescription }
        }
    }
}


private struct ModulePageGroup: View {
    let group: AssistMaterialGroup
    let materials: [AssignmentMaterial]
    let preview: (URL) -> Void
    let save: (AssignmentMaterial) -> Void
    @State private var expanded: Bool
    init(group: AssistMaterialGroup, materials: [AssignmentMaterial], preview: @escaping (URL) -> Void, save: @escaping (AssignmentMaterial) -> Void) {
        self.group = group; self.materials = materials; self.preview = preview; self.save = save
        _expanded = State(initialValue: materials.contains { Int($0.id) != nil && !Self.isImage($0) })
    }
    private static func isImage(_ material: AssignmentMaterial) -> Bool {
        ["png","jpg","jpeg","gif","webp","svg","tiff","ico"].contains((material.name as NSString).pathExtension.lowercased())
    }
    private var documents: [AssignmentMaterial] { materials.filter { Int($0.id) != nil && !Self.isImage($0) } }
    var body: some View {
        DisclosureGroup(isExpanded:$expanded) {
            VStack(alignment:.leading,spacing:10) {
                if let raw = group.sourceURL, let url = AssignmentAssistContent.cleanURL(raw) {
                    Link("Open page in Canvas",destination:url).feedbackFont(.callout).padding(.vertical,6)
                }
                ForEach(documents) { row($0) }
                let images = materials.filter { Self.isImage($0) }
                if !images.isEmpty {
                    DisclosureGroup("Page images (\(images.count))") { ForEach(images) { row($0) } }
                        .disclosureGroupStyle(ComfortableDisclosureStyle())
                }
                let texts = materials.filter { Int($0.id) == nil }
                if !texts.isEmpty {
                    DisclosureGroup("Page text & links (\(texts.count))") { ForEach(texts) { row($0) } }
                        .disclosureGroupStyle(ComfortableDisclosureStyle())
                }
                if materials.isEmpty { Text("No downloadable attachments on this page.").feedbackFont(.callout).foregroundStyle(.secondary) }
            }.padding(.vertical,10)
        } label: {
            VStack(alignment:.leading,spacing:4) {
                Text(group.title).feedbackFont(.headline).fixedSize(horizontal:false,vertical:true)
                Text("\(documents.count) attachment\(documents.count == 1 ? "" : "s") · Includes page text and linked resources")
                    .feedbackFont(.callout).foregroundStyle(.secondary)
            }.padding(.vertical,6)
        }
        .disclosureGroupStyle(ComfortableDisclosureStyle())
    }
    @ViewBuilder private func row(_ material: AssignmentMaterial) -> some View {
        if let url = material.url {
            NativeFileRow(name:material.name,detail:material.note,url:url,exportName:material.name,
                preview:{preview(url)},save:{save(material)},open:{NSWorkspace.shared.open(url)})
        } else {
            Label { VStack(alignment:.leading,spacing:4) {
                Text(material.name).feedbackFont(.body)
                Text(material.note).feedbackFont(.callout).foregroundStyle(.secondary)
            } } icon: { Image(systemName:"exclamationmark.triangle") }.padding(12)
        }
    }
}
