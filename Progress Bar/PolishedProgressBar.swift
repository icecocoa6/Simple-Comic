/*
 Copyright (c) 2006-2009 Dancing Tortoise Software
 Original version is created by Alexander Rauchfuss
 
 Permission is hereby granted, free of charge, to any person
 obtaining a copy of this software and associated documentation
 files (the "Software"), to deal in the Software without
 restriction, including without limitation the rights to use,
 copy, modify, merge, publish, distribute, sublicense, and/or
 sell copies of the Software, and to permit persons to whom the
 Software is furnished to do so, subject to the following
 conditions:
 
 The above copyright notice and this permission notice shall be
 included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 OTHER DEALINGS IN THE SOFTWARE.
 
 Ported by Tomioka Taichi on 2020/03/22.
 
 PolishedProgressBar.swift
*/

import Cocoa

class PolishedProgressBar: NSView {
    /* The maximum value of the progress bar. */
    @objc dynamic var maxValue: Int = 1 {
        didSet {
            assert(maxValue > 0)
            self.needsDisplay = true
        }
    }

    /* The progress bar is filled to this level. */
    @objc dynamic var currentValue: Int = 0 {
        didSet {
            self.needsDisplay = true
        }
    }

    /* The direction of the porgress bar. */
    @objc dynamic var leftToRight: Bool = true {
        didSet {
            self.needsDisplay = true
        }
    }

    /* This is the section of the view. Users can mouse over and click here. */
    @objc var progressRect: NSRect = NSZeroRect

    /* How much room is given for the text on either side. */
    let horizontalMargin: CGFloat = 35

    let cornerRadius: CGFloat = 4.0

    /* This is the color of the unfilled bar. */
    let emptyGradient: NSGradient = NSGradient.init(colorsAndLocations: (NSColor.init(deviceWhite: 0.25, alpha: 1), 0.0), (NSColor.init(deviceWhite: 0.45, alpha: 1), 1.0))!
    /* The color of the filled bar. */
    let barGradient: NSGradient = NSGradient.init(colorsAndLocations: (NSColor.init(deviceWhite: 0.7, alpha: 1), 0.0),
                                                  (NSColor.init(deviceWhite: 0.75, alpha: 1), 0.5),
                                                  (NSColor.init(deviceWhite: 0.82, alpha: 1), 0.5),
                                                  (NSColor.init(deviceWhite: 0.92, alpha: 1), 1.0))!
    let shadowGradient: NSGradient = NSGradient.init(colorsAndLocations: (NSColor.init(deviceWhite: 0.3, alpha: 1), 0.0),
                                                     (NSColor.init(deviceWhite: 0.25, alpha: 1), 0.55),
                                                     (NSColor.init(deviceWhite: 0.2, alpha: 1), 0.5),
                                                     (NSColor.init(deviceWhite: 0.1, alpha: 1), 1.0))!
    /* The highlight on the bottom lip of the bar. */
    let highlightColor: NSColor = NSColor.init(calibratedWhite: 0.88, alpha: 1)
    /* The font attributes of the progress numbers. */
    let numberStyle: [NSAttributedString.Key: Any] = {
        let stringEmboss = NSShadow.init()
        stringEmboss.shadowColor = NSColor.init(deviceWhite: 0.9, alpha: 1)
        stringEmboss.shadowBlurRadius = 0
        stringEmboss.shadowOffset = NSSize.init(width: 1, height: -1)

        return [
            NSAttributedString.Key.font: NSFont.init(name: "Lucida Grande Bold", size: 10)!,
            NSAttributedString.Key.foregroundColor: NSColor.init(deviceWhite: 0.2, alpha: 1),
            NSAttributedString.Key.shadow: stringEmboss
        ]
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        self.setFrameSize(frameRect.size)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.removeTrackingArea(self.trackingAreas.first!)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
        NSBezierPath.defaultLineWidth = 1.0
        var barRect = self.bounds
        barRect.origin.x = self.bounds.minX + 0.5 + self.horizontalMargin
        barRect.origin.y = self.bounds.height / 2.0 - 4.0
        barRect.size.width = self.bounds.width - 2 * self.horizontalMargin
        barRect.size.height = 8

        let highlight = NSBezierPath.init(roundedRect: barRect, xRadius: self.cornerRadius, yRadius: self.cornerRadius)
        self.highlightColor.set()
        highlight.stroke()

        barRect.origin.y += 0.5

        let roundedMask = NSBezierPath.init(roundedRect: barRect, xRadius: self.cornerRadius, yRadius: self.cornerRadius)

        NSGraphicsContext.saveGraphicsState()

        self.shadowGradient.draw(in: roundedMask, angle: 90.0)
        var fillRect = barRect.insetBy(dx: 1, dy: 1)
        NSBezierPath.init(roundedRect: fillRect, xRadius: self.cornerRadius - 1, yRadius: self.cornerRadius - 1).addClip()
        emptyGradient.draw(in: fillRect, angle: 270.0)

        let diameter = 2.0 * self.cornerRadius
        fillRect.size.width = self.progressRect.width * CGFloat(self.currentValue + 1) / CGFloat(self.maxValue) + diameter
        if !leftToRight {
            fillRect.origin.x = barRect.minX + barRect.width - fillRect.width - 1
        }

        let roundFill = NSBezierPath.init(roundedRect: fillRect, xRadius: self.cornerRadius - 1, yRadius: self.cornerRadius - 1)
        self.barGradient.draw(in: roundFill, angle: 90.0)

        NSGraphicsContext.restoreGraphicsState()

        let rightStringRect = NSRect.init(x: self.progressRect.maxX + self.cornerRadius, y: self.bounds.minY, width: self.horizontalMargin, height: self.bounds.height)
        let leftStringRect = NSRect.init(x: 0, y: self.bounds.minY, width: self.horizontalMargin, height: self.bounds.height);
        let totalString = NSString.init(format: "%i", maxValue)
        var stringSize = totalString.size(withAttributes: self.numberStyle)
        var stringRect = rectWithSizeCenteredInRect(stringSize, self.leftToRight ? rightStringRect : leftStringRect)
        totalString.draw(in: stringRect, withAttributes: self.numberStyle)

        let progressString = NSString.init(format: "%i", self.currentValue + 1)
        stringSize = progressString.size(withAttributes: self.numberStyle);
        stringRect = rectWithSizeCenteredInRect(stringSize, self.leftToRight ? leftStringRect : rightStringRect);
        progressString.draw(in: stringRect, withAttributes: self.numberStyle)
    }

    override func setFrameSize(_ size: NSSize) {
        super.setFrameSize(size)
        self.progressRect = NSRect.init(x: self.cornerRadius + self.horizontalMargin,
                                        y: 0,
                                        width: size.width - 2 * (self.cornerRadius + self.horizontalMargin),
                                        height: size.height)
    }

    override func updateTrackingAreas() {
        guard let oldArea = self.trackingAreas.first else { return }

        self.removeTrackingArea(oldArea)

        let newArea = NSTrackingArea.init(rect: self.progressRect, options: oldArea.options, owner: oldArea.owner, userInfo: oldArea.userInfo)
        self.addTrackingArea(newArea)
    }

    override func mouseDown(with event: NSEvent) {
        let cursorPoint = self.convert(event.locationInWindow, from: nil)
        if NSMouseInRect(cursorPoint, self.progressRect, self.isFlipped) {
            self.currentValue = self.indexFor(point: cursorPoint)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let cursorPoint = self.convert(event.locationInWindow, from: nil)
        if NSMouseInRect(cursorPoint, self.progressRect, self.isFlipped) {
            self.currentValue = self.indexFor(point: cursorPoint)

            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "SCMouseDragNotification"), object: self)
        }
    }

    override var mouseDownCanMoveWindow: Bool {
        get { return false }
    }

    @objc func indexFor(point: NSPoint) -> Int
    {
        let index: Int
        if(leftToRight)
        {
            index = Int((point.x - self.progressRect.minX) / self.progressRect.width * CGFloat(maxValue));
        }
        else
        {
            index = Int((self.progressRect.maxX - point.x) / self.progressRect.width * CGFloat(maxValue));
        }
        return min(index, maxValue - 1)
    }
}
