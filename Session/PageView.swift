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

class PageView: NSView, CALayerDelegate {
    enum Side: Int {
        case left = 0
        case right = 1
    }
    
    struct ArrowFlags: OptionSet {
        let rawValue: Int
        
        static let up = ArrowFlags(rawValue: 1 << 0)
        static let down = ArrowFlags(rawValue: 1 << 1)
        static let left = ArrowFlags(rawValue: 1 << 2)
        static let right = ArrowFlags(rawValue: 1 << 3)
        
        init(rawValue: Int) {
            self.rawValue = rawValue
        }
        
        init(rawValues: [Int]) {
            self.rawValue = rawValues.reduce(0) { $0 | (1 << $1) }
        }
    }
    
    @objc var imageBounds: NSRect = NSZeroRect
    
    var firstPage: CALayer = CALayer.init()
    var secondPage: CALayer = CALayer.init()
    var overlayLayer: CALayer = CALayer.init()
    private var firstPageImage: NSImage?
    private var secondPageImage: NSImage?
    var firstImageSize: NSSize?
    var secondImageSize: NSSize?
    var firstPageSource: CGImageSource?
    var secondPageSource: CGImageSource?
    var isTwoPageSpreaded: Bool { secondImageSize != nil }
    
    // Stores which arrow keys are currently depressed this enables multi axis keyboard scrolling.
    var scrollKeys: ArrowFlags = []
    // Timer that fires in between each keydown event to smooth out the scrolling.
    var scrollTimer: Timer? = nil
    var interfaceDelay: NSDate?
    
    var rotation: OrthogonalRotation = .r0_4 {
        didSet {
            self.resizeView()
            self.updateRotation()
        }
    }
    
    @objc dynamic var rotationValue: Int = OrthogonalRotation.r0_4.rawValue
        {
        didSet { rotation = OrthogonalRotation.init(rawValue: rotationValue)! }
    }
    
    @IBOutlet @objc var sessionController: SessionWindowController!
    
    
    /*    While page selection is in progress this method has a value.
     The selection number coresponds to a highlighted page. */
    var pageSelection: Side? = nil
    /* This is the rect describing the users page selection. */
    var cropRect: NSRect = NSZeroRect
    
    override func awakeFromNib() {
        /* Doing this so users can drag archives into the view. */
        self.registerForDraggedTypes([.fileURL])
        
        self.layer = CALayer.init()
        self.layer!.sublayers = [self.firstPage, self.secondPage, self.overlayLayer]
        self.firstPage.actions = ["contents": NSNull(), "bounds": NSNull(), "position": NSNull(), "transform": NSNull()]
        self.secondPage.actions = ["contents": NSNull(), "bounds": NSNull(), "position": NSNull(), "transform": NSNull()]
        
        if BuildConfiguration.current == .debug {
            self.firstPage.borderColor = CGColor.init(red: 1.0, green: 0.0, blue: 0.0, alpha: 0.5)
            self.firstPage.borderWidth = 2
            self.secondPage.borderColor = CGColor.init(red: 0.0, green: 0.0, blue: 1.0, alpha: 0.5)
            self.secondPage.borderWidth = 2
        }
    }
    
    deinit {
        scrollTimer?.invalidate()
    }
    
    override var acceptsFirstResponder: Bool { true }
    
    func setFirstPage(_ first: NSImage, secondPageImage second: NSImage?) {
        scrollKeys = []
        
        firstPageImage = first
        firstImageSize = first.size
        secondPageImage = second
        secondImageSize = second?.size
        
        self.resizeView()
    }
    
    @objc func setSource(first: CGImageSource, _ firstSize: NSSize, second: CGImageSource?, _ secondSize: NSSize) {
        assert(CGImageSourceGetCount(first) > 0)
        assert(second == nil || CGImageSourceGetCount(second!) > 0)
        
        firstPageSource = first
        secondPageSource = second
        let img = second != nil ? NSImage.init(cgImage: CGImageSourceCreateImageAtIndex(second!, 0, nil)!, size: secondSize) : nil
        setFirstPage(NSImage.init(cgImage: CGImageSourceCreateImageAtIndex(first, 0, nil)!, size: firstSize),
                     secondPageImage: img)
        
        if self.firstPageSource != nil
        {
            firstPage.contents = CGImageSourceCreateImageAtIndex(first, 0, nil)
            self.startAnimation(forImage: self.firstPageSource!)
        }
        
        if self.secondPageSource != nil
        {
            secondPage.contents = CGImageSourceCreateImageAtIndex(second!, 0, nil)
            self.startAnimation(forImage: self.secondPageSource!)
        }
    }
    
    // MARK: - Animations
    
    func startAnimation(forImage image: CGImageSource)
    {
        let numFrames = CGImageSourceGetCount(image)
        guard numFrames > 1 else { return }
        guard CGImageSourceCreateImageAtIndex(image, 0, nil) != nil else { return }
        
        let properties = CGImageSourceCopyPropertiesAtIndex(image, 0, nil) as! [CFString : Any]
        
        let layer = CALayer.init()
        self.layer = layer
        
        var duration: CFTimeInterval = 0.0
        for i in 0 ..< numFrames {
            let props = CGImageSourceCopyPropertiesAtIndex(image, i, nil) as! [CFString : Any]
            let frameDuration = (props[kCGImagePropertyGIFUnclampedDelayTime] as! NSNumber?)?.doubleValue ?? 0.1
            duration += frameDuration
        }
        
        let anim = CAKeyframeAnimation.init(keyPath: "contents")
        anim.duration = duration
        anim.calculationMode = .discrete
        anim.values = []
        anim.keyTimes = []
        anim.timingFunctions = []
        
        var elapsedSeconds: CFTimeInterval = 0.0
        for i in 0 ..< numFrames {
            let props = CGImageSourceCopyPropertiesAtIndex(image, i, nil) as! [CFString : Any]
            let frameDuration = (props[kCGImagePropertyGIFUnclampedDelayTime] as! NSNumber?)?.doubleValue ?? 0.1
            anim.values!.append(CGImageSourceCreateImageAtIndex(image, i, nil) as Any)
            anim.keyTimes!.append((elapsedSeconds / duration) as NSNumber)
            anim.timingFunctions!.append(CAMediaTimingFunction.init(name: CAMediaTimingFunctionName.linear))
            elapsedSeconds += frameDuration
        }
        anim.keyTimes?.append(1.0)
        anim.repeatCount = (properties[kCGImagePropertyGIFLoopCount] as! NSNumber?)?.floatValue ?? .greatestFiniteMagnitude
        layer.add(anim, forKey: "contents")
    }
    
    // MARK: - Drag and Drop
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let pboard = sender.draggingPasteboard
        if pboard.types?.contains(.fileURL) ?? false
        {
            self.needsDisplay = true
            self.overlayLayer.borderWidth = 6
            self.overlayLayer.borderColor = NSColor.keyboardFocusIndicatorColor.cgColor
            self.overlayLayer.backgroundColor = CGColor(gray: 0.0, alpha: 0.2)
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
        self.needsDisplay = true
        self.overlayLayer.borderWidth = 0
        self.overlayLayer.backgroundColor = CGColor.clear
    }
    
    override func draggingEnded(_ sender: NSDraggingInfo) {
        self.needsDisplay = true
        self.overlayLayer.borderWidth = 0
        self.overlayLayer.backgroundColor = CGColor.clear
    }
    
    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        self.needsDisplay = true
        self.overlayLayer.borderWidth = 0
        self.overlayLayer.backgroundColor = CGColor.clear
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        sender.enumerateDraggingItems(options: [],
                                      for: self,
                                      classes: [NSURL.self],
                                      searchOptions: [:]) { (item, _, _) in
                                        switch item.item {
                                        case let url as URL:
                                            self.sessionController.updateSessionObject()
                                            self.sessionController.session?.addFile(atURL: url)
                                        default:
                                            break
                                        }
        }
        return true
    }
    
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pboard = sender.draggingPasteboard
        return pboard.types?.contains(.fileURL) ?? false
    }
    
    // MARK: - Drawing
    
    func draw(_ layer: CALayer, in ctx: CGContext) {
        NSGraphicsContext.current = NSGraphicsContext.init(cgContext: ctx, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        self.rotationTransform(frame: self.frame)
        let interpolation = (self.inLiveResize || !scrollKeys.isEmpty) ? NSImageInterpolation.low : NSImageInterpolation.high
        NSGraphicsContext.current?.imageInterpolation = interpolation
        
        NSColor.init(calibratedWhite: 0.2, alpha: 0.5).set()
        
        let highlight: NSBezierPath
        if self.cropRect != NSZeroRect
        {
            let selection: NSRect
            if self.pageSelection == .left
            {
                selection = rectFromNegativeRect(self.cropRect).intersection(self.firstPage.frame)
            }
            else
            {
                selection = rectFromNegativeRect(self.cropRect).intersection(self.secondPage.frame)
            }
            
            highlight = NSBezierPath.init(rect: selection)
            highlight.fill()
            NSColor.init(calibratedWhite: 1.0, alpha: 0.8).set()
            NSBezierPath.defaultLineWidth = 2.0
            NSBezierPath.stroke(selection)
        }
        else if self.pageSelection == .left
        {
            highlight = NSBezierPath.init(rect: self.firstPage.frame)
            highlight.fill()
        }
        else if self.pageSelection == .right
        {
            highlight = NSBezierPath.init(rect: self.secondPage.frame)
            highlight.fill()
        }
        
        NSColor.init(calibratedWhite: 0.2, alpha: 0.8).set()
        
        if sessionController.pageSelectionInProgress()
        {
            let style = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
            style.alignment = .center
            let stringAttributes = [
                NSAttributedString.Key.font: NSFont.init(name: "Lucida Grande", size: 24)!,
                NSAttributedString.Key.foregroundColor: NSColor.init(calibratedWhite: 1.0, alpha: 1.0),
                NSAttributedString.Key.paragraphStyle: style
            ]
            var selectionText: NSString = "Click to select page"
            if self.sessionController.pageSelectionCanCrop()
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
    }
    
    fileprivate func calcFragment(center: CGPoint, size: CGSize, scale: CGFloat) -> CGRect {
        let power: CGFloat = CGFloat((UserDefaults.standard.value(forKey: TSSTLoupePower) as! NSNumber?)?.floatValue ?? 0.0)
        let zoomSize = size.scaleBy(1.0 / (power * scale))
        return NSRect.init(x: center.x / scale - zoomSize.width / 2,
                          y: center.y / scale - zoomSize.height / 2,
                          width: zoomSize.width,
                          height: zoomSize.height)
    }
    
    fileprivate func convertBoundsToFrameParts(bounds size: CGSize, left: CGSize, right: CGSize?, into rect: CGRect) -> (CGRect, CGRect) {
        let fst = calcFragment(center: rect.origin,
                               size: rect.size,
                               scale: size.height / left.height)
        let remainder = fst.maxX - left.width
        
        guard remainder > 0 else { return (fst, NSRect.zero) }
        guard let img = right else { return (fst, NSRect.zero) }
        
        let snd = calcFragment(center: CGPoint.init(x: rect.origin.x - left.width * size.height / left.height, y: rect.origin.y),
                               size: rect.size,
                               scale: size.height / img.height)
        
        return (fst, snd)
    }
    
    @objc func image(inRect _rect: NSRect) -> NSImage?
    {
        guard self.firstPageImage?.isValid ?? false else { return nil }
        
        var size = imageBounds.size
        var rect = _rect
        /* Re-orients the rectangle based on the current page rotation */
        switch rotation {
        case .r0_4:
            rect.origin = rect.offsetBy(dx: -imageBounds.minX, dy: -imageBounds.minY).origin
        case .r1_4:
            rect.origin = NSMakePoint(rect.minY - imageBounds.minY, imageBounds.maxX - rect.minX);
            size.width = NSHeight(imageBounds);
            size.height = NSWidth(imageBounds);
        case .r2_4:
            rect.origin = NSMakePoint(NSMaxX(imageBounds) - NSMinX(rect), NSMaxY(imageBounds) - NSMinY(rect));
        case .r3_4:
            rect.origin = NSMakePoint(imageBounds.maxY - rect.minY, rect.minX - imageBounds.minX);
            size.width = NSHeight(imageBounds);
            size.height = NSWidth(imageBounds);
        }
        
        let firstRect: CGRect
        let secondRect: CGRect
        if (sessionController.session?.pageOrder!.boolValue)! || !(secondPageImage?.isValid ?? false)
        {
            (firstRect, secondRect) = convertBoundsToFrameParts(bounds: size, left: firstImageSize!, right: secondImageSize, into: rect)
        }
        else
        {
            (secondRect, firstRect) = convertBoundsToFrameParts(bounds: size, left: secondImageSize!, right: firstImageSize, into: rect)
        }
        
        let imageFragment = NSImage.init(size: rect.size)
        imageFragment.lockFocus()
        self.rotationTransform(frame: NSRect.init(origin: CGPoint.zero, size: rect.size))
        
        if firstRect != NSZeroRect
        {
            firstPageImage?.draw(in: NSRect.init(origin: CGPoint.zero, size: rect.size),
                                 from: firstRect,
                                 operation: .sourceOver,
                                 fraction: 1.0)
        }
        
        if secondRect != NSZeroRect
        {
            secondPageImage?.draw(in: NSRect.init(origin: CGPoint.zero, size: rect.size),
                                  from: secondRect,
                                  operation: .sourceOver,
                                  fraction: 1.0)
        }
        
        imageFragment.unlockFocus()
        return imageFragment
    }
    
    // MARK: - Geometry handling
    
    func updateRotation() {
        let transform: CATransform3D
        switch rotation {
        case .r0_4:
            transform = CATransform3DIdentity
        case .r1_4:
            transform = CATransform3DMakeRotation(.pi / 2, 0, 0, 1)
        case .r2_4:
            transform = CATransform3DMakeRotation(.pi, 0, 0, 1)
        case .r3_4:
            transform = CATransform3DMakeRotation(-.pi / 2, 0, 0, 1)
        }
        
        firstPage.transform = transform
        secondPage.transform = transform
    }
    
    func rotationTransform(frame: NSRect)
    {
        let transform = NSAffineTransform.init()
        switch rotation {
        case .r0_4:
            break
        case .r3_4:
            transform.rotate(byDegrees: 270)
            transform.translateX(by: -frame.height, yBy: 0)
        case .r2_4:
            transform.rotate(byDegrees: 180)
            transform.translateX(by: -frame.width, yBy: -frame.height)
        case .r1_4:
            transform.rotate(byDegrees: 90)
            transform.translateX(by: 0, yBy: -frame.width)
        }
        transform.concat()
    }
    
    @objc func correctViewPoint()
    {
        var correctOrigin = NSZeroPoint
        let frameSize = self.frame.size
        let viewSize = self.enclosingScrollView!.documentVisibleRect.size
        
        guard frameSize != NSZeroSize else { return }
        
        if sessionController.pageTurn == .left
        {
            correctOrigin.x = frameSize.width > viewSize.width ? (frameSize.width - viewSize.width) : 0
        }
        
        correctOrigin.y = (frameSize.height > viewSize.height) ? (frameSize.height - viewSize.height) : 0
        
        let scrollView = self.enclosingScrollView
        let clipView = scrollView!.contentView
        clipView.scroll(to: correctOrigin)
        scrollView?.reflectScrolledClipView(clipView)
    }
    
    func combinedImageSize() -> CGSize {
        guard firstImageSize != nil || secondImageSize != nil else { return CGSize.zero }
        let firstSize = firstImageSize ?? CGSize.zero
        let secondSize = secondImageSize ?? CGSize.zero
        
        let height = max(firstSize.height, secondSize.height)
        let width = firstSize.scaleTo(height: height).width + secondSize.scaleTo(height: height).width
        let result = CGSize.init(width: width, height: height)
        
        return (rotation == .r3_4 || rotation == .r1_4) ?
            result.transposed : result
    }
    
    @objc func combinedImageSize(forZoom zoom: CGFloat) -> NSSize
    {
        return combinedImageSize().scaleBy(zoom)
    }
    
    fileprivate func calcViewSize(_ imageSize: NSSize, _ visibleRect: NSRect) -> CGSize {
        var viewSize: CGSize = CGSize.zero
        var scaling = sessionController.session?.adjustmentMode ?? .none
        scaling = sessionController.currentPageIsText() ? .fitToWidth : scaling
        switch (scaling)
        {
        case .none:
            viewSize.width = max(imageSize.width, visibleRect.width)
            viewSize.height = max(imageSize.height, visibleRect.height)
        case .fitToWindow:
            viewSize = visibleRect.size
        case .fitToWidth:
            var scaleToFit: CGFloat
            if(rotation == .r3_4 || rotation == .r1_4)
            {
                scaleToFit = visibleRect.height / imageSize.height;
            }
            else
            {
                scaleToFit = visibleRect.width / imageSize.width;
            }
            
            if UserDefaults.standard.isImageScaleConstrained
            {
                scaleToFit = min(scaleToFit, 1)
            }
            
            let s = imageSize.scaleBy(scaleToFit)
            viewSize.width = max(s.width, visibleRect.width)
            viewSize.height = max(s.height, visibleRect.height)
        }
        
        return viewSize
    }
    
    @objc func resizeView() {
        self.firstPage.frame = NSZeroRect
        self.secondPage.frame = NSZeroRect
        let visibleRect = self.enclosingScrollView!.documentVisibleRect
        let frameRect = self.frame
        
        
        var imageSize = self.combinedImageSize().scaleBy(CGFloat(sessionController.session?.zoomLevel?.floatValue ?? 1.0))
        let viewSize = calcViewSize(imageSize, visibleRect)
        self.frame.size = viewSize
        
        if !UserDefaults.standard.isImageScaleConstrained &&
            sessionController.session!.adjustmentMode != .none
        {
            if( viewSize.width / viewSize.height < imageSize.width / imageSize.height)
            {
                imageSize = imageSize.scaleTo(width: viewSize.width)
            }
            else
            {
                imageSize = imageSize.scaleTo(height: viewSize.height)
            }
        }
        
        imageBounds = rectWithSizeCenteredInRect(imageSize, NSMakeRect(0,0,viewSize.width, viewSize.height));
        let imageRect: CGRect
        if rotation == .r3_4 || rotation == .r1_4
        {
            imageRect = rectWithSizeCenteredInRect(imageBounds.size,
                                                   NSRect.init(origin: CGPoint.zero, size: self.frame.size))
        }
        else
        {
            imageRect = imageBounds
        }
        
        if isTwoPageSpreaded
        {
            switch rotation
            {
            case .r0_4:
                fallthrough
            case .r2_4:
                let size = CGSize.init(width: imageRect.width / 2, height: imageRect.height)
                self.firstPage.frame.size = size
                self.secondPage.frame.size = size
            case .r1_4:
                fallthrough
            case .r3_4:
                let size = CGSize.init(width: imageRect.width, height: imageRect.height / 2)
                self.firstPage.frame.size = size
                self.secondPage.frame.size = size
            }
        }
        else
        {
            self.firstPage.frame.size = imageRect.size
        }
        
        if isTwoPageSpreaded
        {
            let reversed = !(sessionController.session?.pageOrder?.boolValue ?? false)
            let fst: CALayer = reversed ? self.secondPage : self.firstPage
            let snd: CALayer = reversed ? self.firstPage : self.secondPage
            
            switch rotation
            {
            case .r0_4:
                fst.frame.origin = imageRect.origin;
                snd.frame.origin = NSMakePoint(fst.frame.maxX, imageRect.minY);
            case .r1_4:
                fst.frame.origin = imageRect.origin;
                snd.frame.origin = NSMakePoint(imageRect.minX, fst.frame.maxY);
            case .r2_4:
                snd.frame.origin = imageRect.origin;
                fst.frame.origin = NSMakePoint(snd.frame.maxX, imageRect.minY);
            case .r3_4:
                snd.frame.origin = imageRect.origin;
                fst.frame.origin = NSMakePoint(imageRect.minX, snd.frame.maxY);
            }
        }
        else
        {
            self.firstPage.frame.origin = imageRect.origin;
        }
        
        let xratio = (frameRect.size.width > 0) ? (visibleRect.midX / frameRect.size.width) : 1.0
        let yratio = (frameRect.size.height > 0) ? (visibleRect.midY / frameRect.size.height) : 1.0
        let origin = CGPoint.init(x: viewSize.width * xratio, y: viewSize.height * yratio)
        let rect = CGRect.init(origin: origin, size: visibleRect.size)
        self.scroll(rect.center)
        self.needsDisplay = true
        self.overlayLayer.frame = self.bounds
        self.overlayLayer.setNeedsDisplay()
    }
    
    func pageSelectionRect(selection: Side) -> NSRect
    {
        if !(secondPageImage?.isValid ?? false)
        {
            return selection == .left ? self.bounds : NSZeroRect
        }
        
        let left2right = sessionController.session!.pageOrder!.boolValue
        let pages = left2right ? [self.firstPage.frame, self.secondPage.frame] : [self.secondPage.frame, self.firstPage.frame]
        let leftSelected = (left2right && selection == .left) || (!left2right && selection == .right)
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
        
        let selection = (pageSelection == .left) ?
            rectFromNegativeRect(cropRect).intersection(self.firstPage.frame) :
            rectFromNegativeRect(cropRect).intersection(self.secondPage.frame)
        
        let center = centerPointOfRect(selection)
        var pageRect = NSZeroRect
        let originalSize: NSSize
        
        if self.firstPage.hitTest(center) != nil
        {
            pageRect = self.firstPage.frame
            originalSize = firstImageSize!
        }
        else if self.secondPage.hitTest(center) != nil
        {
            pageRect = self.secondPage.frame
            originalSize = secondImageSize!
        }
        else
        {
            return NSZeroRect
        }
        
        pageRect.origin = selection.offsetBy(dx: -pageRect.origin.x, dy: -pageRect.origin.y).origin
        let scaling = originalSize.height / pageRect.size.height;
        return NSRect.init(x: pageRect.origin.x * scaling,
                           y: pageRect.origin.y * scaling,
                           width: selection.size.width * scaling,
                           height: selection.size.height * scaling)
    }
    
    // MARK: - Event handling
    
    override func scrollWheel(with event: NSEvent) {
        guard !sessionController.pageSelectionInProgress() else
        {
            return
        }
        
        let modifier = event.modifierFlags
        var scaling = sessionController.session!.adjustmentMode
        scaling = sessionController.currentPageIsText() ? .fitToWidth : scaling
        
        if modifier.contains(.command) && event.deltaY != 0
        {
            var loupeDiameter = (UserDefaults.standard.value(forKey: TSSTLoupeDiameter)! as! NSNumber).intValue
            loupeDiameter += event.deltaY > 0 ? 30 : -30;
            UserDefaults.standard.setValue(loupeDiameter.clamp(150 ... 500), forKey: TSSTLoupeDiameter)
        }
        else if modifier.contains(.option) && event.deltaY != 0
        {
            var loupePower = (UserDefaults.standard.value(forKey: TSSTLoupePower)! as! NSNumber).intValue
            loupePower += event.deltaY > 0 ? 1 : -1;
            UserDefaults.standard.setValue(loupePower.clamp(2 ... 6), forKey: TSSTLoupePower)
        }
        else if(scaling == .fitToWindow)
        {
            let deltaX = event.deltaX
            if deltaX != 0.0
            {
                event.trackSwipeEvent(options: .lockDirection, dampenAmountThresholdMin: -1.0, max: 1.0) { (_, _, _, _) in
                }
            }
            
            
            if (deltaX > 0.0)
            {
                sessionController.pageLeft(self)
            }
            else if (deltaX < 0.0)
            {
                sessionController.pageRight(self)
            }
            
        }
        else
        {
            let visible = self.enclosingScrollView!.documentVisibleRect
            let scrollPoint = NSMakePoint(NSMinX(visible) - (event.deltaX * 5), NSMinY(visible) + (event.deltaY * 5));
            self.scroll(scrollPoint)
        }
        
        sessionController.refreshLoupePanel()
    }
    
    override func keyDown(with event: NSEvent) {
        if sessionController.pageSelectionInProgress()
        {
            sessionController.cancelPageSelection()
            pageSelection = nil
            cropRect = NSZeroRect
            self.needsDisplay = true
            self.overlayLayer.setNeedsDisplay()
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
                sessionController.turnPage(to: .prev)
            }
            else
            {
                scrollKeys = scrollKeys.union(.up)
                scrollPoint.y += delta
                scrolling = true
            }
            break;
        case NSDownArrowFunctionKey:
            if !self.verticalScrollIsPossible
            {
                sessionController.turnPage(to: .next)
            }
            else
            {
                scrollKeys = scrollKeys.union(.down)
                scrollPoint.y -= delta
                scrolling = true
            }
            break;
        case NSLeftArrowFunctionKey:
            if !self.horizontalScrollIsPossible
            {
                sessionController.pageLeft(self)
            }
            else
            {
                scrollKeys = scrollKeys.union(.left)
                scrollPoint.x -= delta
                scrolling = true;
            }
            break;
        case NSRightArrowFunctionKey:
            if !self.horizontalScrollIsPossible
            {
                sessionController.pageRight(self)
            }
            else
            {
                scrollKeys = scrollKeys.union(.right)
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
            sessionController.killTopOptionalUIElement()
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
            sessionController.refreshLoupePanel()
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
        
        if self.bounds.maxY <= visible.maxY
        {
            if sessionController.session!.pageOrder!.boolValue
            {
                if visible.minX > 0
                {
                    self.scroll(NSPoint.init(x: visible.minX - visible.width, y: 0))
                }
                else
                {
                    sessionController.pageTurn = .left
                    sessionController.turnPage(to: .prev)
                }
            }
            else
            {
                if visible.maxX < self.bounds.width
                {
                    self.scroll(NSPoint.init(x: visible.maxX, y: 0))
                }
                else
                {
                    sessionController.pageTurn = .right
                    sessionController.turnPage(to: .prev)
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
        var scrollPoint = visible.origin
        
        if scrollPoint.y <= 0
        {
            if sessionController.session!.pageOrder!.boolValue
            {
                if visible.maxX < self.bounds.width
                {
                    self.scroll(NSPoint.init(x: visible.maxX, y: self.bounds.height - visible.height))
                }
                else
                {
                    sessionController.pageTurn =  .right
                    sessionController.turnPage(to: .next)
                }
            }
            else
            {
                if visible.minX > 0
                {
                    self.scroll(NSPoint.init(x: visible.minX - visible.width, y: self.bounds.height - visible.height))
                }
                else
                {
                    sessionController.pageTurn = .left
                    sessionController.turnPage(to: .next)
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
            scrollKeys = scrollKeys.subtracting(.up)
        case NSDownArrowFunctionKey:
            scrollKeys = scrollKeys.subtracting(.down)
        case NSLeftArrowFunctionKey:
            scrollKeys = scrollKeys.subtracting(.left)
        case NSRightArrowFunctionKey:
            scrollKeys = scrollKeys.subtracting(.right)
        default:
            break;
        }
    }
    
    override func flagsChanged(with event: NSEvent) {
        if event.type == NSEvent.EventType.keyDown && event.modifierFlags.contains(.command)
        {
            scrollKeys = []
        }
    }
    
    @objc func scroll(timer: Timer) {
        if scrollKeys.isEmpty
        {
            scrollTimer?.invalidate()
            scrollTimer = nil;
            // This is to reset the interpolation.
            self.needsDisplay = true
            self.overlayLayer.setNeedsDisplay()
            return
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
        var turn: Side? = nil
        var directionString: NSString? = nil
        let turnDirection = sessionController.session!.pageOrder?.boolValue
        var finishTurn = false
        if scrollKeys.contains(.up)
        {
            scrollPoint.y += delta;
            if(NSMaxY(visible) >= NSMaxY(self.frame) && pageTurnAllowed)
            {
                turn = turnDirection! ? .left : .right
            }
        }
        
        if scrollKeys.contains(.down)
        {
            scrollPoint.y -= delta;
            if(scrollPoint.y <= 0 && pageTurnAllowed)
            {
                turn = turnDirection! ? .right : .left
            }
        }
        
        if scrollKeys.contains(.left)
        {
            scrollPoint.x -= delta;
            if(scrollPoint.x <= 0 && pageTurnAllowed)
            {
                turn = .left;
            }
        }
        
        if scrollKeys.contains(.right)
        {
            scrollPoint.x += delta;
            if(NSMaxX(visible) >= NSMaxX(self.frame) && pageTurnAllowed)
            {
                turn = .right;
            }
        }
        
        if let t = turn
        {
            var difference = 0;
            
            if t == .right
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
                if t == .left
                {
                    sessionController.pageLeft(self)
                }
                else if t == .right
                {
                    sessionController.pageRight(self)
                }
                finishTurn = true
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
        
        sessionController.refreshLoupePanel()
    }
    
    override func rightMouseDown(with event: NSEvent) {
        let loupe = sessionController.session!.loupe!.boolValue
        sessionController.session!.loupe = !loupe as NSNumber
    }
    
    override func mouseDown(with event: NSEvent) {
        if sessionController.pageSelectionInProgress() {
            let cursor = self.convert(event.locationInWindow, from: nil)
            cropRect.origin = cursor;
        }
        else if self.dragIsPossible
        {
            NSCursor.closedHand.set()
        }
    }
    
    override func mouseMoved(with event: NSEvent) {
        guard sessionController.pageSelectionInProgress() else {
            super.mouseMoved(with: event)
            return
        }
        
        let cursor = self.convert(event.locationInWindow, from: nil)
        if sessionController.canSelectPageIndex(Side.left.rawValue) && self.firstPage.frame.contains(cursor)
        {
            pageSelection = .left
        }
        else if sessionController.canSelectPageIndex(Side.right.rawValue) && self.secondPage.frame.contains(cursor)
        {
            pageSelection = .right
        }
        else
        {
            pageSelection = nil
        }
        self.needsDisplay = true
        self.overlayLayer.setNeedsDisplay()
    }
    
    override func mouseDragged(with event: NSEvent) {
        let viewOrigin = self.enclosingScrollView!.documentVisibleRect.origin
        var cursor = event.locationInWindow
        var currentPoint: NSPoint
        if sessionController.pageSelectionInProgress()
        {
            cursor = self.convert(cursor, from: nil)
            cropRect.size.width = cursor.x - cropRect.origin.x;
            cropRect.size.height = cursor.y - cropRect.origin.y;
            if self.pageSelectionRect(selection: .left).contains(cropRect.origin)
            {
                pageSelection = .left
            }
            else if self.pageSelectionRect(selection: .right).contains(cropRect.origin)
            {
                pageSelection = .right
            }
            self.needsDisplay = true
            self.overlayLayer.setNeedsDisplay()
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
                    sessionController.refreshLoupePanel()
                }
                e = (self.window?.nextEvent(matching: [.leftMouseUp, .leftMouseDragged]))!
            }
            self.window?.invalidateCursorRects(for: self)
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        if sessionController.pageSelectionInProgress()
        {
            sessionController.selectedPage(pageSelection?.rawValue ?? -1, withCropRect: self.imageCropRectangle())
            pageSelection = nil
            cropRect = NSZeroRect;
            
            self.needsDisplay = true
            self.overlayLayer.setNeedsDisplay()
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
                    NSApp.sendAction(#selector(SessionWindowController.shiftPageLeft(_:)), to: nil, from: self)
                }
                else
                {
                    NSApp.sendAction(#selector(SessionWindowController.pageLeft(_:)), to: nil, from: self)
                }
            }
            else
            {
                if event.modifierFlags.contains(.option)
                {
                    NSApp.sendAction(#selector(SessionWindowController.shiftPageRight(_:)), to: nil, from: self)
                }
                else
                {
                    NSApp.sendAction(#selector(SessionWindowController.pageRight(_:)), to: nil, from: self)
                }
            }
        }
    }
    
    override func swipe(with event: NSEvent) {
        if event.deltaX > 0.0
        {
            sessionController.pageLeft(self)
        }
        else if event.deltaX < 0.0
        {
            sessionController.pageRight(self)
        }
    }
    
    static var nextValidLeft: TimeInterval = -1;
    static var nextValidRight: TimeInterval = -1;
    
    override func rotate(with event: NSEvent) {
        // Prevent more than one rotation in the same direction per second
        if event.rotation > 0.5 && event.timestamp > PageView.nextValidRight
        {
            sessionController.rotateLeft(self)
            PageView.nextValidRight = event.timestamp + 0.75
        }
        else if event.rotation < -0.5 && event.timestamp > PageView.nextValidLeft
        {
            sessionController.rotateRight(self)
            PageView.nextValidLeft = event.timestamp + 0.75;
        }
    }
    
    override func magnify(with event: NSEvent) {
        let session = sessionController.session
        var previousZoom = CGFloat(session!.zoomLevel!.floatValue)
        
        if session!.adjustmentMode != .none
        {
            previousZoom = self.imageBounds.width / self.combinedImageSize(forZoom: 1).width
        }
        
        previousZoom += event.magnification * 2;
        previousZoom = previousZoom < 5 ? previousZoom : 5;
        previousZoom = previousZoom > 0.25 ? previousZoom : 0.25;
        session!.zoomLevel = previousZoom as NSNumber
        session!.adjustmentMode = .none
        
        self.resizeView()
    }
    
    var dragIsPossible: Bool {
        return
            self.horizontalScrollIsPossible ||
                self.verticalScrollIsPossible &&
                !sessionController.pageSelectionInProgress()
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

extension CGRect {
    fileprivate var center: CGPoint {
        CGPoint.init(x: midX, y: midY)
    }
}

extension UserDefaults {
    // If true a page scale is constrained by its resolution.
    var isImageScaleConstrained: Bool {
        return UserDefaults.standard.bool(forKey: TSSTConstrainScale)
    }
}

enum OrthogonalRotation: Int {
    case r0_4 = 0
    case r1_4 = 3
    case r2_4 = 2
    case r3_4 = 1
    static let r4_4 = r0_4
}

func * (lhs: OrthogonalRotation, rhs: OrthogonalRotation) -> OrthogonalRotation {
    return OrthogonalRotation.init(rawValue: (lhs.rawValue + rhs.rawValue) % 4)!
}