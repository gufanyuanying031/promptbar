import AppKit
import SwiftUI
import Carbon
import QuartzCore

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = Model()
    var panel: FloatingPanel!
    var detailPanel: FloatingPanel!
    var item: NSStatusItem!
    var hotKey: EventHotKeyRef?
    var capsuleCenter: NSPoint?
    var lastExpanded = false
    var animationID = UUID()
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        panel = FloatingPanel(contentRect:NSRect(x:0,y:0,width:132,height:60),styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
        panel.isFloatingPanel = true; panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear; panel.isOpaque = false; panel.hasShadow = true
        panel.isMovableByWindowBackground = false; panel.collectionBehavior = [.canJoinAllSpaces,.fullScreenAuxiliary]
        let host = NSHostingView(rootView:CapsuleView(m:model))
        // SwiftUI must not resize NSPanel before our anchor-based layout runs.
        host.sizingOptions = []
        panel.contentView = host
        if let screen = NSScreen.main { let r = screen.visibleFrame; panel.setFrameOrigin(NSPoint(x:r.maxX-193,y:r.minY+110)) }
        panel.title = L("PromptBar 胶囊")
        detailPanel = FloatingPanel(contentRect:NSRect(x:0,y:0,width:631,height:82),styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
        detailPanel.title = L("PromptBar 优化面板")
        detailPanel.isFloatingPanel = true; detailPanel.hidesOnDeactivate = false
        detailPanel.isReleasedWhenClosed = false; detailPanel.isOpaque = false
        detailPanel.backgroundColor = .clear; detailPanel.hasShadow = true
        detailPanel.isMovableByWindowBackground = false
        detailPanel.collectionBehavior = [.canJoinAllSpaces,.fullScreenAuxiliary]
        let detailHost = NSHostingView(rootView:RootView(m:model)); detailHost.sizingOptions = []
        detailHost.wantsLayer = true
        detailPanel.contentView = detailHost
        capsuleCenter = NSPoint(x:panel.frame.midX,y:panel.frame.midY)
        model.didDrag = { [weak self] _ in
            guard let self else { return }
            self.capsuleCenter = NSPoint(x:self.panel.frame.midX,y:self.panel.frame.midY)
            self.resize()
        }
        model.focusEditor = { [weak self] in NSApp.activate(ignoringOtherApps:true); self?.detailPanel.makeKey() }
        model.resize = { [weak self] in self?.resize() }
        resize(); panel.orderFrontRegardless()
        item = NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName:"sparkles",accessibilityDescription:"PromptBar")
        item.button?.target = self; item.button?.action = #selector(statusClick)
        item.button?.sendAction(on:[.leftMouseUp,.rightMouseUp])
        NotificationCenter.default.addObserver(self,selector:#selector(menuStarted),name:NSMenu.didBeginTrackingNotification,object:nil)
        NotificationCenter.default.addObserver(self,selector:#selector(menuEnded),name:NSMenu.didEndTrackingNotification,object:nil)
        installHotKey()
        NotificationCenter.default.addObserver(self,selector:#selector(screenChanged),name:NSApplication.didChangeScreenParametersNotification,object:nil)
    }
    func resize() {
        guard panel != nil, detailPanel != nil else { return }
        panel.level = model.preferences.alwaysOnTop ? .floating : .normal
        detailPanel.level = panel.level
        let changed = lastExpanded != model.expanded
        lastExpanded = model.expanded
        let reduce = model.preferences.reduceMotion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        guard model.expanded else {
            if changed { animatePanel(open:false,reduce:reduce) }
            return
        }
        model.panelPresented = true
        let size = model.page == .editor ? NSSize(width:631,height:model.reading ? 362 : 82) : NSSize(width:463,height:526)
        let center = NSPoint(x:panel.frame.midX,y:panel.frame.midY)
        let screen = NSScreen.screens.first { $0.frame.contains(center) } ?? panel.screen ?? NSScreen.main
        let frame = Placement.detail(capsule:panel.frame,size:size,visible:screen?.visibleFrame)
        if changed || reduce || !detailPanel.isVisible {
            detailPanel.setFrame(frame,display:true)
        } else if detailPanel.frame != frame {
            NSAnimationContext.runAnimationGroup { c in
                c.duration = 0.26; c.timingFunction = CAMediaTimingFunction(name:.easeInEaseOut)
                detailPanel.animator().setFrame(frame,display:true)
            }
        }
        if changed { animatePanel(open:true,reduce:reduce) }
    }
    func animatePanel(open: Bool, reduce: Bool) {
        let id = UUID(); animationID = id
        let layer = detailPanel.contentView?.layer
        let current = layer?.presentation()?.transform
        layer?.removeAnimation(forKey:"panelReveal")
        let above = detailPanel.frame.midY > panel.frame.midY
        // Visual transform only: neither window frame nor capsule position is changed.
        let folded = CATransform3DConcat(CATransform3DMakeScale(0.94,0.86,1),CATransform3DMakeTranslation(0,above ? -7 : 7,0))
        let end = open ? CATransform3DIdentity : folded
        if reduce {
            layer?.transform = CATransform3DIdentity
            detailPanel.alphaValue = 1
            if open { detailPanel.orderFrontRegardless() } else { detailPanel.orderOut(nil); model.panelPresented = false }
            model.transitioning = false
            return
        }
        model.transitioning = true
        if open && !detailPanel.isVisible { detailPanel.alphaValue = 0 }
        if open { detailPanel.orderFrontRegardless() }
        let duration = open ? 0.34 : 0.24
        let animation = CABasicAnimation(keyPath:"transform")
        animation.fromValue = NSValue(caTransform3D:current ?? (open ? folded : CATransform3DIdentity))
        animation.toValue = NSValue(caTransform3D:end)
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(controlPoints:0.2,0.75,0.25,1)
        CATransaction.begin(); CATransaction.setDisableActions(true)
        layer?.transform = end
        layer?.add(animation,forKey:"panelReveal")
        CATransaction.commit()
        NSAnimationContext.runAnimationGroup({ c in
            c.duration = duration
            c.timingFunction = CAMediaTimingFunction(controlPoints:0.2,0.75,0.25,1)
            detailPanel.animator().alphaValue = open ? 1 : 0
        },completionHandler:{ [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.animationID == id else { return }
                self.model.transitioning = false
                if !open {
                    self.detailPanel.orderOut(nil)
                    self.model.panelPresented = false
                    self.detailPanel.contentView?.layer?.transform = CATransform3DIdentity
                    self.detailPanel.alphaValue = 1
                } else if !self.model.pointerInside { self.model.scheduleCollapse() }
            }
        })
    }
    @objc func menuStarted() { model.menuOpen = true }
    @objc func menuEnded() { model.menuOpen = false; if !model.pointerInside { model.scheduleCollapse() } }
    @objc func screenChanged() { resize() }
    @objc func toggle() { if model.expanded { model.collapse() } else { model.show() } }
    @objc func statusClick() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu(); menu.addItem(withTitle:model.expanded ? L("收起") : L("展开"),action:#selector(toggle),keyEquivalent:"")
            menu.addItem(withTitle:L("条目库"),action:#selector(history),keyEquivalent:"")
            menu.addItem(withTitle:L("设置…"),action:#selector(settings),keyEquivalent:"")
            menu.addItem(.separator()); menu.addItem(withTitle:L("退出 PromptBar"),action:#selector(quit),keyEquivalent:"q")
            for menuItem in menu.items { menuItem.target = self }
            item.menu = menu; item.button?.performClick(nil); item.menu = nil
        } else { toggle() }
    }
    @objc func history() { model.show(.history) }
    @objc func settings() { model.show(.settings) }
    @objc func quit() { NSApp.terminate(nil) }
    func installHotKey() {
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        var spec = EventTypeSpec(eventClass:OSType(kEventClassKeyboard),eventKind:UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, data in
            guard let data else { return noErr }
            let delegate = Unmanaged<AppDelegate>.fromOpaque(data).takeUnretainedValue()
            MainActor.assumeIsolated { delegate.toggle() }
            return noErr
        },1,&spec,pointer,nil)
        let id = EventHotKeyID(signature:0x50425231,id:1)
        let status = RegisterEventHotKey(UInt32(kVK_ANSI_P),UInt32(controlKey | optionKey),id,GetApplicationEventTarget(),0,&hotKey)
        if status != noErr { model.error = L("全局快捷键被占用，可通过菜单栏图标展开。") }
    }
    func applicationWillTerminate(_ notification: Notification) { if let hotKey { UnregisterEventHotKey(hotKey) } }
}
@main struct PromptBarMain {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
