//
//  BezelWindow.swift
//  Simple Comic
//
//  Created by Alexander Rauchfuss on 5/30/07.
//  Copyright 2007 Dancing Tortoise Software. All rights reserved.
//
//  Portedd by Tomioka Taichi on 2020/04/10.
//

import Cocoa

class BezelWindow: NSPanel {
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect,
                   styleMask: .borderless,
                   backing: backingStoreType,
                   defer: flag)
    }
    
    override var canBecomeKey: Bool { true }
    override func performClose(_ sender: Any?) {
        _ = self.delegate?.windowShouldClose?(self)
    }
    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        return menuItem.action == #selector(performClose(_:))
    }
}

class BezelView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.set()
        dirtyRect.fill()
        let grad = NSGradient(colorsAndLocations: (NSColor(deviceWhite: 0.3, alpha: 1), 0.0),
                              (NSColor(deviceWhite: 0.25, alpha: 1), 0.5),
                              (NSColor(deviceWhite: 0.2, alpha: 1), 0.5),
                              (NSColor(deviceWhite: 0.1, alpha: 1), 1.0))
        grad?.draw(in: self.bounds, angle: 270)
    }
}
