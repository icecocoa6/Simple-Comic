//
//  Image+CoreDataClass.swift
//  Simple Comic
//
//    Copyright (c) 2006-2009 Dancing Tortoise Software
//
//    Permission is hereby granted, free of charge, to any person
//    obtaining a copy of this software and associated documentation
//    files (the "Software"), to deal in the Software without
//    restriction, including without limitation the rights to use,
//    copy, modify, merge, publish, distribute, sublicense, and/or
//    sell copies of the Software, and to permit persons to whom the
//    Software is furnished to do so, subject to the following
//    conditions:
//
//    The above copyright notice and this permission notice shall be
//    included in all copies or substantial portions of the Software.
//
//    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//    EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//    OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//    NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//    HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//    WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//    FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//    OTHER DEALINGS IN THE SOFTWARE.
//
//  Ported by Tomioka Taichi on 2020/03/23.
//
//

import Foundation
import AppKit
import CoreData


public class Image: NSManagedObject {
    var thumbLock: NSLock?
    var loaderLock: NSLock?
    
    @objc static let imageExtensions: [String] = {
        return NSImage.imageTypes.filter { (str) -> Bool in
            return str != "pdf" && str != "eps"
        }
    }()
    
    @objc static let textExtensions = ["txt", "nfo", "info"]
    
    static let monospaceCharacterSize: NSSize =
        NSString.init(string: "A")
            .boundingRect(with: NSZeroSize,
                          options: [],
                          attributes: [.font: NSFont.init(name: "Monaco", size: 14)!]).size
    
    static let TSSTInfoPageAttributes: [NSAttributedString.Key: Any] = {
        var tabStops: [NSTextTab] = []
        /* Loop through the tab stops */
        for tabSize in stride(from: 8, to: 120, by: 8)
        {
            let tabLocation = CGFloat(tabSize) * monospaceCharacterSize.width
            let tabStop = NSTextTab.init(type: .leftTabStopType, location: tabLocation)
            tabStops.append(tabStop)
        }
        
        var style = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
        style.tabStops = tabStops
        
        return [
            .font: NSFont.init(name: "Monaco", size: 14)!,
            .paragraphStyle: style
        ]
    }()
    
    convenience init(context: NSManagedObjectContext, url: URL, text: Bool = false) {
        self.init(context: context)
        self.imageURL = url
        self.text = text
    }
    
    override public func awakeFromInsert() {
        super.awakeFromInsert()
        thumbLock = NSLock.init()
        loaderLock = NSLock.init()
    }
    
    override public func awakeFromFetch() {
        super.awakeFromFetch()
        thumbLock = NSLock.init()
        loaderLock = NSLock.init()
    }
    
    override public func didTurnIntoFault() {
        thumbLock = nil
        loaderLock = nil
    }
    
    @objc func shouldDisplayAlone() -> Bool {
        if self.text
        {
            return true;
        }
        
        let defaultAspect: Float = 1.0;
        var aspectRatio = self.aspectRatio
        
        if aspectRatio == nil
        {
            let imageData = self.pageData
            self.setOwnSizeInfoWithData(imageData: imageData!)
            aspectRatio = self.aspectRatio
        }
        
        return aspectRatio != nil ? aspectRatio!.floatValue > defaultAspect : true;
    }
    
    func setOwnSizeInfoWithData(imageData: Data)
    {
        let pageRep = NSBitmapImageRep.init(data: imageData)!
        let imageSize = CGSize.init(width: pageRep.pixelsWide, height: pageRep.pixelsHigh)
        
        if NSZeroSize != imageSize
        {
            let aspect = imageSize.width / imageSize.height;
            self.width = Double(Float(imageSize.width))
            self.height = Double(Float(imageSize.height))
            self.aspectRatio = Float(aspect) as NSNumber
        }
    }
    
    @objc var name: String? {
        get {
            self.imageURL?.lastPathComponent
        }
    }
    
    var thumbnail: NSImage? {
        if self.thumbnailData == nil
        {
            self.thumbnailData = self.prepThumbnail
        }
        
        if let data = self.thumbnailData {
            return NSImage(data: data)
        } else {
            return nil
        }
    }
    
    var prepThumbnail: Data? {
        thumbLock!.lock()
        let managedImage = self.pageImage
        var thumbnailData: Data? = nil;
        
        if let image = managedImage
        {
            let pixelSize = image.size.adjust(to: CGSize(width: 256, height: 256))
            let temp = NSImage.init(size: pixelSize)
            temp.lockFocus()
            NSGraphicsContext.current?.imageInterpolation = .high
            image.draw(in: NSRect.init(origin: CGPoint.zero, size: pixelSize), from: NSZeroRect, operation: .sourceOver, fraction: 1.0)
            temp.unlockFocus()
            thumbnailData = temp.tiffRepresentation
        }
        thumbLock!.unlock()
        
        return thumbnailData
    }
    
    @objc var pageImage: NSImage? {
        let text = self.text
        if text
        {
            return self.textPage
        }
        
        var imageFromData: NSImage? = nil
        let imageData = self.pageData
        
        if let img = imageData
        {
            self.setOwnSizeInfoWithData(imageData: img)
            imageFromData = NSImage.init(data: img)
        }
        
        let width = self.width
        let height = self.height
        let imageSize = NSSize.init(width: width, height: height)
        
        guard imageFromData != nil && imageSize != NSZeroSize else {
            return nil
        }
        
        let img = imageFromData!
        img.cacheMode = .never
        img.size = imageSize
        img.cacheMode = .default
        
        return imageFromData
    }
    
    var imageSource: CGImageSource? {
        guard !text else { return nil }
        guard let img = self.pageData else { return nil }
        
        self.setOwnSizeInfoWithData(imageData: img)
        guard let source = CGImageSourceCreateWithData(NSData.init(data: img) as CFData, nil) else { return nil }
        guard CGImageSourceGetStatus(source) == .statusComplete else { return nil }
        guard CGImageSourceGetCount(source) > 0 else { return nil }
        
        return source
    }
    
    var textPage: NSImage? {
        let textData = self.pageData
        var lossyConversion: ObjCBool = false;
        let stringEncoding = NSString.stringEncoding(for: textData!, encodingOptions: nil, convertedString: nil, usedLossyConversion: &lossyConversion)
        let text = NSString.init(data: textData!, encoding: stringEncoding)
        var pageRect = NSZeroRect
        var index = 0
        while index < text!.length
        {
            let lineRange = text?.lineRange(for: NSRange.init(location: index, length: 0))
            index = NSMaxRange(lineRange!)
            let singleLine = NSString.init(string: text!.substring(with: lineRange!))
            let lineRect = singleLine.boundingRect(with: NSSize.init(width: 800, height: 800), options: [.usesLineFragmentOrigin], attributes: Image.TSSTInfoPageAttributes)
            if lineRect.width > pageRect.width
            {
                pageRect.size.width = lineRect.size.width
            }
            
            pageRect.size.height += lineRect.height - 19
        }
        pageRect.size.width += 10;
        pageRect.size.height += 10;
        pageRect.size.height = pageRect.height < 500 ? 500 : pageRect.height;
        
        let textImage = NSImage.init(size: pageRect.size)
        textImage.lockFocus()
        NSColor.white.set()
        pageRect.fill()
        text?.draw(with: pageRect.insetBy(dx: 5, dy: 5), options: [.usesLineFragmentOrigin], attributes: Image.TSSTInfoPageAttributes)
        textImage.unlockFocus()
        return textImage
    }
    
    @objc var pageData: Data? {
        if let index = self.index
        {
            return self.group?.dataFor(pageIndex: index.intValue)
        }
        else if let url = self.imageURL
        {
            return try! Data.init(contentsOf: url)
        }
        
        return nil
    }
    
    /* Makes sure that the group is both an archive and not nested */
    var isExtractable: Bool {
        self.group is Archive && self.group!.isTopLevel && !self.text
    }
    
    /// returns a url at which this the source file of this image is actually placed.
    var representationURL: URL? {
        self.group != nil
            ? (self.group!.topLevelGroup as! PhysicalContainer).url
            : self.imageURL
    }
}
