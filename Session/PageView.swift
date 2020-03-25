//
//  PageView.swift
//  Simple Comic
//
//   Copyright (c) 2006-2009 Dancing Tortoise Software
//
//   Permission is hereby granted, free of charge, to any person
//   obtaining a copy of this software and associated documentation
//   files (the "Software"), to deal in the Software without
//   restriction, including without limitation the rights to use,
//   copy, modify, merge, publish, distribute, sublicense, and/or
//   sell copies of the Software, and to permit persons to whom the
//   Software is furnished to do so, subject to the following
//   conditions:
//
//   The above copyright notice and this permission notice shall be
//   included in all copies or substantial portions of the Software.
//
//   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//   EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//   OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//   NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//   HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//   WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//   FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//   OTHER DEALINGS IN THE SOFTWARE.
//
//  Ported by Tomioka Taichi on 2020/03/24.
//
//   Composites one or two images to the screen, making sure that they
//   are horizontally alligned.
//   None of the logic involving the aspect ratios of the images is
//   in this class.
//

import Cocoa

class PageView: NSView {
    let NOTURN = 0
    let LEFTTURN = 1
    let RIGHTTURN = 2
    let UNKTURN = 3
    
    @objc var imageBounds: NSRect = NSZeroRect
    var firstPageRect: NSRect = NSZeroRect
    var secondPageRect: NSRect = NSZeroRect
    var firstPageImage: NSImage?
    var secondPageImage: NSImage?
    
    // Stores which arrow keys are currently depressed this enables multi axis keyboard scrolling.
    var scrollKeys: Int = 0
    // Timer that fires in between each keydown event to smooth out the scrolling.
    var scrollTimer: Timer? = nil
    var interfaceDelay: NSDate?
    
    @objc var rotation: Int = 0 {
        didSet {
            self.resizeView()
        }
    }
    
    @objc var sessionController: TSSTSessionWindowController?
    
    
    // This controls the drawing of the accepting drag-drop border highlighting
    var acceptingDrag: Bool = false
    
    /*    While page selection is in progress this method has a value of 1 or 2.
     The selection number coresponds to a highlighted page. */
    var pageSelection: Int = -1
    /* This is the rect describing the users page selection. */
    var cropRect: NSRect = NSZeroRect
    
    override func awakeFromNib() {
        /* Doing this so users can drag archives into the view. */
        self.registerForDraggedTypes([.fileURL])
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        scrollTimer?.invalidate()
    }
    
    override var acceptsFirstResponder: Bool { true }
    
    @objc func setFirstPage(_ first: NSImage, secondPageImage second: NSImage) {
        scrollKeys = 0
        if first != firstPageImage
        {
            firstPageImage = first
            self.startAnimation(forImage: firstPageImage)
        }
        
        if second != secondPageImage
        {
            secondPageImage = second
            self.startAnimation(forImage: secondPageImage)
        }
        
        self.resizeView()
    }
    
    // MARK: - Animations
    
    func startAnimation(forImage image: NSImage?)
    {
        guard image != nil else { return }
        
        let testImageRep = image!.bestRepresentation(for: NSZeroRect, context: NSGraphicsContext.current, hints: nil)
        if let imgRep = testImageRep as? NSBitmapImageRep
        {
            let frameCount = (imgRep.value(forProperty: .frameCount) as! NSNumber?)?.intValue ?? 0
            guard frameCount > 1 else { return }
            
            let loopCount = imgRep.value(forProperty: .loopCount) as! NSNumber?
            let frameDuration = (imgRep.value(forProperty: .currentFrameDuration) as! NSNumber?)?.floatValue ?? 0.0
            Timer.scheduledTimer(withTimeInterval: TimeInterval(max(frameDuration, 0.1)), repeats: false) { _ in
                self.animateImage(imageNumber: 1, page: self.firstPageImage, loopCount: loopCount?.intValue ?? 0)
            }
        }
    }
    
    func animateImage(imageNumber: Int, page: NSImage?, loopCount: Int)
    {
        let pageImage = imageNumber == 1 ? firstPageImage : secondPageImage
        if page != pageImage || sessionController == nil
        {
            return
        }
        let testImageRep = pageImage?.bestRepresentation(for: NSZeroRect, context: NSGraphicsContext.current, hints: nil) as! NSBitmapImageRep?
        let frameCount = (testImageRep?.value(forProperty: .frameCount) as! NSNumber?)?.intValue ?? 0
        var currentFrame = (testImageRep?.value(forProperty: .currentFrame) as! NSNumber?)?.intValue ?? 0
        currentFrame = currentFrame < frameCount ? (currentFrame + 1) : 0
        
        var loop = loopCount
        if currentFrame == 0 && loop > 1
        {
            loop -= 1
        }
        testImageRep?.setProperty(.currentFrame, withValue: currentFrame)
        if loop != 1
        {
            let frameDuration = (testImageRep?.value(forProperty: .currentFrameDuration) as! NSNumber?)?.floatValue ?? 0.0
            Timer.scheduledTimer(withTimeInterval: TimeInterval(max(frameDuration, 0.1)), repeats: false) { _ in
                self.animateImage(imageNumber: imageNumber, page: page, loopCount: loop)
            }
        }
        
        DispatchQueue.main.async {
            self.needsDisplay = true
        }
    }
    
    // MARK: - Drag and Drop
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let pboard = sender.draggingPasteboard
        if pboard.types?.contains(.fileURL) ?? false
        {
            acceptingDrag = true
            self.needsDisplay = true
            return .generic
        }
        return []
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        let pboard = sender.draggingPasteboard
        if pboard.types?.contains(.fileURL) ?? false
        {
            return .generic
        }
        return []
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        acceptingDrag = false
        self.needsDisplay = true
    }
    
    override func draggingEnded(_ sender: NSDraggingInfo) {
        acceptingDrag = false
        self.needsDisplay = true
    }
    
    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        acceptingDrag = false
        self.needsDisplay = true
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pboard = sender.draggingPasteboard
        if pboard.types?.contains(.fileURL) ?? false
        {
            let filePaths = pboard.propertyList(forType: .fileURL)!
            sessionController?.updateSessionObject()
            let app = NSApp.delegate as! SimpleComicAppDelegate
            app.addFiles([filePaths], to: sessionController?.session()!)
            return true
        }
        return false
    }
    
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pboard = sender.draggingPasteboard
        return pboard.types?.contains(.fileURL) ?? false
    }
    
    // MARK: - Drawing
    
    override func draw(_ dirtyRect: NSRect) {
        guard let firstPageImg = self.firstPageImage else { return }
        
        NSGraphicsContext.saveGraphicsState()
        self.rotationTransform(frame: self.frame)
        let interpolation = (self.inLiveResize || scrollKeys != 0) ? NSImageInterpolation.low : NSImageInterpolation.high
        NSGraphicsContext.current?.imageInterpolation = interpolation
        
        firstPageImg.draw(in: self.centerScanRect(firstPageRect),
                          from: NSZeroRect,
                          operation: .sourceOver,
                          fraction: 1.0)
        
        if secondPageImage?.isValid ?? false
        {
            secondPageImage!.draw(in: self.centerScanRect(secondPageRect),
                                  from: NSZeroRect,
                                  operation: .sourceOver,
                                  fraction: 1.0)
        }
        
        NSColor.init(calibratedWhite: 0.2, alpha: 0.5).set()
        
        let highlight: NSBezierPath
        if self.cropRect != NSZeroRect
        {
            let selection: NSRect
            if self.pageSelection == 0
            {
                selection = rectFromNegativeRect(self.cropRect).intersection(firstPageRect)
            }
            else
            {
                selection = rectFromNegativeRect(self.cropRect).intersection(secondPageRect)
            }
            
            highlight = NSBezierPath.init(rect: selection)
            highlight.fill()
            NSColor.init(calibratedWhite: 1.0, alpha: 0.8).set()
            NSBezierPath.defaultLineWidth = 2.0
            NSBezierPath.stroke(selection)
        }
        else if self.pageSelection == 0
        {
            highlight = NSBezierPath.init(rect: firstPageRect)
            highlight.fill()
        }
        else if self.pageSelection == 1
        {
            highlight = NSBezierPath.init(rect: secondPageRect)
            highlight.fill()
        }
        
        NSColor.init(calibratedWhite: 0.2, alpha: 0.8).set()
        
        if sessionController?.pageSelectionInProgress() ?? false
        {
            let style = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
            style.alignment = .center
            let stringAttributes = [
                NSAttributedString.Key.font: NSFont.init(name: "Lucida Grande", size: 24)!,
                NSAttributedString.Key.foregroundColor: NSColor.init(calibratedWhite: 1.0, alpha: 1.0),
                NSAttributedString.Key.paragraphStyle: style
            ]
            var selectionText: NSString = "Click to select page"
            if self.sessionController?.pageSelectionCanCrop() ?? false
            {
                selectionText = selectionText.appending("\nDrag to crop") as NSString
            }
            let textSize = selectionText.size(withAttributes: stringAttributes)
            let bezelRect = rectWithSizeCenteredInRect(textSize, self.imageBounds)
            let bezel = NSBezierPath.init(roundedRect: bezelRect.insetBy(dx: -8, dy: -4), xRadius: 10, yRadius: 10)
            bezel.fill()
            selectionText.draw(in: bezelRect, withAttributes: stringAttributes)
        }
        
        NSGraphicsContext.restoreGraphicsState()
        
        if acceptingDrag
        {
            NSBezierPath.defaultLineWidth = 6
            NSColor.keyboardFocusIndicatorColor.set()
            NSBezierPath.stroke(self.enclosingScrollView!.documentVisibleRect)
        }
    }
    
    @objc func image(inRect rect: NSRect) -> NSImage?
    {
        guard self.firstPageImage?.isValid ?? false else { return nil }
        
        var imageRect = imageBounds
        var cursorPoint = NSZeroPoint
        /* Re-orients the rectangle based on the current page rotation */
        switch rotation {
        case 0:
            cursorPoint = NSMakePoint(NSMinX(rect) - NSMinX(imageBounds), NSMinY(rect) - NSMinY(imageBounds));
            break;
        case 1:
            cursorPoint = NSMakePoint(NSMaxY(imageBounds) - NSMinY(rect), NSMinX(rect) - NSMinX(imageBounds));
            imageRect.size.width = NSHeight(imageBounds);
            imageRect.size.height = NSWidth(imageBounds);
            break;
        case 2:
            cursorPoint = NSMakePoint(NSMaxX(imageBounds) - NSMinX(rect), NSMaxY(imageBounds) - NSMinY(rect));
            break;
        case 3:
            cursorPoint = NSMakePoint(NSMinY(rect) - NSMinY(imageBounds), NSMaxX(imageBounds) - NSMinX(rect));
            imageRect.size.width = NSHeight(imageBounds);
            imageRect.size.height = NSWidth(imageBounds);
            break;
        default:
            break;
        }
        
        let power: CGFloat = CGFloat((UserDefaults.standard.value(forKey: TSSTLoupePower) as! NSNumber?)?.floatValue ?? 0.0)
        var firstFragment = NSZeroRect
        var secondFragment = NSZeroRect
        if (sessionController?.session()?.pageOrder!.boolValue)! || !secondPageImage!.isValid
        {
            let scale = imageRect.height / firstPageImage!.size.height
            let zoomSize = NSSize.init(width: rect.width / (power * scale), height: rect.height / (power * scale))
            firstFragment = NSRect.init(x: cursorPoint.x / scale - zoomSize.width / 2,
                                        y: cursorPoint.y / scale - zoomSize.height / 2,
                                        width: zoomSize.width,
                                        height: zoomSize.height)
            let remainder = firstFragment.maxX - firstPageImage!.size.width
            
            if secondPageImage!.isValid && remainder > 0
            {
                cursorPoint.x -= firstPageImage!.size.width * scale
                let scale = imageRect.height / secondPageImage!.size.height
                let zoomSize = NSSize.init(width: rect.width / (power * scale), height: rect.height / (power * scale))
                secondFragment = NSRect.init(x: cursorPoint.x / scale - zoomSize.width / 2,
                                             y: cursorPoint.y / scale - zoomSize.height / 2,
                                             width: zoomSize.width,
                                             height: zoomSize.height)
            }
        }
        else
        {
            let scale = imageRect.height / firstPageImage!.size.height
            let zoomSize = NSSize.init(width: rect.width / (power * scale), height: rect.height / (power * scale))
            secondFragment = NSRect.init(x: cursorPoint.x / scale - zoomSize.width / 2,
                                         y: cursorPoint.y / scale - zoomSize.height / 2,
                                         width: zoomSize.width,
                                         height: zoomSize.height)
            let remainder = secondFragment.maxX - secondPageImage!.size.width
            
            if remainder > 0
            {
                cursorPoint.x -= secondPageImage!.size.width * scale
                let scale = imageRect.height / firstPageImage!.size.height
                let zoomSize = NSSize.init(width: rect.width / (power * scale), height: rect.height / (power * scale))
                secondFragment = NSRect.init(x: cursorPoint.x / scale - zoomSize.width / 2,
                                             y: cursorPoint.y / scale - zoomSize.height / 2,
                                             width: zoomSize.width,
                                             height: zoomSize.height)
            }
        }
        
        let imageFragment = NSImage.init(size: rect.size)
        imageFragment.lockFocus()
        self.rotationTransform(frame: NSRect.init(origin: CGPoint.zero, size: rect.size))
        
        if firstFragment != NSZeroRect
        {
            firstPageImage?.draw(in: NSRect.init(origin: CGPoint.zero, size: rect.size),
                                 from: firstFragment,
                                 operation: .sourceOver,
                                 fraction: 1.0)
        }
        
        if secondFragment != NSZeroRect
        {
            secondPageImage?.draw(in: NSRect.init(origin: CGPoint.zero, size: rect.size),
                                  from: secondFragment,
                                  operation: .sourceOver,
                                  fraction: 1.0)
        }
        
        imageFragment.unlockFocus()
        return imageFragment
    }
    
    // MARK: - Geometry handling
    
    func rotationTransform(frame: NSRect)
    {
        let transform = NSAffineTransform.init()
        switch rotation {
        case 1:
            transform.rotate(byDegrees: 270)
            transform.translateX(by: -frame.height, yBy: 0)
            break
        case 2:
            transform.rotate(byDegrees: 180)
            transform.translateX(by: -frame.width, yBy: -frame.height)
            break
        case 3:
            transform.rotate(byDegrees: 90)
            transform.translateX(by: 0, yBy: -frame.width)
            break
        default:
            break
        }
        transform.concat()
    }
    
    @objc func correctViewPoint()
    {
        var correctOrigin = NSZeroPoint
        let frameSize = self.frame.size
        let viewSize = self.enclosingScrollView!.documentVisibleRect.size
        
        guard frameSize != NSZeroSize else { return }
        
        if sessionController!.pageTurn == 1
        {
            correctOrigin.x = frameSize.width > viewSize.width ? (frameSize.width - viewSize.width) : 0
        }
        
        correctOrigin.y = (frameSize.height > viewSize.height) ? (frameSize.height - viewSize.height) : 0
        
        let scrollView = self.enclosingScrollView
        let clipView = scrollView!.contentView
        clipView.scroll(to: correctOrigin)
        scrollView?.reflectScrolledClipView(clipView)
    }
    
    @objc func combinedImageSize(forZoom zoom: CGFloat) -> NSSize
    {
        var firstSize = firstPageImage?.size ?? NSZeroSize;
        var secondSize = secondPageImage?.size ?? NSZeroSize;
        
        if firstSize.height > secondSize.height
        {
            secondSize = scaleSize(secondSize , Float(firstSize.height / secondSize.height))
        }
        else if firstSize.height < secondSize.height
        {
            firstSize = scaleSize(firstSize , Float(secondSize.height / firstSize.height))
        }
        
        firstSize.width += secondSize.width
        
        if(rotation == 1 || rotation == 3)
        {
            firstSize = NSSize.init(width: firstSize.height, height: firstSize.width)
        }
        
        let zoomedSize = scaleSize(firstSize, Float(zoom))
        return zoomedSize
    }
    
    @objc func resizeView() {
        firstPageRect = NSZeroRect
        secondPageRect = NSZeroRect
        let visibleRect = self.enclosingScrollView!.documentVisibleRect
        let frameRect = self.frame
        var xpercent = NSMidX(visibleRect) / frameRect.size.width
        if frameRect.size.width == 0 {
            xpercent = 1.0
        }
        var ypercent = NSMidY(visibleRect) / frameRect.size.height
        if frameRect.size.height == 0 {
            ypercent = 1.0
        }
        var imageSize = self.combinedImageSize(forZoom: CGFloat((sessionController!.session().value(forKey: TSSTZoomLevel)! as! NSNumber).floatValue))
        
        var viewSize = NSZeroSize
        var scaleToFit: CGFloat
        var scaling = (sessionController!.session().value(forKey: TSSTPageScaleOptions)! as! NSNumber).intValue
        scaling = sessionController!.currentPageIsText() ? 2 : scaling
        switch (scaling)
        {
        case 0:
            viewSize.width = imageSize.width > NSWidth(visibleRect) ? imageSize.width : NSWidth(visibleRect);
            viewSize.height = imageSize.height > NSHeight(visibleRect) ? imageSize.height : NSHeight(visibleRect);
            break;
        case 1:
            viewSize = visibleRect.size;
            break;
        case 2:
            if(rotation == 1 || rotation == 3)
            {
                scaleToFit = NSHeight(visibleRect) / imageSize.height;
            }
            else
            {
                scaleToFit = NSWidth(visibleRect) / imageSize.width;
            }
            
            if (UserDefaults.standard.value(forKey: TSSTConstrainScale)! as! NSNumber).boolValue
            {
                scaleToFit = scaleToFit > 1 ? 1 : scaleToFit;
            }
            viewSize = scaleSize(imageSize, Float(scaleToFit));
            viewSize.width = viewSize.width > NSWidth(visibleRect) ? viewSize.width : NSWidth(visibleRect);
            viewSize.height = viewSize.height > NSHeight(visibleRect) ? viewSize.height : NSHeight(visibleRect);
            break;
        default:
            break;
        }
        
        viewSize = NSMakeSize(CGFloat(roundf(Float(viewSize.width))), CGFloat(roundf(Float(viewSize.height))))
        self.frame.size = viewSize
        
        if !(UserDefaults.standard.value(forKey: TSSTConstrainScale)! as! NSNumber).boolValue &&
            sessionController!.session()?.scaleOptions?.intValue != 0
        {
            if( viewSize.width / viewSize.height < imageSize.width / imageSize.height)
            {
                scaleToFit = viewSize.width / imageSize.width;
            }
            else
            {
                scaleToFit = viewSize.height / imageSize.height;
            }
            imageSize = scaleSize(imageSize, Float(scaleToFit))
        }
        
        imageBounds = rectWithSizeCenteredInRect(imageSize, NSMakeRect(0,0,viewSize.width, viewSize.height));
        var imageRect = imageBounds
        if rotation == 1 || rotation == 3
        {
            imageRect = rectWithSizeCenteredInRect(NSMakeSize( NSHeight(imageRect), NSWidth(imageRect)),
                                                   NSMakeRect( 0, 0, NSHeight(self.frame), NSWidth(self.frame)));
        }
        firstPageRect.size = scaleSize(firstPageImage!.size , Float(NSHeight(imageRect) / firstPageImage!.size.height));
        if secondPageImage?.isValid ?? false
        {
            secondPageRect.size = scaleSize(secondPageImage!.size , Float(NSHeight(imageRect) / secondPageImage!.size.height));
            if (sessionController!.session()?.pageOrder!.boolValue)!
            {
                firstPageRect.origin = imageRect.origin;
                secondPageRect.origin = NSMakePoint(NSMaxX(firstPageRect), NSMinY(imageRect));
            }
            else
            {
                secondPageRect.origin = imageRect.origin;
                firstPageRect.origin = NSMakePoint(NSMaxX(secondPageRect), NSMinY(imageRect));
            }
        }
        else
        {
            firstPageRect.origin = imageRect.origin;
        }
        
        let xOrigin = viewSize.width * xpercent;
        let yOrigin = viewSize.height * ypercent;
        let recenter = NSMakePoint(xOrigin - visibleRect.size.width / 2, yOrigin - visibleRect.size.height / 2);
        self.scroll(recenter)
        self.needsDisplay = true
    }
    
    func pageSelectionRect(selection: Int) -> NSRect
    {
        guard selection == 1 || selection == 2 else { return NSZeroRect }
        
        if !secondPageImage!.isValid
        {
            return selection == 1 ? self.bounds : NSZeroRect
        }
        
        let left2right = sessionController!.session()!.pageOrder!.boolValue
        let pages = left2right ? [firstPageRect, secondPageRect] : [secondPageRect, firstPageRect]
        let leftSelected = (left2right && selection == 1) || (!left2right && selection == 2)
        let left = NSRect.init(x: 0, y: 0, width: pages[0].maxX, height: self.bounds.height)
        let right = NSRect.init(x: pages[1].minX, y: 0, width: self.bounds.width - pages[1].minX, height: self.bounds.height)
        
        return leftSelected ? left : right
    }
    
    func imageCropRectangle() -> NSRect
    {
        if(NSEqualSizes(NSZeroSize, cropRect.size))
        {
            return NSZeroRect;
        }
        
        var selection: NSRect
        if (pageSelection == 0) {
            selection = NSIntersectionRect(rectFromNegativeRect(cropRect), firstPageRect);
        }
        else {
            selection = NSIntersectionRect(rectFromNegativeRect(cropRect), secondPageRect);
        }
        
        let center = centerPointOfRect(selection)
        var pageRect = NSZeroRect
        var originalSize = NSZeroSize
        if NSPointInRect(center, firstPageRect)
        {
            pageRect = firstPageRect
            originalSize = firstPageImage!.size
        }
        else if NSPointInRect(center, secondPageRect)
        {
            pageRect = secondPageRect;
            originalSize = secondPageImage!.size
        }
        
        pageRect.origin = NSMakePoint(selection.origin.x - pageRect.origin.x, selection.origin.y - pageRect.origin.y);
        let scaling = originalSize.height / pageRect.size.height;
        pageRect = NSMakeRect(pageRect.origin.x * scaling,
                              pageRect.origin.y * scaling,
                              selection.size.width * scaling,
                              selection.size.height * scaling);
        return pageRect;
    }
    
    // MARK: - Event handling
    
    override func scrollWheel(with event: NSEvent) {
        guard !sessionController!.pageSelectionInProgress() else
        {
            return
        }
        
        let modifier = event.modifierFlags
        var scaling = sessionController!.session()!.scaleOptions!.intValue
        scaling = sessionController!.currentPageIsText() ? 2 : scaling
        
        if modifier.contains(.command) && event.deltaY != 0
        {
            var loupeDiameter = (UserDefaults.standard.value(forKey: TSSTLoupeDiameter)! as! NSNumber).intValue
            loupeDiameter += event.deltaY > 0 ? 30 : -30;
            loupeDiameter = loupeDiameter < 150 ? 150 : loupeDiameter;
            loupeDiameter = loupeDiameter > 500 ? 500 : loupeDiameter;
            UserDefaults.standard.setValue(loupeDiameter, forKey: TSSTLoupeDiameter)
        }
        else if modifier.contains(.option) && event.deltaY != 0
        {
            var loupePower = (UserDefaults.standard.value(forKey: TSSTLoupePower)! as! NSNumber).intValue
            loupePower += event.deltaY > 0 ? 1 : -1;
            loupePower = loupePower < 2 ? 2 : loupePower;
            loupePower = loupePower > 6 ? 6 : loupePower;
            UserDefaults.standard.setValue(loupePower, forKey: TSSTLoupePower)
        }
        else if(scaling == 1)
        {
            let deltaX = event.deltaX
            if deltaX != 0.0
            {
                event.trackSwipeEvent(options: .lockDirection, dampenAmountThresholdMin: -1.0, max: 1.0) { (_, _, _, _) in
                }
            }
            
            
            if (deltaX > 0.0)
            {
                sessionController!.pageLeft(self)
            }
            else if (deltaX < 0.0)
            {
                sessionController!.pageRight(self)
            }
            
        }
        else
        {
            let visible = self.enclosingScrollView!.documentVisibleRect
            let scrollPoint = NSMakePoint(NSMinX(visible) - (event.deltaX * 5), NSMinY(visible) + (event.deltaY * 5));
            self.scroll(scrollPoint)
        }
        
        sessionController?.refreshLoupePanel()
    }
    
    override func keyDown(with event: NSEvent) {
        if sessionController!.pageSelectionInProgress()
        {
            sessionController!.cancelPageSelection()
            pageSelection = -1
            cropRect = NSZeroRect
            self.needsDisplay = true
            return
        }
        
        let modifier = event.modifierFlags
        let shiftKey = modifier.contains(.shift)
        let charNumber = event.charactersIgnoringModifiers!.unicodeScalars.first!
        let visible = self.enclosingScrollView!.documentVisibleRect
        var scrollPoint = visible.origin
        var scrolling = false
        let delta: CGFloat = shiftKey ? 50 * 3 : 50;
        
        switch (Int(charNumber.value))
        {
        case NSUpArrowFunctionKey:
            if !self.verticalScrollIsPossible
            {
                sessionController!.previousPage()
            }
            else
            {
                scrollKeys |= 1;
                scrollPoint.y += delta
                scrolling = true
            }
            break;
        case NSDownArrowFunctionKey:
            if !self.verticalScrollIsPossible
            {
                sessionController!.nextPage()
            }
            else
            {
                scrollKeys |= 2;
                scrollPoint.y -= delta
                scrolling = true
            }
            break;
        case NSLeftArrowFunctionKey:
            if !self.horizontalScrollIsPossible
            {
                sessionController!.pageLeft(self)
            }
            else
            {
                scrollKeys |= 4;
                scrollPoint.x -= delta
                scrolling = true;
            }
            break;
        case NSRightArrowFunctionKey:
            if !self.horizontalScrollIsPossible
            {
                sessionController!.pageRight(self)
            }
            else
            {
                scrollKeys |= 8
                scrollPoint.x += delta
                scrolling = true
            }
            break;
        case NSPageUpFunctionKey:
            self.pageUp()
            break;
        case NSPageDownFunctionKey:
            self.pageDown()
            break;
        case 0x20:    // Spacebar
            if(shiftKey)
            {
                self.pageUp()
            }
            else
            {
                self.pageDown()
            }
            break;
        case 27:
            sessionController!.killTopOptionalUIElement()
            break;
        case 127:
            self.pageUp()
            break;
        default:
            super.keyDown(with: event)
            break;
        }
        
        if scrolling && scrollTimer != nil
        {
            self.scroll(scrollPoint)
            sessionController!.refreshLoupePanel()
            let userInfo = [
                "lastTime": Date.init(),
                "accelerate": shiftKey,
                "leftTurnStart": nil,
                "rightTurnStart": nil
                ] as [String : Any?]
            // TODO: Timer animation
            scrollTimer = Timer.scheduledTimer(timeInterval: 1.0/10, target: self, selector: #selector(PageView.scroll(timer:) as (PageView) -> (Timer) -> Void), userInfo: userInfo, repeats: true)
        }
    }
    
    func pageUp() {
        let visible = self.enclosingScrollView!.documentVisibleRect
        var scrollPoint = visible.origin
        
        if NSMaxY(self.bounds) <= NSMaxY(visible)
        {
            if sessionController!.session()!.pageOrder!.boolValue
            {
                if(NSMinX(visible) > 0)
                {
                    scrollPoint = NSMakePoint(NSMinX(visible) - NSWidth(visible), 0)
                    self.scroll(scrollPoint)
                }
                else
                {
                    sessionController!.pageTurn = 1
                    sessionController!.previousPage()
                }
            }
            else
            {
                if NSMaxX(visible) < NSWidth(self.bounds)
                {
                    scrollPoint = NSMakePoint(NSMaxX(visible), 0)
                    self.scroll(scrollPoint)
                }
                else
                {
                    sessionController!.pageTurn = 2
                    sessionController!.previousPage()
                }
            }
        }
        else
        {
            scrollPoint.y += visible.size.height;
            self.scroll(scrollPoint)
        }
    }
    
    func pageDown() {
        let visible = self.enclosingScrollView!.documentVisibleRect
        var scrollPoint = visible.origin;
        
        if scrollPoint.y <= 0
        {
            if sessionController!.session().pageOrder!.boolValue
            {
                if NSMaxX(visible) < NSWidth(self.bounds)
                {
                    scrollPoint = NSMakePoint(NSMaxX(visible), NSHeight(self.bounds) - NSHeight(visible))
                    self.scroll(scrollPoint)
                }
                else
                {
                    sessionController!.pageTurn =  2
                    sessionController!.nextPage()
                }
            }
            else
            {
                if NSMinX(visible) > 0
                {
                    scrollPoint = NSMakePoint(NSMinX(visible) - NSWidth(visible), NSHeight(self.bounds) - NSHeight(visible))
                    self.scroll(scrollPoint)
                }
                else
                {
                    sessionController!.pageTurn = 1
                    sessionController!.nextPage()
                }
            }
        }
        else
        {
            scrollPoint.y -= visible.size.height;
            self.scroll(scrollPoint)
        }
    }
    
    override func keyUp(with event: NSEvent) {
        let charNumber = event.charactersIgnoringModifiers!.unicodeScalars.first!
        switch Int(charNumber.value)
        {
        case NSUpArrowFunctionKey:
            scrollKeys &= 14;
            break;
        case NSDownArrowFunctionKey:
            scrollKeys &= 13;
            break;
        case NSLeftArrowFunctionKey:
            scrollKeys &= 11;
            break;
        case NSRightArrowFunctionKey:
            scrollKeys &= 7;
            break;
        default:
            break;
        }
    }
    
    override func flagsChanged(with event: NSEvent) {
        if (event.type.rawValue & NSEvent.EventType.keyDown.rawValue) != 0 && event.modifierFlags.contains(.command)
        {
            scrollKeys = 0;
        }
    }
    
    @objc func scroll(timer: Timer) {
        if scrollKeys == 0
        {
            scrollTimer?.invalidate()
            scrollTimer = nil;
            // This is to reset the interpolation.
            self.needsDisplay = true
            return;
        }
        
        let pageTurnAllowed = (UserDefaults.standard.value(forKey: TSSTAutoPageTurn)! as! NSNumber).boolValue
        let delay: TimeInterval = 0.2;
        let visible = self.enclosingScrollView!.documentVisibleRect
        let currentDate = Date.init()
        let difference: TimeInterval = currentDate.timeIntervalSince((timer.userInfo! as! NSMutableDictionary)["lastTime"] as! Date)
        let multiplier = ((timer.userInfo! as! NSMutableDictionary)["accelerate"]! as! NSNumber).boolValue ? 3 : 1
        (timer.userInfo! as! NSMutableDictionary)["lastTime"] = currentDate
        var scrollPoint = visible.origin
        let delta = CGFloat(1000 * difference * Double(multiplier))
        var turn = NOTURN
        var directionString: NSString? = nil
        let turnDirection = sessionController!.session().pageOrder?.boolValue
        var finishTurn = false
        if scrollKeys & 1 != 0
        {
            scrollPoint.y += delta;
            if(NSMaxY(visible) >= NSMaxY(self.frame) && pageTurnAllowed)
            {
                turn = turnDirection! ? LEFTTURN : RIGHTTURN;
            }
        }
        
        if (scrollKeys & 2) != 0
        {
            scrollPoint.y -= delta;
            if(scrollPoint.y <= 0 && pageTurnAllowed)
            {
                turn = turnDirection! ? RIGHTTURN : LEFTTURN;
            }
        }
        
        if (scrollKeys & 4) != 0
        {
            scrollPoint.x -= delta;
            if(scrollPoint.x <= 0 && pageTurnAllowed)
            {
                turn = LEFTTURN;
            }
        }
        
        if (scrollKeys & 8) != 0
        {
            scrollPoint.x += delta;
            if(NSMaxX(visible) >= NSMaxX(self.frame) && pageTurnAllowed)
            {
                turn = RIGHTTURN;
            }
        }
        
        if(turn != NOTURN)
        {
            var difference = 0;
            
            if(turn == RIGHTTURN)
            {
                directionString = "rightTurnStart";
            }
            else
            {
                directionString = "leftTurnStart";
            }
            
            if (timer.userInfo! as! NSMutableDictionary)[directionString! as String] != nil
            {
                (timer.userInfo! as! NSMutableDictionary)[directionString! as String] = currentDate
            }
            else
            {
                difference = Int(currentDate.timeIntervalSince((timer.userInfo! as! NSMutableDictionary)[directionString! as String] as! Date))
            }
            
            if difference >= Int(delay)
            {
                if(turn == LEFTTURN)
                {
                    sessionController!.pageLeft(self)
                    finishTurn = true
                }
                else if(turn == RIGHTTURN)
                {
                    sessionController!.pageRight(self)
                    finishTurn = true
                }
                
                scrollTimer?.invalidate()
                scrollTimer = nil;
            }
        }
        else
        {
            (timer.userInfo! as! NSMutableDictionary)["rightTurnStart"] = nil
            (timer.userInfo! as! NSMutableDictionary)["leftTurnStart"] = nil
        }
        
        if !finishTurn
        {
            let scrollView = self.enclosingScrollView
            let clipView = scrollView!.contentView
            clipView.scroll(to: clipView.constrainBoundsRect(NSMakeRect(scrollPoint.x, scrollPoint.y, 1, 1)).origin)
            scrollView?.reflectScrolledClipView(clipView)
        }
        
        sessionController?.refreshLoupePanel()
    }
    
    override func rightMouseDown(with event: NSEvent) {
        let loupe = sessionController!.session().loupe!.boolValue
        sessionController!.session().loupe = !loupe as NSNumber
    }
    
    override func mouseDown(with event: NSEvent) {
        if sessionController!.pageSelectionInProgress() {
            let cursor = self.convert(event.locationInWindow, from: nil)
            cropRect.origin = cursor;
        }
        else if self.dragIsPossible
        {
            NSCursor.closedHand.set()
        }
    }
    
    override func mouseMoved(with event: NSEvent) {
        if sessionController!.pageSelectionInProgress()
        {
            let cursor = self.convert(event.locationInWindow, from: nil)
            if NSPointInRect(cursor, firstPageRect) && (sessionController?.canSelectPageIndex(0))!
            {
                pageSelection = 0;
            }
            else if NSPointInRect(cursor, secondPageRect) && sessionController!.canSelectPageIndex(1)
            {
                pageSelection = 1;
            }
            else
            {
                pageSelection = -1;
            }
            self.needsDisplay = true
        }
        else
        {
            super.mouseMoved(with: event)
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        let viewOrigin = self.enclosingScrollView!.documentVisibleRect.origin
        var cursor = event.locationInWindow
        var currentPoint: NSPoint
        if sessionController!.pageSelectionInProgress()
        {
            cursor = self.convert(cursor, from: nil)
            cropRect.size.width = cursor.x - cropRect.origin.x;
            cropRect.size.height = cursor.y - cropRect.origin.y;
            if NSPointInRect(cropRect.origin, self.pageSelectionRect(selection: 1))
            {
                pageSelection = 0;
            }
            else if NSPointInRect(cropRect.origin, self.pageSelectionRect(selection: 2))
            {
                pageSelection = 1;
            }
            self.needsDisplay = true
        }
        else if self.dragIsPossible
        {
            var e = event
            while e.type != .leftMouseUp
            {
                if e.type == .leftMouseDragged
                {
                    currentPoint = e.locationInWindow
                    self.scroll(NSMakePoint(viewOrigin.x + cursor.x - currentPoint.x,viewOrigin.y + cursor.y - currentPoint.y))
                    sessionController!.refreshLoupePanel()
                }
                e = (self.window?.nextEvent(matching: [.leftMouseUp, .leftMouseDragged]))!
            }
            self.window?.invalidateCursorRects(for: self)
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        if sessionController!.pageSelectionInProgress()
        {
            sessionController!.selectedPage(pageSelection, withCropRect: self.imageCropRectangle())
            pageSelection = -1;
            cropRect = NSZeroRect;
            
            self.needsDisplay = true
            return;
        }
        
        if self.dragIsPossible
        {
            NSCursor.openHand.set()
        }
        
        let clickPoint = event.locationInWindow
        let viewSplit = NSWidth(self.enclosingScrollView!.frame) / 2
        if NSMouseInRect(clickPoint, self.enclosingScrollView!.frame, self.enclosingScrollView!.isFlipped)
        {
            if clickPoint.x < viewSplit
            {
                if event.modifierFlags.contains(.option)
                {
                    NSApp.sendAction(#selector(TSSTSessionWindowController.shiftPageLeft(_:)), to: nil, from: self)
                }
                else
                {
                    NSApp.sendAction(#selector(TSSTSessionWindowController.pageLeft(_:)), to: nil, from: self)
                }
            }
            else
            {
                if event.modifierFlags.contains(.option)
                {
                    NSApp.sendAction(#selector(TSSTSessionWindowController.shiftPageRight(_:)), to: nil, from: self)
                }
                else
                {
                    NSApp.sendAction(#selector(TSSTSessionWindowController.pageRight(_:)), to: nil, from: self)
                }
            }
        }
    }
    
    override func swipe(with event: NSEvent) {
        if event.deltaX > 0.0
        {
            sessionController!.pageLeft(self)
        }
        else if event.deltaX < 0.0
        {
            sessionController!.pageRight(self)
        }
    }
    
    static var nextValidLeft: TimeInterval = -1;
    static var nextValidRight: TimeInterval = -1;
    
    override func rotate(with event: NSEvent) {
        // Prevent more than one rotation in the same direction per second
        if event.rotation > 0.5 && event.timestamp > PageView.nextValidRight
        {
            sessionController!.rotateLeft(self)
            PageView.nextValidRight = event.timestamp + 0.75
        }
        else if event.rotation < -0.5 && event.timestamp > PageView.nextValidLeft
        {
            sessionController!.rotateRight(self)
            PageView.nextValidLeft = event.timestamp + 0.75;
        }
    }
    
    override func magnify(with event: NSEvent) {
        let session = sessionController!.session()
        let scalingOption = session!.scaleOptions!.intValue
        var previousZoom = CGFloat(session!.zoomLevel!.floatValue)
        
        if scalingOption != 0
        {
            previousZoom = NSWidth(self.imageBounds) / self.combinedImageSize(forZoom: 1).width
        }
        
        previousZoom += event.magnification * 2;
        previousZoom = previousZoom < 5 ? previousZoom : 5;
        previousZoom = previousZoom > 0.25 ? previousZoom : 0.25;
        session!.zoomLevel = previousZoom as NSNumber
        session!.scaleOptions = 0
        
        self.resizeView()
    }
    
    var dragIsPossible: Bool {
        return
            self.horizontalScrollIsPossible ||
                self.verticalScrollIsPossible &&
                !sessionController!.pageSelectionInProgress()
    }
    
    var horizontalScrollIsPossible: Bool {
        let total = imageBounds.size;
        let visible = self.enclosingScrollView!.documentVisibleRect.size
        return visible.width < round(total.width)
    }
    
    var verticalScrollIsPossible: Bool {
        let total = imageBounds.size
        let visible = self.enclosingScrollView!.documentVisibleRect.size
        return visible.height < round(total.height)
    }
    
    override func resetCursorRects() {
        if self.dragIsPossible
        {
            self.addCursorRect(self.enclosingScrollView!.documentVisibleRect, cursor: NSCursor.openHand);
        }
        else
        {
            super.resetCursorRects();
        }
    }
}
