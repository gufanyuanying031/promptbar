import AppKit
import SwiftUI

typealias ViewState<Value> = SwiftUI.State<Value>

private let ink = Color.primary
private let accent = Color(red:0.16, green:0.16, blue:0.17)
struct Glass: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView(); v.material = .underWindowBackground; v.blendingMode = .behindWindow; v.state = .active; return v
    }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}
struct HoverHint: ViewModifier {
    let text: String
    @ViewState<Bool> private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        content.onHover { hovering = $0 }
            .overlay(alignment:.bottom) {
                if hovering {
                    Text(text).font(.system(size:9,weight:.medium))
                        .foregroundStyle(Color.black.opacity(0.72))
                        .padding(.horizontal,7).padding(.vertical,3)
                        .background(.white.opacity(0.97),in:Capsule())
                        .overlay(Capsule().strokeBorder(Color.black.opacity(0.055),lineWidth:0.5))
                        .fixedSize().offset(y:17).allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration:0.16),value:hovering)
    }
}
struct TactileButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color.black.opacity(configuration.isPressed ? 0.09 : 0),in:RoundedRectangle(cornerRadius:9))
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.92 : 1)
            .opacity(configuration.isPressed ? 0.72 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration:0.13),value:configuration.isPressed)
    }
}
struct Icon: View {
    let symbol: String
    let help: String
    var active = false
    let action: () -> Void
    var body: some View {
        Button(action:action) { Image(systemName:symbol).font(.system(size:16, weight:.medium)).foregroundStyle(active ? accent : .primary).frame(width:34,height:34).background(active ? accent.opacity(0.10) : Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius:11)) }
            .buttonStyle(TactileButtonStyle()).modifier(HoverHint(text:help)).accessibilityLabel(help)
    }
}
struct Pill: View {
    let title: String
    let symbol: String
    let action: () -> Void
    var body: some View {
        Button(action:action) { Label(title,systemImage:symbol).font(.system(size:11, weight:.medium)).lineLimit(1).padding(.horizontal,10).padding(.vertical,7).background(Color.primary.opacity(0.045),in:Capsule()) }.buttonStyle(TactileButtonStyle())
    }
}
struct DragHandle: NSViewRepresentable {
    let model: Model
    func makeNSView(context: Context) -> HandleView { let view = HandleView(); view.model = model; return view }
    func updateNSView(_ view: HandleView, context: Context) { view.model = model }
    final class HandleView: NSView {
        weak var model: Model?
        override var mouseDownCanMoveWindow: Bool { false }
        override func resetCursorRects() { addCursorRect(bounds,cursor:.openHand) }
        override func draw(_ dirtyRect: NSRect) {
            NSColor.black.withAlphaComponent(0.30).setFill()
            for x in [-3.0, 3.0] { for y in [-5.0, 0.0, 5.0] {
                NSBezierPath(ovalIn:NSRect(x:bounds.midX+x-1,y:bounds.midY+y-1,width:2,height:2)).fill()
            } }
        }
        override func mouseDown(with event: NSEvent) {
            guard let window else { return }
            model?.dragging = true
            model?.collapse()
            NSCursor.closedHand.push()
            let start = window.frame.origin
            window.performDrag(with:event)
            let end = window.frame.origin
            model?.didDrag?(NSPoint(x:end.x-start.x,y:end.y-start.y))
            NSCursor.pop()
            model?.dragging = false
            model?.hover(false)
        }
    }
}
struct AlignedText: NSViewRepresentable {
    @Binding var text: String
    var enabled: Bool
    var roomy: Bool
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: AlignedText
        init(_ parent: AlignedText) { self.parent = parent }
        func textDidChange(_ notification: Notification) {
            if let view = notification.object as? NSTextView { parent.text = view.string }
        }
    }
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView(); scroll.drawsBackground = false; scroll.hasVerticalScroller = true; scroll.autohidesScrollers = true
        let view = NSTextView(); view.isRichText = false; view.drawsBackground = false
        view.font = .systemFont(ofSize:13); view.textColor = .labelColor; view.insertionPointColor = .labelColor
        view.textContainerInset = NSSize(width:5,height:7)
        view.isVerticallyResizable = true; view.isHorizontallyResizable = false
        view.autoresizingMask = [.width]; view.textContainer?.widthTracksTextView = true
        view.textContainer?.lineFragmentPadding = 0
        view.delegate = context.coordinator; view.setAccessibilityLabel(L("提示词编辑区"))
        scroll.documentView = view
        return scroll
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let view = scroll.documentView as? NSTextView else { return }
        if view.string != text {
            let range = view.selectedRange(); view.string = text
            view.setSelectedRange(NSRange(location:min(range.location,(text as NSString).length),length:0))
        }
        view.isEditable = enabled
    }
}
struct OrbitSpinner: View {
    var reduce: Bool
    var body: some View {
        TimelineView(.animation(minimumInterval:1.0 / 60.0,paused:reduce)) { context in
            let angle = reduce ? 0 : context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy:1.1) / 1.1 * 360
            Circle().trim(from:0.06,to:0.82)
                .stroke(AngularGradient(colors:[.white.opacity(0.15),.white.opacity(0.95)],center:.center),style:StrokeStyle(lineWidth:1.8,lineCap:.round))
                .frame(width:17,height:17).rotationEffect(.degrees(angle))
        }.accessibilityLabel(L("正在优化，点击取消"))
    }
}
struct CapsuleView: View {
    @ObservedObject var m: Model
    var body: some View {
        HStack(spacing:0) {
            DragHandle(model:m).frame(width:30,height:38).help(L("按住六点移动；不会触发展开"))
            divider
            Button { m.show(); m.focusEditor?() } label: {
                Image(systemName:"sparkles").font(.system(size:19,weight:.regular))
                    .frame(width:40,height:38,alignment:.center).contentShape(Rectangle())
            }.buttonStyle(TactileButtonStyle()).help(L("进入优化面板")).accessibilityLabel(L("三颗星优化入口"))
                .onHover { m.capsuleHover($0) }
            divider
            Button { m.preferences.alwaysOnTop.toggle(); m.save() } label: {
                Image(systemName:m.preferences.alwaysOnTop ? "pin.fill" : "pin")
                    .font(.system(size:16,weight:.regular)).frame(width:34,height:38,alignment:.center).contentShape(Rectangle())
            }.buttonStyle(TactileButtonStyle()).help(L("窗口保持最前")).accessibilityLabel(L("窗口置顶"))
        }.foregroundStyle(Color.black.opacity(0.78))
            .padding(.horizontal,5).padding(.vertical,3)
            .background(LinearGradient(colors:[.white,Color(red:0.97,green:0.98,blue:0.99).opacity(0.94),.white],startPoint:.topLeading,endPoint:.bottomTrailing))
            .background(Glass()).clipShape(Capsule())
            .overlay(Capsule().strokeBorder(.white,lineWidth:1))
            .overlay(Capsule().inset(by:1).strokeBorder(Color.black.opacity(0.09),lineWidth:0.5))
            .padding(8).preferredColorScheme(.light)
            .contextMenu {
                Button(L("展开优化面板")) { m.show() }
                Button(L("设置…")) { m.show(.settings) }
                Button(L("条目库")) { m.show(.history) }
                Divider()
                Button(L("退出 PromptBar")) { NSApp.terminate(nil) }
            }
    }
    var divider: some View { Rectangle().fill(Color.black.opacity(0.10)).frame(width:1,height:20) }
}
struct RootView: View {
    @ObservedObject var m: Model
    @ViewState<Bool> private var choosingStyle = false
    var body: some View {
        HStack(spacing:0) {
            Color.clear.frame(width:12)
            Group {
            if m.panelPresented && m.page != .editor {
                VStack(spacing:0) {
                    HStack {
                        Text(m.page == .settings ? L("设置") : L("条目库")).font(.system(size:14,weight:.semibold))
                        Spacer()
                        Icon(symbol:"arrow.left",help:L("返回悬浮栏")) { m.show() }
                        Icon(symbol:"minus",help:L("收起")) { m.collapse() }
                    }.padding(14)
                    if m.page == .settings { SettingsView(m:m) } else { HistoryView(m:m) }
                }.frame(width:420,height:510)
            } else {
                HStack(spacing:8) {
                    if m.panelPresented {
                        VStack(spacing:0) {
                            bar
                            if m.reading {
                                AlignedText(text:Binding(get:{m.draft},set:{m.edit($0)}),enabled:!m.busy,roomy:true)
                                    .frame(height:250).padding(10)
                                    .background(Color.white.opacity(0.62),in:RoundedRectangle(cornerRadius:14))
                                    .padding(.horizontal,6).padding(.bottom,10)
                            }
                        }.transition(.opacity.combined(with:.scale(scale:0.98,anchor:.center)))
                    } else { capsule.transition(.opacity) }
                }.padding(.horizontal,m.panelPresented ? 10 : 5).frame(height:m.panelPresented ? (m.reading ? 346 : 66) : 38)
            }
        }
            .onHover { m.hover($0) }
        }
        .background(
            LinearGradient(colors:[.white.opacity(0.98),Color(red:0.98,green:0.985,blue:0.99).opacity(0.92),.white.opacity(0.96)],startPoint:.topLeading,endPoint:.bottomTrailing)
        )
        .background(Glass())
        .clipShape(RoundedRectangle(cornerRadius:m.page != .editor && m.panelPresented ? 23 : 26))
        .overlay(RoundedRectangle(cornerRadius:m.page != .editor && m.panelPresented ? 23 : 26).strokeBorder(.white.opacity(0.95),lineWidth:1))
        .overlay(RoundedRectangle(cornerRadius:m.page != .editor && m.panelPresented ? 23 : 26).inset(by:1).strokeBorder(Color.black.opacity(0.055),lineWidth:0.5))
        .animation(m.preferences.reduceMotion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? nil : .easeInOut(duration:0.22),value:m.panelPresented)
        .frame(width:m.panelPresented ? (m.page == .editor ? 615 : 447) : 96,
               height:m.panelPresented ? (m.page == .editor ? (m.reading ? 346 : 66) : 510) : 38)
        .padding(8).tint(accent).preferredColorScheme(.light)
        .onChange(of:m.busy) { if !m.busy && !m.pointerInside { m.scheduleCollapse() } }
        .contextMenu { contextMenu }
        .onChange(of:m.preferences.selectedStyle) { choosingStyle = false }
        .onChange(of:choosingStyle) { m.menuOpen = choosingStyle; if !choosingStyle && !m.pointerInside { m.scheduleCollapse() } }
    }
    var capsule: some View {
        HStack(alignment:.center,spacing:0) {
            small("square.and.pencil", L("进入编辑")) { m.show() }
            Rectangle().fill(Color.black.opacity(0.10)).frame(width:1,height:17)
            small(m.preferences.alwaysOnTop ? "pin.fill" : "pin",m.preferences.alwaysOnTop ? L("取消窗口置顶") : L("窗口保持最前"),active:m.preferences.alwaysOnTop) { m.preferences.alwaysOnTop.toggle(); m.save() }
        }.frame(width:59,height:38,alignment:.center)
    }
    func small(_ symbol:String,_ help:String,active:Bool = false,action:@escaping () -> Void) -> some View {
        Button(action:action) {
            Image(systemName:symbol).font(.system(size:15,weight:.medium)).foregroundStyle(active ? accent : Color.black.opacity(0.76)).frame(width:29,height:30,alignment:.center).contentShape(Circle())
        }.buttonStyle(TactileButtonStyle()).modifier(HoverHint(text:help)).accessibilityLabel(help)
    }
    var bar: some View {
        HStack(alignment:.center,spacing:7) {

            small(m.style.symbol,L("选择优化风格")) { choosingStyle = true }
                .popover(isPresented:$choosingStyle,arrowEdge:.bottom) {
                    EditorView(m:m).stylePicker
                }
            Rectangle().fill(Color.black.opacity(0.08)).frame(width:1,height:28)
            ZStack(alignment:.bottomLeading) {
                AlignedText(text:Binding(get:{m.draft},set:{m.edit($0)}),enabled:!m.busy,roomy:false)
                    .frame(width:255,height:32)
                    .overlay(alignment:.leading) {
                        if m.draft.isEmpty { Text(L("粘贴提示词，或写下想法…")).font(.system(size:12)).foregroundStyle(.tertiary).padding(.leading,5).allowsHitTesting(false) }
                    }

            }
            small(m.reading ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right", (m.language == "en" ? "Expand text" : "展开长文"),active:m.reading) { m.toggleReading() }
            small("xmark.circle", L("清空输入")) { m.clearDraft() }.disabled(m.busy || m.draft.isEmpty)
            small(m.feedback == "paste" ? "checkmark" : "doc.on.clipboard",L("粘贴"),active:m.feedback == "paste") { m.paste() }.disabled(m.busy)
            small(m.feedback == "copy" ? "checkmark" : "doc.on.doc",L("复制"),active:m.feedback == "copy") { m.copy() }.disabled(m.busy || m.draft.isEmpty)
            small(m.pinnedOpen ? "lock.fill" : "lock.open",(m.language == "en" ? "Keep open" : "保持展开"),active:m.pinnedOpen) { m.togglePin() }

            Button {
                if m.busy { m.cancel() } else { m.toggle() }
            } label: {
                ZStack {
                    Circle().fill(accent)
                    if m.busy {
                        OrbitSpinner(reduce:m.preferences.reduceMotion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
                    } else {
                        Image(systemName:m.showingResult ? "arrow.uturn.backward" : "sparkles").font(.system(size:15,weight:.medium)).foregroundStyle(.white)
                    }
                }.frame(width:32,height:32)
            }.buttonStyle(TactileButtonStyle()).modifier(HoverHint(text:m.busy ? L("取消优化") : m.showingResult ? L("还原原文") : m.result != nil ? L("切回优化稿") : L("优化提示词")))
                .keyboardShortcut(.return,modifiers:.command).disabled(m.draft.isEmpty)
        }.help(m.error.isEmpty ? m.notice : m.error)
        .overlay(alignment:.bottomTrailing) {
            if !m.feedback.isEmpty {
                Text(m.feedback == "copy" ? L("已复制") : m.feedback == "paste" ? L("已粘贴") : L("已清空"))
                    .font(.system(size:10,weight:.medium)).padding(.horizontal,9).padding(.vertical,4)
                    .background(.white.opacity(0.96),in:Capsule()).offset(y:22)
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment:.bottomLeading) {
            if !m.error.isEmpty { Text(L(m.error)).font(.system(size:9)).foregroundStyle(.red).lineLimit(1).offset(y:16) }
        }
    }
    @ViewBuilder var contextMenu: some View {
        Button(m.expanded ? L("收起悬浮栏") : L("展开编辑器")) { m.expanded ? m.collapse() : m.show() }
        Menu(L("优化风格 · ") + L(m.style.name)) {
            ForEach(Style.presets) { style in
                Button { m.selectStyle(style.id) } label: { Label(L(style.name),systemImage:m.preferences.selectedStyle == style.id ? "checkmark" : style.symbol) }
            }
        }
        Menu(L("API 厂商 · ") + L(m.provider.name)) {
            ForEach(m.preferences.providers) { p in
                Button { m.preferences.selectedProvider = p.id; m.save() } label: { if p.id == m.preferences.selectedProvider { Label(p.name,systemImage:"checkmark") } else { Text(L(p.name)) } }
            }
        }
        Button(L("再次优化当前文本")) { m.optimize() }
        Button(L("补充修改要求…")) {
            let alert = NSAlert(); alert.messageText = L("继续调整提示词"); alert.informativeText = L("输入本轮修改要求，例如：更简洁，保留所有限制。")
            let input = NSTextField(frame:NSRect(x:0,y:0,width:320,height:52)); input.stringValue = m.refinement
            alert.accessoryView = input; alert.addButton(withTitle:L("优化")); alert.addButton(withTitle:L("取消"))
            m.menuOpen = true
            if alert.runModal() == .alertFirstButtonReturn { m.refinement = input.stringValue; m.optimize() }
            m.menuOpen = false
        }.disabled(m.busy || m.draft.isEmpty)
        Button(L("固定展开")) { m.togglePin() }
        Divider()
        Toggle(L("窗口保持最前"),isOn:$m.preferences.alwaysOnTop).onChange(of:m.preferences.alwaysOnTop) { m.save() }
        Button(L("条目库")) { m.show(.history) }
        Button(L("设置…")) { m.show(.settings) }
        Divider()
        Button(L("退出 PromptBar")) { NSApp.terminate(nil) }
    }
}
struct EditorView: View {
    @ObservedObject var m: Model
    @ViewState<Bool> var choosingStyle = false
    @FocusState var focused: Bool
    var body: some View {
        VStack(alignment:.leading,spacing:14) {
            HStack(spacing:8) {
                Pill(title:L(m.style.name),symbol:m.style.symbol) { choosingStyle.toggle() }.popover(isPresented:$choosingStyle,arrowEdge:.bottom) { stylePicker }
                Menu {
                    ForEach(m.preferences.providers) { p in Button(L(p.name)) { m.preferences.selectedProvider = p.id; m.save() } }
                    Divider(); Button(L("配置 API…")) { m.show(.settings) }
                } label: { Label(L(m.provider.name),systemImage:"cpu").font(.system(size:11,weight:.medium)).padding(.horizontal,9).padding(.vertical,7) }.menuStyle(.borderlessButton).fixedSize().disabled(m.busy)
                Spacer()
                Text(m.showingResult ? L("优化稿") : L("草稿")).font(.system(size:10,weight:.medium)).foregroundStyle(m.showingResult ? accent : .secondary)
            }
            ZStack(alignment:.topLeading) {
                RoundedRectangle(cornerRadius:16).fill(Color(nsColor:.textBackgroundColor).opacity(0.45))
                if m.draft.isEmpty { VStack(alignment:.leading,spacing:9) { Text(L("把想法放在这里。 ")).font(.system(size:20,weight:.medium,design:.rounded)); Text(L("粘贴提示词，或直接写下你想做的事。\n我们帮你把意思表达清楚。")).font(.system(size:12)).lineSpacing(5) }.foregroundStyle(.tertiary).padding(19).allowsHitTesting(false) }
                TextEditor(text:Binding(get:{m.draft},set:{m.edit($0)})).font(.system(size:14)).scrollContentBackground(.hidden).padding(12).focused($focused).disabled(m.busy).accessibilityLabel(L("提示词编辑区"))
            }.overlay(RoundedRectangle(cornerRadius:16).strokeBorder(Color.primary.opacity(0.065),lineWidth:1)).frame(maxHeight:.infinity)
            HStack {
                Text("\(m.draft.count.formatted()) " + L("字符")).font(.system(size:10,design:.monospaced)).foregroundStyle(.tertiary)
                Spacer()
                Button { m.paste() } label: { Label(L("粘贴"),systemImage:"doc.on.clipboard") }.disabled(m.busy)
                Button { m.keep() } label: { Label(L("置顶条目"),systemImage:"pin") }.disabled(m.draft.isEmpty || m.busy)
            }.font(.system(size:11)).buttonStyle(TactileButtonStyle())
            if m.result != nil {
                HStack(spacing:8) {
                    Image(systemName:"text.badge.plus").foregroundStyle(.secondary)
                    TextField(L("继续调整，例如：再简洁一点"),text:$m.refinement).textFieldStyle(.plain).font(.system(size:11)).disabled(m.busy)
                    Button(L("再优化")) { m.optimize() }.buttonStyle(TactileButtonStyle()).foregroundStyle(accent).disabled(m.busy)
                }.padding(10).background(Color.primary.opacity(0.035),in:RoundedRectangle(cornerRadius:10))
            }
            if !m.error.isEmpty { Text(L(m.error)).font(.system(size:11)).foregroundStyle(.red).lineLimit(3).textSelection(.enabled) }
            else { Text(m.busy ? "正在通过 \(m.provider.name) 优化，草稿已保留…" : m.notice.isEmpty ? L("仅发送到你选择的 API · 不会发送聊天消息") : m.notice).font(.system(size:10)).foregroundStyle(.secondary).lineLimit(2) }
            HStack(spacing:10) {
                if m.busy {
                    Button { m.cancel() } label: { HStack(spacing:8) { ProgressView().controlSize(.small); Text(L("取消优化")) }.frame(maxWidth:.infinity).frame(height:42) }.buttonStyle(TactileButtonStyle()).background(Color.primary.opacity(0.07),in:RoundedRectangle(cornerRadius:13))
                } else {
                    Button { m.toggle() } label: { Label(m.result == nil ? L("优化提示词") : m.showingResult ? L("还原原文") : L("切回优化稿"),systemImage:m.showingResult ? "arrow.uturn.backward" : "sparkles").font(.system(size:13,weight:.semibold)).frame(maxWidth:.infinity).frame(height:42).foregroundStyle(.white).background(accent,in:RoundedRectangle(cornerRadius:13)) }.buttonStyle(TactileButtonStyle()).keyboardShortcut(.return,modifiers:.command).disabled(m.draft.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
                }
                Button { m.copy() } label: { Label(L("复制"),systemImage:"doc.on.doc").font(.system(size:12,weight:.medium)).frame(width:92,height:42).background(Color.primary.opacity(0.055),in:RoundedRectangle(cornerRadius:13)) }.buttonStyle(TactileButtonStyle()).disabled(m.draft.isEmpty || m.busy)
            }
        }.padding(20)
    }
    var stylePicker: some View {
        VStack(alignment:.leading,spacing:5) {
            Text(L("表达风格")).font(.system(size:14,weight:.semibold)).padding(8)
            Text(L("与 API 厂商独立，可任意组合")).font(.system(size:10)).foregroundStyle(.secondary).padding(.horizontal,8).padding(.bottom,6)
            ForEach(Style.presets) { s in
                Button { m.selectStyle(s.id); choosingStyle = false; if s.id == "custom" && m.preferences.customInstruction.isEmpty { m.show(.settings) } } label: {
                    HStack(spacing:12) {
                        Image(systemName:s.symbol).frame(width:22).foregroundStyle(accent)
                        VStack(alignment:.leading,spacing:3) { Text(L(s.name)).font(.system(size:12,weight:.medium)); Text(L(s.detail)).font(.system(size:10)).foregroundStyle(.secondary) }
                        Spacer()
                        if m.style.id == s.id { Image(systemName:"checkmark.circle.fill").foregroundStyle(accent) }
                    }.padding(10).background(m.style.id == s.id ? accent.opacity(0.08) : .clear,in:RoundedRectangle(cornerRadius:10)).contentShape(Rectangle())
                }.buttonStyle(TactileButtonStyle())
            }
        }.padding(12).frame(width:285)
    }
}
struct HistoryView: View {
    @ObservedObject var m: Model
    var body: some View {
        VStack(alignment:.leading,spacing:14) {
            HStack { Text(L("条目库")).font(.system(size:23,weight:.semibold,design:.rounded)); Spacer(); Text("\(m.entries.filter(\.pinned).count) " + L("已置顶")).font(.system(size:11)).foregroundStyle(.secondary) }
            HStack { Image(systemName:"magnifyingglass").foregroundStyle(.secondary); TextField(L("搜索原文或优化稿"),text:$m.search).textFieldStyle(.plain) }.font(.system(size:12)).padding(11).background(Color.primary.opacity(0.04),in:RoundedRectangle(cornerRadius:11))
            if m.visibleEntries.isEmpty {
                VStack(spacing:12) { Image(systemName:"pin.circle").font(.system(size:40,weight:.ultraLight)).foregroundStyle(.tertiary); Text(m.search.isEmpty ? L("留住好用的表达") : L("没有匹配的条目")).font(.system(size:15,weight:.medium)); Text(L("优化后自动留存，也可将任意草稿置顶。\n置顶条目始终排在最前。")).font(.system(size:11)).foregroundStyle(.secondary).multilineTextAlignment(.center).lineSpacing(4) }.frame(maxWidth:.infinity,maxHeight:.infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing:9) {
                        ForEach(m.visibleEntries) { e in
                            VStack(alignment:.leading,spacing:10) {
                                HStack { Label(L(e.style),systemImage:e.pinned ? "pin.fill" : "sparkles").foregroundStyle(e.pinned ? accent : .secondary); Spacer(); Text(e.date,style:.date).foregroundStyle(.tertiary); Button { m.pin(e) } label: { Image(systemName:e.pinned ? "pin.slash" : "pin") }.help(e.pinned ? L("取消置顶") : L("置顶")) }
                                    .font(.system(size:10)).buttonStyle(TactileButtonStyle())
                                Text(e.result).font(.system(size:12)).lineLimit(3).frame(maxWidth:.infinity,alignment:.leading)
                                HStack { Text(L(e.provider)).font(.system(size:10)).foregroundStyle(.tertiary); Spacer(); Button(L("载入")) { m.load(e) }.disabled(m.busy); Button(L("复制")) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(e.result,forType:.string); m.notice = L("条目已复制") } }.font(.system(size:11)).buttonStyle(TactileButtonStyle()).foregroundStyle(accent)
                            }.padding(13).background(Color.primary.opacity(0.035),in:RoundedRectangle(cornerRadius:13))
                                .contextMenu { Button(e.pinned ? L("取消置顶") : L("置顶")) { m.pin(e) }; Button(L("载入编辑器")) { m.load(e) }; Divider(); Button(L("删除条目"),role:.destructive) { m.remove(e) } }
                        }
                    }
                }
            }
            HStack { Button(L("导入")) { m.importHistory() }; Button(L("导出")) { m.exportHistory() }; Spacer(); Button(L("清空历史")) { m.clearHistory() }.disabled(m.entries.filter{!$0.pinned}.isEmpty) }.font(.system(size:11)).buttonStyle(TactileButtonStyle()).foregroundStyle(.secondary)
            if !m.notice.isEmpty { Text(L(m.notice)).font(.system(size:10)).foregroundStyle(.secondary) }
            if !m.error.isEmpty { Text(L(m.error)).font(.system(size:10)).foregroundStyle(.red) }
        }.padding(20)
    }
}
struct SettingsView: View {
    @ObservedObject var m: Model
    @ViewState<Int> private var tab = 0
    @ViewState<String> private var key = ""
    @ViewState<String> private var keyNotice = ""
    @ViewState<Bool> private var keyDirty = false
    @ViewState<Bool> private var reveal = false
    @ViewState<String> private var editingProvider = ""
    var providerBinding: Binding<Provider> {
        Binding(get:{m.provider},set:{new in if let i = m.preferences.providers.firstIndex(where:{$0.id == new.id}) { m.preferences.providers[i] = new; m.save() }})
    }
    var body: some View {
        VStack(alignment:.leading,spacing:12) {
            HStack {
                Image(systemName:"globe").foregroundStyle(.secondary)
                Text(L("界面语言")).font(.system(size:11,weight:.medium))
                Spacer()
                Picker(L("界面语言"),selection:Binding(get:{m.language},set:{m.setLanguage($0)})) {
                    Text("English").tag("en"); Text("简体中文").tag("zh")
                }.labelsHidden().frame(width:145)
            }
            Picker(L("设置分类"),selection:$tab) { Text(L("模型与 API")).tag(0); Text(L("优化风格")).tag(1); Text(L("外观与行为")).tag(2) }.pickerStyle(.segmented).labelsHidden()
            ScrollView {
                VStack(alignment:.leading,spacing:17) {
                    if tab == 0 { api } else if tab == 1 { styles } else { behavior }
                }.padding(.bottom,8)
            }
            Spacer(minLength:0)
            HStack { Image(systemName:"lock.shield"); Text(L("Key 存于系统钥匙串 · 不含遥测或中转服务")) }.font(.system(size:10)).foregroundStyle(.tertiary)
        }.padding(20).onAppear { loadKey() }.onChange(of:m.preferences.selectedProvider) { loadKey() }
    }
    func loadKey() { key = Vault.read(m.provider.id); editingProvider = m.provider.id; keyDirty = false; keyNotice = ""; reveal = false }
    func saveKey() {
        do { try Vault.save(key.trimmingCharacters(in:.whitespacesAndNewlines),account:editingProvider); keyDirty = false; keyNotice = key.isEmpty ? L("已删除此厂商的 Key") : L("已保存到 macOS 钥匙串") }
        catch { keyNotice = error.localizedDescription }
    }
    func label(_ title: String, _ detail: String = "") -> some View {
        VStack(alignment:.leading,spacing:4) { Text(L(title)).font(.system(size:12,weight:.semibold)); if !detail.isEmpty { Text(L(detail)).font(.system(size:10)).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true) } }
    }
    var api: some View {
        Group {
            label(L("选择 API 厂商"), L("每个厂商独立保存模型、地址和 Key；切换厂商不会改变优化风格。"))
            Picker(L("厂商"),selection:Binding(get:{m.preferences.selectedProvider},set:{m.preferences.selectedProvider = $0; m.save()})) { ForEach(m.preferences.providers) { Text($0.name).tag($0.id) } }.labelsHidden().frame(maxWidth:.infinity,alignment:.leading)
            label(L("API 协议"))
            Picker(L("API 协议"),selection:providerBinding.wire) { ForEach(Provider.Wire.allCases,id:\.self) { Text(L($0.rawValue)).tag($0) } }.labelsHidden()
            VStack(alignment:.leading,spacing:7) { label("Base URL", L("填写 API 根地址。应用会自动追加对应协议的请求路径。"))
                TextField("https://api.example.com/v1",text:providerBinding.baseURL).textFieldStyle(.roundedBorder).font(.system(size:11,design:.monospaced)) }
            if m.provider.id == "deepseek" {
                VStack(alignment:.leading,spacing:7) {
                    label(L("DeepSeek 模型"), L("Flash：日常快速优化；Pro：复杂要求。也可在下方手动输入模型 ID。"))
                    HStack(spacing:8) {
                        ForEach(["deepseek-flash", "deepseek-v4-pro"],id:\.self) { id in
                            Button { var p = m.provider; p.model = id; providerBinding.wrappedValue = p } label: {
                                HStack(spacing:5) {
                                    if m.provider.model == id { Image(systemName:"checkmark") }
                                    Text(id == "deepseek-flash" ? "Flash" : "Pro")
                                }.font(.system(size:11,weight:.medium)).padding(.horizontal,14).padding(.vertical,8)
                                .foregroundStyle(m.provider.model == id ? Color.white : accent)
                                .background(m.provider.model == id ? accent : Color.black.opacity(0.04),in:Capsule())
                            }.buttonStyle(TactileButtonStyle())
                        }
                    }
                    Text(L("Flash 当前服务版本：V4.1-Flash-1017 · API ID 保持 deepseek-flash"))
                        .font(.system(size:9)).foregroundStyle(.secondary)
                }
            }
            VStack(alignment:.leading,spacing:7) { label(L("模型 ID"), L("填写厂商控制台的精确模型 ID；显示名称不一定等于 API ID。"))
                TextField(L("填写模型 ID"),text:providerBinding.model).textFieldStyle(.roundedBorder).font(.system(size:12,design:.monospaced)) }
            VStack(alignment:.leading,spacing:8) {
                label("API Key", L("切换厂商前请保存。未保存的 Key 不会用于请求。"))
                HStack {
                    Group { if reveal { TextField(L("输入 API Key"),text:$key) } else { SecureField(L("输入 API Key"),text:$key) } }.textFieldStyle(.roundedBorder).onChange(of:key) { keyDirty = true; keyNotice = "" }
                    Button { reveal.toggle() } label: { Image(systemName:reveal ? "eye.slash" : "eye") }.buttonStyle(TactileButtonStyle()).help(reveal ? L("隐藏 Key") : L("显示 Key"))
                    Button(L("保存")) { saveKey() }
                }
                if keyDirty { Text(L("Key 尚未保存")).font(.system(size:10)).foregroundStyle(.orange) }
                if !keyNotice.isEmpty { Text(L(keyNotice)).font(.system(size:10)).foregroundStyle(.secondary) }
            }
            HStack { Button(m.testing ? L("测试中…") : L("测试连接")) { m.testConnection() }.disabled(m.testing || keyDirty); Text(L("将产生一条简短的 API 请求")).font(.system(size:10)).foregroundStyle(.tertiary) }
            if !m.testMessage.isEmpty { Text(L(m.testMessage)).font(.system(size:11)).foregroundStyle(.secondary).textSelection(.enabled) }
        }
    }
    var styles: some View {
        Group {
            label(L("默认表达风格"), L("风格决定改写规则，厂商决定执行模型。选择任意组合即可。"))
            ForEach(Style.presets) { s in
                Button { m.selectStyle(s.id) } label: {
                    HStack(spacing:12) { Image(systemName:s.symbol).frame(width:24).foregroundStyle(accent); VStack(alignment:.leading,spacing:3) { Text(L(s.name)).font(.system(size:12,weight:.medium)); Text(L(s.detail)).font(.system(size:10)).foregroundStyle(.secondary) }; Spacer(); if m.style.id == s.id { Image(systemName:"checkmark.circle.fill").foregroundStyle(accent) } }.padding(11).background(m.style.id == s.id ? accent.opacity(0.08) : Color.primary.opacity(0.025),in:RoundedRectangle(cornerRadius:12))
                }.buttonStyle(TactileButtonStyle())
            }
            label(L("自定义风格规则"), L("选中“自定义”风格后生效，仍保留忠实原意等基本规则。"))
            TextEditor(text:Binding(get:{m.preferences.customInstruction},set:{m.preferences.customInstruction = $0; m.save()})).font(.system(size:12)).frame(height:90).padding(6).background(Color.primary.opacity(0.04),in:RoundedRectangle(cornerRadius:10)).overlay(RoundedRectangle(cornerRadius:10).stroke(Color.primary.opacity(0.08)))
        }
    }
    var behavior: some View {
        Group {
            label(L("轻一点，刚刚好"), L("收起后只保留小胶囊；点击左侧展开，右侧快捷切换优化稿。"))
            Toggle(L("窗口保持最前"),isOn:$m.preferences.alwaysOnTop).onChange(of:m.preferences.alwaysOnTop) { m.save() }
            Toggle(L("减少动态效果"),isOn:$m.preferences.reduceMotion).onChange(of:m.preferences.reduceMotion) { m.save() }
            Toggle(L("自动保存优化历史"),isOn:$m.preferences.historyEnabled).onChange(of:m.preferences.historyEnabled) { m.save() }
            Text(L("关闭自动历史后仍可手动置顶。历史以本地文本保存，最多保留 150 条未置顶记录，置顶条目不自动清理。")).font(.system(size:10)).foregroundStyle(.secondary)
            Divider()
            label(L("外观"), L("统一使用柔白背景、石墨色图标与细边框。主操作使用灰黑色强调。"))
            Divider()
            label(L("随手调用"), L("Control + Option + P：展开／收起\nCommand + Return：优化／切换原文\n拖动顶部空白区域移动窗口；右键选择风格、厂商或退出。"))
            label(L("剪贴板协作"), L("在 Codex 复制原文 → 在这里粘贴和优化 → 复制结果回去。不会读取其他应用的输入框，也不会自动发送。"))
            Divider()
            label("PromptBar 0.15.0", L("原生 SwiftUI + AppKit · Apple Silicon · macOS 14+\n独立实现的提示词悬浮工具，非 WorkBuddy 官方产品。"))
        }.font(.system(size:12))
    }
}
