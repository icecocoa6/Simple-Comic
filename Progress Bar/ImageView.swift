//
//  ImageView.swift
//  Simple Comic
//
//  Original version is created by Alexander Rauchfuss on 7/15/07.
//  Copyright 2007 Dancing Tortoise Software. All rights reserved.
//
//  Ported by Tomioka Taichi on 2020/03/22.
//

import Cocoa


public class ImageView: NSImageView {
    @objc public var clears: Bool = false
    @objc public var imageName: NSString?
    
    static var stringAttributes: [NSAttributedString.Key : Any] = {
        let style = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
        style.lineBreakMode = NSLineBreakMode.byTruncatingHead
        
        var attrs = [
            NSAttributedString.Key.font: NSFont.init(name: "Lucida Grande", size: 14)!,
            NSAttributedString.Key.foregroundColor: NSColor.white,
            NSAttributedString.Key.paragraphStyle: style
        ]
        return attrs
    }()
    
    override public func draw(_ dirtyRect: NSRect) {
        if (clears)
        {
            NSColor.clear.set()
            self.bounds.fill()
        }
        
        guard let img = self.image else { return }
        
        let imageRect = rectWithSizeCenteredInRect(img.size, self.bounds)
        img.draw(in: imageRect, from: NSZeroRect, operation: NSCompositingOperation.sourceOver, fraction: 1.0)
        
        if let imgName = self.imageName
        {
            let imgRect = imageRect.insetBy(dx: 10, dy: 10)
            let nameBounds = imgName.boundingRect(with: imgRect.size, options: [], attributes: ImageView.stringAttributes)
            let stringRect = rectWithSizeCenteredInRect(nameBounds.size, imgRect)
            NSColor.init(calibratedWhite: 0, alpha: 0.8).set()
            NSBezierPath.init(roundedRect: stringRect.insetBy(dx: -5.0, dy: -5.0), xRadius: 10, yRadius: 10).fill()
            imgName.draw(in: stringRect, withAttributes: ImageView.stringAttributes)
        }
    }
    
}
