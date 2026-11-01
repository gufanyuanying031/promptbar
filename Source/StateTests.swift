import Foundation
import AppKit
@main struct StateTests {
 @MainActor static func main() async throws {
  let dir = FileManager.default.temporaryDirectory.appendingPathComponent("PromptBar-Tests-" + UUID().uuidString)
  defer { try? FileManager.default.removeItem(at:dir) }
  let m = Model(directory:dir)
  m.original = "原文"; m.result = "优化稿"; m.draft = "优化稿"; m.showingResult = true
  m.toggle(); precondition(m.draft == "原文" && !m.showingResult)
  m.toggle(); precondition(m.draft == "优化稿" && m.showingResult)
  print("PASS original/result toggle without API")
  m.edit("手动修改"); precondition(m.original == nil && m.result == nil && !m.showingResult)
  print("PASS manual edit resets snapshots")
  m.keep(); precondition(m.entries.count == 1 && m.entries[0].pinned)
  m.keep(); precondition(m.entries.count == 1)
  print("PASS pinned draft saved without duplication")
  m.preferences.selectedStyle = "research"; m.preferences.selectedProvider = "gemini"; m.save()
  precondition(m.style.id == "research")
  print("PASS style/provider independence")
  let restored = Model(directory:dir)
  precondition(restored.entries.count == 1 && restored.entries[0].pinned && restored.style.id == "research")
  print("PASS entries and preferences survive relaunch")
  for i in 0..<170 { m.entries.append(Entry(original:"\(i)",result:"r",style:"s",provider:"p")) }
  m.trimHistory(); precondition(m.entries.count == 151 && m.entries.filter(\.pinned).count == 1)
  print("PASS history cap retains pinned entries")
  m.draft = "preserved"; m.busy = true; m.cancel(); precondition(!m.busy && m.draft == "preserved")
  print("PASS cancel preserves draft")
  m.toggleReading(); precondition(m.reading)
  m.toggleReading(); precondition(!m.reading)
  print("PASS long editor toggles independently")
  var resizeCount = 0; m.resize = { resizeCount += 1 }
  m.draft = "收藏测试"; m.keep()
  precondition(!m.reading && m.draft == "收藏测试")
  print("PASS saving leaves reading and draft unchanged")
  m.expanded = false; m.transitioning = true; m.hover(true)
  precondition(!m.expanded)
  m.transitioning = false; m.hover(false); m.hover(true)
  precondition(m.expanded)
  print("PASS animation ignores hover reentry, normal hover still expands")
  m.original = "original"; m.result = "result"; m.draft = "result"; m.reading = true
  m.clearDraft()
  precondition(m.draft.isEmpty && m.original == nil && m.result == nil && !m.reading && m.feedback == "clear")
  print("PASS clear resets current prompt and reports confirmation")
  m.pinnedOpen = false; m.busy = false; m.menuOpen = false; m.page = .editor; m.reading = true
  m.capsuleHover(false); m.hover(false)
  try await Task.sleep(nanoseconds:850_000_000)
  precondition(!m.expanded)
  print("PASS long editor collapses after pointer leaves")
  m.confirm("copy"); m.confirm("paste")
  try await Task.sleep(nanoseconds:1_450_000_000)
  precondition(m.feedback.isEmpty)
  print("PASS successive feedback expires without stale state")
  m.draft = "旧优化稿"; m.original = "最初原文"; m.result = "旧优化稿"; m.showingResult = true
  m.preferences.selectedStyle = "balanced"; m.preferences.customInstruction = ""
  m.selectStyle("custom")
  precondition(m.preferences.selectedStyle == "custom" && !m.busy && !m.error.isEmpty)
  precondition(m.draft == "旧优化稿" && m.original == "最初原文")
  print("PASS invalid custom style preserves current content without API")
  m.clearDraft(); m.selectStyle("concise")
  precondition(m.preferences.selectedStyle == "concise" && !m.busy)
  print("PASS empty draft changes style without API")
  let previousLanguage = AppLanguage.current
  defer { AppLanguage.current = previousLanguage }
  m.setLanguage("en")
  precondition(L("已复制") == "Copied" && L("清空输入") == "Clear prompt")
  precondition(L("deepseek-flash") == "deepseek-flash")
  precondition(L("我的提示词") == "我的提示词")
  print("PASS English UI labels and unchanged model IDs / user content")
  m.setLanguage("zh")
  precondition(L("已复制") == "已复制")
  print("PASS language switches back immediately")
  print("17 state checks passed. No live API request was made.")
 }
}
