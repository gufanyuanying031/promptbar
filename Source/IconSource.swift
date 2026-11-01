import AppKit
let image = NSImage(size:NSSize(width:1024,height:1024))
image.lockFocus()
let outer = NSBezierPath(roundedRect:NSRect(x:48,y:48,width:928,height:928),xRadius:210,yRadius:210)
NSGradient(starting:NSColor(calibratedRed:1,green:1,blue:1,alpha:1),ending:NSColor(calibratedRed:0.94,green:0.94,blue:0.945,alpha:1))!.draw(in:outer,angle:-90)
NSColor.white.withAlphaComponent(0.85).setStroke(); outer.lineWidth = 6; outer.stroke()
let pill = NSBezierPath(roundedRect:NSRect(x:150,y:324,width:724,height:376),xRadius:188,yRadius:188)
NSColor.white.withAlphaComponent(0.6).setFill(); pill.fill()
NSColor.white.setStroke(); pill.lineWidth = 5; pill.stroke()
NSColor(calibratedRed:0.16,green:0.16,blue:0.17,alpha:1).set()
if let symbol = NSImage(systemSymbolName:"square.and.pencil",accessibilityDescription:nil)?.withSymbolConfiguration(.init(pointSize:150,weight:.regular)) { symbol.draw(in:NSRect(x:247,y:423,width:173,height:173)) }
let line = NSBezierPath(); line.move(to:NSPoint(x:512,y:400)); line.line(to:NSPoint(x:512,y:624)); line.lineWidth = 3; NSColor.gray.withAlphaComponent(0.25).setStroke(); line.stroke()
if let symbol = NSImage(systemSymbolName:"sparkles",accessibilityDescription:nil)?.withSymbolConfiguration(.init(pointSize:150,weight:.regular)) { symbol.draw(in:NSRect(x:598,y:423,width:173,height:173)) }
image.unlockFocus()
let rep = NSBitmapImageRep(data:image.tiffRepresentation!)!
try rep.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:CommandLine.arguments[1]))
