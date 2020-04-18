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
        for group in self.imageList!.groups!
        {
            let grp = group as! ImageGroup
            _ = grp.url
        }
    }

    var adjustmentMode: PageAdjustmentMode {
        get { PageAdjustmentMode(rawValue: Int(rawAdjustmentMode)) ?? .none }
        set(value) {
            self.willChangeValue(for: \.rawAdjustmentMode)
            rawAdjustmentMode = Int16(value.rawValue)
            self.didChangeValue(for: \.rawAdjustmentMode)
        }
    }
    
    func addFile(atURL url: URL) {
        let entity = self.managedObjectContext?.createEntity(fromContentsAtURL: url)
        guard entity != nil else { return }
        
        self.willChangeValue(for: \.allImages)
        switch entity {
        case let group as ImageGroup:
            group.imageList = self.imageList
        case let image as Image:
            image.imageList = self.imageList
        default:
            assert(false)
        }
        self.didChangeValue(for: \.allImages)
        
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
    }
    
    @objc var allImages: Set<Image>? {
        self.imageList?.allImages
    }
    
    var orientation: Orientation.Horizontal {
        return pageOrder ? .right : .left
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
            return Directory(context: self, url: url)
        } else if UTTypeConformsTo(uti, kUTTypeArchive) {
            return Archive(context: self, url: url)
        } else if UTTypeConformsTo(uti, kUTTypePDF) {
            return PDF(context: self, url: url)
        } else if UTTypeConformsTo(uti, kUTTypeImage) {
            return Image(context: self, url: url)
        } else if UTTypeConformsTo(uti, kUTTypeText) {
            return Image(context: self, url: url, text: true)
        }
        
        return nil
    }
}

@objc enum PageAdjustmentMode: Int, Codable {
    case none = 0
    case fitToWindow = 1
    case fitToWidth = 2
}
