//
//  ThumbnailView.swift
//  Simple Comic
//
//  Original version is created by Alexander Rauchfuss on 8/22/07.
//  Copyright 2007 Dancing Tortoise Software. All rights reserved.
//
//  Ported by Tomioka Taichi on 2020/03/22.
//

import Cocoa

public class ThumbnailView: NSView {
    @objc
    @IBOutlet var dataSource: TSSTSessionWindowController?
    @IBOutlet var pageController: NSArrayController?
    
    @IBOutlet var thumbnailView: ImageView?
    
    var trackingRects: NSMutableIndexSet? = NSMutableIndexSet.init()
    var trackingIndexes: NSMutableSet = NSMutableSet.init()
    
    var hoverIndex: Int = NSNotFound
    var limit: Int = 0
    
    var thumbLock: NSLock = NSLock.init()
    var threadIdent: UInt = 0
    
    override public func awakeFromNib() {
        self.window?.makeFirstResponder(self)
        self.window?.acceptsMouseMovedEvents = true
        thumbnailView?.clears = true
    }
    
    override public init(frame frameRect: NSRect)
    {
        super.init(frame: frameRect)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func draw(_ dirtyRect: NSRect) {
        let mouse = NSEvent.mouseLocation
        let mousePoint = self.window!.convertPoint(fromScreen: mouse)
        
        for counter in 0 ..< limit
        {
            let thumbnail = dataSource?.imageForPage(at: counter)
            var drawRect = self.rectFor(index: counter)
            drawRect = rectWithSizeCenteredInRect(thumbnail!.size, drawRect.insetBy(dx: 2, dy: 2))
            thumbnail?.draw(in: drawRect, from: NSZeroRect, operation: .sourceOver, fraction: 1.0)
            
            if NSMouseInRect(mousePoint, drawRect, false)
            {
                hoverIndex = counter
                self.zoomThumbnail(at: hoverIndex)
            }
        }
    }
    
    override public func mouseDown(with event: NSEvent) {
        let contents = pageController!.content as! [Any]
        
        if 0 ..< contents.count ~= hoverIndex
        {
            pageController?.setSelectionIndex(hoverIndex)
        }
        self.window?.orderOut(self)
    }
    
    override public func keyDown(with event: NSEvent) {
        let charNumber = event.charactersIgnoringModifiers!.first
        switch charNumber?.asciiValue {
        case 27:
            let wc = self.window?.windowController as! TSSTSessionWindowController
            wc.killTopOptionalUIElement()
            break
        default:
            break
        }
    }
    
    override public func mouseEntered(with event: NSEvent) {
        hoverIndex = (event.userData?.load(as: NSNumber.self).intValue)!
        
        let contents = pageController!.content as! [Any]?
        if limit == contents!.count
        {
            DispatchQueue.main.async {
                self.zoomThumbnail(at: self.hoverIndex)
            }
        }
    }
    
    override public func mouseExited(with event: NSEvent) {
        if event.userData?.load(as: NSNumber.self).intValue == hoverIndex
        {
            hoverIndex = NSNotFound
            
            thumbnailView?.image = nil
            self.window?.removeChildWindow((thumbnailView?.window)!)
            thumbnailView?.window?.orderOut(self)
        }
    }
    
    fileprivate func thumbRect(from rect: CGRect, size: CGSize, in visibleRect: CGRect) -> CGRect {
        let xRange = visibleRect.minX + size.width / 2 ... visibleRect.maxX - size.width / 2
        let yRange = visibleRect.minY + size.height / 2 ... visibleRect.maxY - size.height / 2
        let center = NSPoint.init(x: rect.midX.clamp(xRange),
                                  y: rect.midY.clamp(yRange))
        
        return NSRect.init(x: center.x - size.width / 2.0,
                           y: center.y - size.height / 2.0,
                           width: size.width, height: size.height)
    }
    
    func zoomThumbnail(at index: Int)
    {
        let objects = pageController?.arrangedObjects as! [AnyObject]?
        let thumbImage = objects?[index].value(forKey: "pageImage") as! NSImage?
        
        guard let thumbView = thumbnailView else { return; }
        guard let thumb = thumbImage else { return; }
        
        thumbView.image = thumb
        thumbView.needsDisplay = true
        thumbView.imageName = objects?[index].value(forKey: "name") as! NSString?
        
        if let window = thumbView.window as! InfoWindow?
        {
            let length: CGFloat = 312.0  // thumbnailView.frame.width
            let imageSize = thumb.size.fit(to: length)
            
            let indexRect = self.rectFor(index: index)
            let visibleRect = self.window!.screen!.visibleFrame
            let rect = thumbRect(from: indexRect, size: imageSize, in: visibleRect)
            
            window.setFrame(rect, display: false, animate: false)
            
            self.window?.addChildWindow(window, ordered: .above)
        }
    }
    
    @objc public func processThumbs()
    {
        threadIdent += 1
        let localIdent = threadIdent
        thumbLock.lock()
        let contents = pageController?.content as! [Any]?
        let pageCount = contents?.count ?? 0
        
        limit = 0
        while (limit < pageCount) && (localIdent == threadIdent) && (dataSource?.responds(to: #selector(TSSTSessionWindowController.imageForPage(at:))) ?? false)
        {
            dataSource?.imageForPage(at: limit)
            
            if limit % 5 == 0
            {
                DispatchQueue.main.async {
                    if self.window?.isVisible ?? false
                    {
                        self.needsDisplay = true
                    }
                }
            }
            
            limit += 1
        }
        
        thumbLock.unlock()
        DispatchQueue.main.async {
            self.needsDisplay = true
        }
    }
    
    func rectFor(index: Int) -> NSRect
    {
        let bounds: NSRect = self.window!.screen!.visibleFrame
        let ratio = bounds.height / bounds.width
        let contents = pageController!.content as! [Any]
        let horCount = Int(ceil(sqrt(CGFloat(contents.count) / ratio)))
        let vertCount = Int(ceil(CGFloat(contents.count) / CGFloat(horCount)))
        let side = bounds.height / CGFloat(vertCount)
        let horSide = bounds.width / CGFloat(horCount)
        let horGridPos = CGFloat(index % horCount);
        let vertGridPos = CGFloat((index / horCount) % vertCount)
        let pageOrder = dataSource?.session()?.value(forKey: "pageOrder") as! NSNumber?
        
        if pageOrder?.boolValue ?? false
        {
            return NSRect.init(x: horGridPos * horSide, y: bounds.maxY - side - vertGridPos * side, width: horSide, height: side);
        }
        else
        {
            return NSRect.init(x: bounds.maxX - horSide - horGridPos * horSide, y: bounds.maxY - side - vertGridPos * side, width: horSide, height: side);
        }
    }
    
    func removeTrackingRects()
    {
        thumbnailView?.image = nil
        hoverIndex = NSNotFound
        
        trackingRects?.enumerate {
            idx, _ in
            self.removeTrackingRect(idx)
        }
        
        trackingRects?.removeAllIndexes()
        trackingIndexes.removeAllObjects()
    }
    
    @objc public func buildTrackingRects()
    {
        hoverIndex = NSNotFound
        self.removeTrackingRects()
        
        let contents = pageController?.content as! [Any]
        for counter in 0 ..< contents.count
        {
            let trackRect = self.rectFor(index: counter).insetBy(dx: 2, dy: 2)
            let rectIndex = UnsafeMutablePointer<NSNumber>.allocate(capacity: 1)
            rectIndex.initialize(to: NSNumber.init(value: counter))
            
            let tagIndex = self.addTrackingRect(trackRect, owner: self, userData: rectIndex, assumeInside: false)
            trackingRects?.add(tagIndex)
            trackingIndexes.add(counter)
        }
        
        self.needsDisplay = true
    }
}

extension CGSize {
    fileprivate func fit(to length: CGFloat) -> CGSize {
        let aspect = self.width / self.height
        let viewSize: CGFloat = length
        if aspect <= 1.0
        {
            return CGSize.init(width: aspect * viewSize, height: viewSize)
        }
        else
        {
            return CGSize.init(width: viewSize, height: viewSize / aspect)
        }
    }
}

extension Comparable {
    fileprivate func clamp(_ limits: ClosedRange<Self>) -> Self {
        return min(max(limits.lowerBound, self), limits.upperBound)
    }
}
