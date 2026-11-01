import AppKit
import SwiftUI

@MainActor final class Model: ObservableObject {
    enum Page { case editor, history, settings }
    @Published var language = AppLanguage.current
    func setLanguage(_ value: String) { AppLanguage.current = value; language = value; resize?() }
    @Published var preferences = Preferences()
    @Published var entries: [Entry] = []
    @Published var expanded = false
    @Published var panelPresented = false
    @Published var pinnedOpen = false
    @Published var pointerInside = false
    @Published var dragging = false
    var transitioning = false
    private var starInside = false
    private var detailInside = false
    func capsuleHover(_ inside: Bool) { starInside = inside; applyHover() }
    private func applyHover() {
        pointerInside = starInside || detailInside; collapseTask?.cancel()
        if dragging || transitioning { return }
        if pointerInside { if !expanded { show() } } else { scheduleCollapse() }
    }
    @Published var reading = false
    func toggleReading() { reading.toggle(); resize?() }
    @Published var menuOpen = false
    private var collapseTask: Task<Void, Never>?
    @Published var page: Page = .editor
    @Published var draft = ""
    @Published var original: String?
    @Published var result: String?
    @Published var showingResult = false
    @Published var busy = false
    @Published var error = ""
    @Published var notice = ""
    @Published var feedback = ""
    private var feedbackTask: Task<Void, Never>?
    func confirm(_ action: String) {
        feedbackTask?.cancel(); feedback = action
        feedbackTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds:1_300_000_000)
            guard !Task.isCancelled else { return }; self?.feedback = ""
        }
    }
    func clearDraft() {
        guard !busy else { return }
        edit(""); refinement = ""; reading = false; resize?(); confirm("clear")
        if !pointerInside { scheduleCollapse() }
    }
    @Published var refinement = ""
    @Published var search = ""
    @Published var testing = false
    @Published var testMessage = ""
    var resize: (() -> Void)?
    var focusEditor: (() -> Void)?
    var didDrag: ((NSPoint) -> Void)?
    private var task: Task<Void, Never>?
    private var testTask: Task<Void, Never>?
    private var requestID = UUID()
    private var revision = 0
    private let directory: URL
    var provider: Provider { preferences.providers.first { $0.id == preferences.selectedProvider } ?? Provider.presets[0] }
    var style: Style { Style.presets.first { $0.id == preferences.selectedStyle } ?? Style.presets[0] }
    var visibleEntries: [Entry] {
        entries.filter { search.isEmpty || $0.original.localizedCaseInsensitiveContains(search) || $0.result.localizedCaseInsensitiveContains(search) }
            .sorted { $0.pinned != $1.pinned ? $0.pinned : $0.date > $1.date }
    }
    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("PromptBar")
        do {
            try FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            if FileManager.default.fileExists(atPath: self.directory.appendingPathComponent("preferences.json").path) {
                preferences = try JSONDecoder().decode(Preferences.self, from: Data(contentsOf: self.directory.appendingPathComponent("preferences.json")))
            }
            if FileManager.default.fileExists(atPath: self.directory.appendingPathComponent("history.json").path) {
                entries = try JSONDecoder().decode([Entry].self, from: Data(contentsOf: self.directory.appendingPathComponent("history.json")))
            }
        } catch { self.error = "本地数据读取失败，未覆盖原文件：\(error.localizedDescription)" }
        // Migrate only the shipped legacy default; preserve custom models/endpoints and Keychain accounts.
        if let i = preferences.providers.firstIndex(where: { $0.id == "deepseek" }),
           preferences.providers[i].model == "deepseek-chat",
           preferences.providers[i].baseURL == "https://api.deepseek.com/v1" {
            preferences.providers[i].model = "deepseek-flash"
        }

    }
    func save() {
        do {
            let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted, .sortedKeys]
            let p = directory.appendingPathComponent("preferences.json")
            let h = directory.appendingPathComponent("history.json")
            try e.encode(preferences).write(to:p, options:.atomic)
            try e.encode(entries).write(to:h, options:.atomic)
            try FileManager.default.setAttributes([.posixPermissions:0o600], ofItemAtPath:p.path)
            try FileManager.default.setAttributes([.posixPermissions:0o600], ofItemAtPath:h.path)
        } catch { self.error = "本地保存失败：\(error.localizedDescription)" }
        resize?()
    }
    func show(_ page: Page = .editor) { self.page = page; expanded = true; resize?() }
    func collapse() { collapseTask?.cancel(); expanded = false; resize?() }
    func hover(_ inside: Bool) { detailInside = inside; applyHover() }
    func scheduleCollapse() {
        collapseTask?.cancel()
        collapseTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 650_000_000)
            guard !Task.isCancelled, let self, !self.pointerInside, !self.dragging, !self.transitioning, !self.pinnedOpen,
                  !self.menuOpen, !self.busy, self.page == .editor else { return }
            self.collapse()
        }
    }
    func togglePin() { pinnedOpen.toggle(); if pinnedOpen { show() } else if !pointerInside { scheduleCollapse() } }

    func edit(_ text: String) {
        draft = text
        revision += 1
        // Editing a snapshot starts a new version, so restore never discards manual edits.
        original = nil; result = nil; showingResult = false; error = ""; notice = ""
    }
    func paste() {
        guard !busy else { return }
        guard let text = NSPasteboard.general.string(forType:.string), !text.isEmpty else { error = L("剪贴板中没有文本。"); return }
        edit(text); show(); confirm("paste")
    }
    func copy() {
        guard !draft.isEmpty else { return }
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(draft, forType:.string)
        notice = L("已复制，可粘贴回 Codex 或其他应用"); confirm("copy")
    }
    func toggle() {
        guard !busy else { return }
        if let original, let result {
            showingResult.toggle(); draft = showingResult ? result : original
            notice = showingResult ? L("已切换到优化稿") : L("已还原原文 · 再点可切回优化稿")
        } else { optimize() }
    }
    func cancel() { requestID = UUID(); task?.cancel(); task = nil; busy = false; notice = L("已取消，草稿保留") }
    func selectStyle(_ id: String) {
        guard id != preferences.selectedStyle, Style.presets.contains(where: { $0.id == id }) else { return }
        if busy { cancel() }
        preferences.selectedStyle = id; save()
        guard !draft.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else { return }
        refinement = ""
        optimize(source: original ?? draft)
    }
    func optimize(source: String? = nil) {
        guard !busy else { return }
        let input = (source ?? draft).trimmingCharacters(in:.whitespacesAndNewlines)
        guard !input.isEmpty else { error = L("先写一点想法，或粘贴提示词。"); return }
        guard input.count <= 32000 else { error = L("提示词过长，请控制在 32,000 字符以内。"); return }
        guard style.id != "custom" || !preferences.customInstruction.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else { error = L("请先在设置中填写自定义风格规则。"); return }
        let p = provider, s = style, originalText = source ?? draft
        let system = Optimizer.instruction(style:s, custom:preferences.customInstruction, refinement:refinement)
        let key = Vault.read(p.id)
        do { _ = try Optimizer.request(provider:p, key:key, system:system, text:input) } catch { self.error = error.localizedDescription; return }
        let id = UUID(); requestID = id
        let snapshotRevision = revision
        busy = true; error = ""; notice = ""
        task = Task {
            do {
                let output = try await Optimizer.run(provider:p, key:key, system:system, text:input)
                guard !Task.isCancelled, requestID == id, revision == snapshotRevision else { return }
                original = originalText; result = output; showingResult = true; draft = output
                if output.count > 180 || output.contains("\n") { reading = true; resize?() }
                refinement = ""; notice = L("优化完成 · 可随时还原")
                if preferences.historyEnabled {
                    entries.insert(Entry(original:originalText, result:output, style:s.name, provider:p.name), at:0)
                    trimHistory(); save()
                }
            } catch {
                if !Task.isCancelled && requestID == id { self.error = error is URLError ? "网络请求失败：\(error.localizedDescription)" : error.localizedDescription }
            }
            if requestID == id { busy = false; task = nil }
        }
    }
    func testConnection() {
        guard !testing else { return }
        let p = provider, key = Vault.read(p.id)
        do { _ = try Optimizer.request(provider:p, key:key, system:"Return OK.", text:"Reply OK") } catch { testMessage = error.localizedDescription; return }
        testing = true; testMessage = L("正在发送一条简短测试请求…")
        testTask = Task {
            do {
                _ = try await Optimizer.run(provider:p, key:key, system:"Return OK.", text:"Reply OK")
                testMessage = "\(p.name) · \(p.model) 连接成功"
            } catch { testMessage = "\(p.name)：\(error.localizedDescription)" }
            testing = false
        }
    }
    func pin(_ entry: Entry) { if let i = entries.firstIndex(where:{$0.id == entry.id}) { entries[i].pinned.toggle(); trimHistory(); save() } }
    func trimHistory() {
        let recent = entries.filter { !$0.pinned }.sorted { $0.date > $1.date }.prefix(150)
        entries = entries.filter(\.pinned) + recent
    }
    func keep() {
        guard !draft.isEmpty, !busy else { return }
        if let i = entries.firstIndex(where:{$0.original == (original ?? draft) && $0.result == (result ?? draft)}) {
            entries[i].pinned = true
        } else { entries.insert(Entry(original:original ?? draft, result:result ?? draft, style:style.name, provider:provider.name, pinned:true), at:0) }
        save(); notice = L("已置顶到条目库")
    }
    func load(_ entry: Entry) {
        guard !busy else { return }
        if !draft.isEmpty && draft != entry.result {
            let a = NSAlert(); a.messageText = L("载入这个条目？"); a.informativeText = L("这会替换当前编辑区的草稿。"); a.addButton(withTitle:L("载入")); a.addButton(withTitle:L("取消"))
            guard a.runModal() == .alertFirstButtonReturn else { return }
        }
        original = entry.original; result = entry.result; draft = entry.result; showingResult = true; revision += 1; error = ""; notice = L("已载入条目，可切换原文"); show()
    }
    func remove(_ entry: Entry) { entries.removeAll {$0.id == entry.id}; save() }
    func clearHistory() {
        let a = NSAlert(); a.messageText = L("清空未置顶的历史？"); a.informativeText = L("已置顶条目会保留。此操作无法撤销。"); a.addButton(withTitle:L("清空")); a.addButton(withTitle:L("取消"))
        if a.runModal() == .alertFirstButtonReturn { entries.removeAll {!$0.pinned}; save() }
    }
    func exportHistory() {
        let panel = NSSavePanel(); panel.nameFieldStringValue = L("PromptBar-条目.json"); panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { let e = JSONEncoder(); e.outputFormatting = .prettyPrinted; try e.encode(entries).write(to:url, options:.atomic); notice = L("条目已导出，不含 API Key") } catch { self.error = error.localizedDescription }
    }
    func importHistory() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.json]; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf:url)
            guard data.count < 10_000_000 else { throw BarError.message(L("导入文件超过 10 MB。")) }
            let incoming = try JSONDecoder().decode([Entry].self, from:data)
            let ids = Set(entries.map(\.id)); entries += incoming.filter {!ids.contains($0.id)}
            trimHistory(); save(); notice = L("已导入条目")
        } catch { self.error = "导入失败：\(error.localizedDescription)" }
    }
}
