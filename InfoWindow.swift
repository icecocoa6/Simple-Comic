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
import SwiftUI

public class InfoWindow: NSPanel {
    private var viewModel: ThumbnailPopupViewModel {
        (self.contentView as! NSHostingView<ThumbnailPopup>).rootView.viewModel
    }
    
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: NSWindow.StyleMask.borderless, backing: backingStoreType, defer: flag)
        
        self.backgroundColor = NSColor.clear
        self.isOpaque = false
        self.ignoresMouseEvents = true
    }
    
    public override func awakeFromNib() {
        self.contentView = NSHostingView(rootView: ThumbnailPopup())
    }
    
    func caret(atPoint point: NSPoint, size: NSSize, withLimitLeft left: CGFloat, right: CGFloat)
    {
        let view = self.contentView as! NSHostingView<ThumbnailPopup>
        let radius = view.rootView.radius
        let caretSize = view.rootView.caretSize
        let limitWidth = right - left
        let relativePosition = (point.x - left) / limitWidth
        let offset = size.width * relativePosition
        let frameRect = NSRect(x: point.x - offset - radius,
                               y: point.y,
                               width: size.width + radius * 2,
                               height: size.height + radius * 2 + caretSize.height)
        
        self.viewModel.caret = offset + radius
        self.setFrame(frameRect, display: true, animate: false)
        self.invalidateShadow()
    }
    
    func moveCenter(atPoint _center: NSPoint)
    {
        let center = CGVector(_center)
        let size = CGVector(self.frame.size)
        self.setFrameOrigin(CGPoint(center - size / 2.0))
        self.invalidateShadow()
    }

    func resize(toDiameter diameter: CGFloat)
    {
        let center = CGVector(self.frame.center)
        let size = CGVector(dx: diameter, dy: diameter)
        let origin = center - size / 2.0
        self.setFrame(CGRect(origin: CGPoint(origin), size: CGSize(size)),
                      display: true, animate: false)
    }
    
    var image: NSImage? {
        get {
            self.viewModel.image
        }
        set(value) {
            self.viewModel.image = value
        }
    }
}
