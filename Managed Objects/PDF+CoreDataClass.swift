//
//  PDF+CoreDataClass.swift
//  Simple Comic
//
//  Original version is created by Alexander Rauchfuss on 2/9/08.
//  Copyright 2008 Dancing Tortoise Software. All rights reserved.
//
//  Ported by Tomioka Taichi on 2020/03/24.
//
//

import Foundation
import CoreData
import Quartz

public class PDF: ImageGroup {

    private var _instance: PDFDocument?
    var instance: Any? {
        guard _instance == nil else { return _instance }
        _instance = PDFDocument.init(url: URL.init(fileURLWithPath: self.path!))
        return _instance
    }
    
    override public func awakeFromInsert() {
        super.awakeFromInsert()
        self._instance = nil
    }
    
    override public func awakeFromFetch() {
        super.awakeFromFetch()
        self._instance = nil
    }
    
    override public func didTurnIntoFault() {
        self._instance = nil
    }
    
    override func dataFor(pageIndex: Int) -> Data? {
        groupLock.lock()
        let pdf = self.instance as! PDFDocument?
        let page = pdf?.page(at: pageIndex)
        groupLock.unlock()
        
        var bounds = page!.bounds(for: .mediaBox)
        let dimension: CGFloat = 1400.0
        let scale = bounds.width > bounds.height ? dimension / bounds.width : dimension / bounds.height
        bounds.size = scaleSize(bounds.size, Float(scale))
        
        let pageImage = NSImage.init(size: bounds.size)
        pageImage.lockFocus()
        let cgctx = NSGraphicsContext.current!.cgContext
        NSColor.white.set()
        bounds.fill()
        let scaleTransform = NSAffineTransform.init()
        scaleTransform.scale(by: scale)
        scaleTransform.concat()
        page?.draw(with: .mediaBox, to: cgctx)
        pageImage.unlockFocus()
        
        return pageImage.tiffRepresentation
    }
    
    /*  Creates an image managedobject for every "page" in a pdf. */
    @objc func pdfContents() {
        let doc = self.instance as! PDFDocument
        let set = NSMutableSet.init()
        for pageNumber in 0 ..< doc.pageCount
        {
            let entity = Image.init(context: self.managedObjectContext!)
            entity.imagePath = String.init(format: "%i", pageNumber + 1)
            entity.index = pageNumber as NSNumber
            set.add(entity)
        }
        self.addToImages(set)
        self.addToNestedImages(set)
    }
}
