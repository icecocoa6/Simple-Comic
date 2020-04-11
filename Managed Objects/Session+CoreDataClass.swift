//
//  Session+CoreDataClass.swift
//  Simple Comic
//
//  Original version is created by Alexander Rauchfuss on 2/9/08.
//  Copyright 2008 Dancing Tortoise Software. All rights reserved.
//
//  Ported by Tomioka Taichi on 2020/03/24.
//
//

import Foundation
import AppKit
import CoreData


public class Session: NSManagedObject {
    override public func awakeFromFetch() {
        super.awakeFromFetch()

        /* By calling path for all children, groups with unresolved bookmarks
        are deleted. */
        for group in self.groups!
        {
            let grp = group as! ImageGroup
            _ = grp.path
        }
    }

    var adjustmentMode: PageAdjustmentMode {
        get { PageAdjustmentMode(rawValue: rawAdjustmentMode?.intValue ?? 0) ?? .none }
        set(value) {
            self.willChangeValue(for: \.rawAdjustmentMode)
            rawAdjustmentMode = value.rawValue as NSNumber
            self.didChangeValue(for: \.rawAdjustmentMode)
        }
    }
    
    func addFile(atURL url: URL) {
        let entity = self.managedObjectContext?.createEntity(fromContentsAtURL: url)
        guard entity != nil else { return }
        switch entity {
        case let group as ImageGroup:
            self.addToImages(group.nestedImages!)
            group.session = self
        case let image as Image:
            self.addToImages(image)
            image.session = self
        default:
            assert(false)
        }
        
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
    }
    
    var orientation: Orientation.Horizontal {
        return (pageOrder?.boolValue ?? false) ? .right : .left
    }
}

extension NSManagedObjectContext {
    func createEntity(fromContentsAtURL url: URL) -> NSManagedObject? {
        let resources: URLResourceValues
        do {
            resources = try url.resourceValues(forKeys: [.isReadableKey, .isHiddenKey, .isDirectoryKey, .typeIdentifierKey])
        }
        catch {
            NSApp.presentError(error)
            return nil
        }
        
        let isDirectory = resources.isDirectory!
        let isReadable = resources.isReadable!
        let isHidden = resources.isHidden!
        let uti = resources.typeIdentifier! as CFString
        
        // TODO: error handling
        guard isReadable && !isHidden else { return nil }
        
        if isDirectory {
            let entity = ImageGroup.init(context: self)
            entity.path = url.path
            entity.name = url.lastPathComponent
            entity.nestedFolderContents()
            return entity
        } else if UTTypeConformsTo(uti, kUTTypeArchive) {
            let entity = Archive.init(context: self)
            entity.path = url.path
            entity.name = url.lastPathComponent
            entity.nestedArchiveContents()
            return entity
        } else if UTTypeConformsTo(uti, kUTTypePDF) {
            let entity = PDF.init(context: self)
            entity.path = url.path
            entity.name = url.lastPathComponent
            entity.pdfContents()
            return entity
        } else if UTTypeConformsTo(uti, kUTTypeImage) {
            let entity = Image.init(context: self)
            entity.imagePath = url.path
            return entity
        } else if UTTypeConformsTo(uti, kUTTypeText) {
            let entity = Image.init(context: self)
            entity.imagePath = url.path
            entity.text = true
            return entity
        }
        
        return nil
    }
}

@objc enum PageAdjustmentMode: Int, Codable {
    case none = 0
    case fitToWindow = 1
    case fitToWidth = 2
}
