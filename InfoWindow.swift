//
//  InfoWindow.swift
//  Simple Comic
//
//  Created by Alexander Rauchfuss on 7/15/07.
//  Copyright 2007 Dancing Tortoise Software. All rights reserved.
//
//  Ported by Tomioka Taichi on 2020/03/22.
//

import Cocoa

public class InfoWindow: NSPanel {

    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: NSWindow.StyleMask.borderless, backing: backingStoreType, defer: flag)
        
        self.backgroundColor = NSColor.clear
        self.isOpaque = false
        self.ignoresMouseEvents = true
    }
    
    @objc public func caret(atPoint point: NSPoint, size: NSSize, withLimitLeft left: CGFloat, right: CGFloat)
    {
        let limitWidth = right - left
        let relativePosition = (point.x - left) / limitWidth
        let offset = size.width * relativePosition
        let frameRect = NSRect.init(x: point.x - offset - 10, y: point.y, width: size.width + 20, height: size.height + 25)
        
        let view = self.contentView as! InfoView?
        view?.caretPosition = offset + 10
        self.setFrame(frameRect, display: true, animate: false)
        self.invalidateShadow()
    }
    
    @objc public func center(atPoint center: NSPoint)
    {
        self.setFrameOrigin(NSPoint.init(x: center.x - self.frame.width / 2.0, y: center.y - self.frame.height / 2.0))
        self.invalidateShadow()
    }

    @objc public func resize(toDiameter diameter: CGFloat)
    {
        let center = NSPoint.init(x: self.frame.midX, y: self.frame.midY)
        self.setFrame(NSRect.init(x: center.x - diameter / 2.0, y: center.y - diameter / 2.0, width: diameter, height: diameter), display: true, animate: false)
    }
}

class InfoView: NSView {
    private var _caretPosition: CGFloat = 0.0
    var caretPosition: CGFloat {
        get { return self._caretPosition }
        set(value) {
            self._caretPosition = value
            self.needsDisplay = true
        }
    }
    var bordered: Bool = false
    
    @objc public func setBordered(_ flag: Bool)
    {
        bordered = flag
    }
    
    override public func draw(_ dirtyRect: NSRect) {
        NSColor.clear.set()
        self.bounds.fill()
        
        let outline = NSBezierPath.init()
        outline.move(to: NSPoint.init(x: caretPosition + 5, y: 5))
        outline.line(to: NSPoint.init(x: caretPosition, y: 0))
        outline.line(to: NSPoint.init(x: caretPosition - 5, y: 5))
        outline.appendArc(from: NSPoint.init(x: 0, y: 5),
                          to: NSPoint.init(x: 0, y: self.bounds.midY),
                          radius: 5)
        outline.appendArc(from: NSPoint.init(x: 0, y: bounds.maxY),
                          to: NSPoint.init(x: self.bounds.midX, y: self.bounds.maxY),
                          radius: 5)
        outline.appendArc(from: NSPoint.init(x: self.bounds.maxX, y: self.bounds.maxY),
                          to: NSPoint.init(x: self.bounds.maxX, y: self.bounds.midY),
                          radius: 5)
        outline.appendArc(from: NSPoint.init(x: self.bounds.maxX, y: 5),
                          to: NSPoint.init(x: caretPosition + 5, y: 5),
                          radius: 5)
        outline.close()
        NSColor.init(calibratedWhite: 1.0, alpha: 1.0).set()
        outline.fill()
    }
}

class CircularImageView: NSImageView {
    
    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.set()
        self.bounds.fill()
        
        guard self.image != nil else { return }
        
        let loupeGradient = NSGradient.init(starting: NSColor.init(calibratedWhite: 0.3, alpha: 1), ending: NSColor.init(calibratedWhite: 0.6, alpha: 1))
        let centerPoint = centerPointOfRect(dirtyRect)
        loupeGradient?.draw(fromCenter: centerPoint, radius: dirtyRect.width / 2 - 10, toCenter: centerPoint, radius: dirtyRect.width / 2 - 1, options: [])
        
        let circle = NSBezierPath.init(ovalIn: self.bounds.insetBy(dx: 1, dy: 1))
        NSColor.init(calibratedWhite: 0.2, alpha: 2).set()
        circle.lineWidth = 2.0
        circle.stroke()
        
        let innerCirc = NSBezierPath.init(ovalIn: self.bounds.insetBy(dx: 10, dy: 10))
        NSColor.white.set()
        innerCirc.fill()
        innerCirc.addClip()
        
        super.draw(dirtyRect)
        
        NSColor.init(calibratedWhite: 0.6, alpha: 1).set()
        innerCirc.lineWidth = 3.0
        innerCirc.stroke()
    }
}
