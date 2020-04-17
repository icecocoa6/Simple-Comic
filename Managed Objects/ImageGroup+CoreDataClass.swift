//
//  ImageGroup+CoreDataClass.swift
//  Simple Comic
//
//  Original version is created by Alexander Rauchfuss on 2/9/08.
//  Copyright 2008 Dancing Tortoise Software. All rights reserved.
//
//  Ported by Tomioka Taichi on 2020/03/23.
//
//

import AppKit
import Foundation
import CoreData


public class ImageGroup: NSManagedObject {
    let groupLock = NSLock.init()
    
    convenience init(context: NSManagedObjectContext, url: URL) {
        self.init(context: context)
        self.path = url.path
        self.name = url.lastPathComponent
        self.nestedFolderContents()
    }
    
    override public func awakeFromInsert() {
        super.awakeFromInsert()
    }
    
    override public func awakeFromFetch() {
        super.awakeFromFetch()
    }
    
    override public func willTurnIntoFault() {
        if self.nested?.boolValue ?? false
        {
            try! FileManager.default.removeItem(atPath: self.path!)
        }
    }
    
    @objc var path: String? {
        get {
            do {
                var stale = false
                let fileURL = try URL.init(resolvingBookmarkData: self.pathData!,
                                           options: .withoutUI,
                                           relativeTo: nil,
                                           bookmarkDataIsStale: &stale)
                return fileURL.path
            }
            catch {
                self.managedObjectContext?.delete(self)
                NSApp.presentError(error)
                return nil
            }
        }
        set(_value) {
            guard let value = _value else { return }
            
            let url = URL.init(fileURLWithPath: value)
            do {
                let data = try url.bookmarkData(options: .minimalBookmark,
                                                includingResourceValuesForKeys: nil,
                                                relativeTo: nil)
                self.pathData = data
            }
            catch {
                NSApp.presentError(error)
            }
        }
    }
    
    func dataFor(pageIndex: Int) -> Data?
    {
        return nil
    }
    
    @objc var topLevelGroup: NSManagedObject
    {
        return self
    }
    
    @objc func nestedFolderContents()
    {
        let folderURL = URL.init(fileURLWithPath: self.path!)
        let nestedFiles: [String]
        do {
            nestedFiles = try FileManager.default.contentsOfDirectory(atPath: self.path!)
        }
        catch {
            nestedFiles = []
            NSApp.presentError(error)
        }
        
        for path in nestedFiles
        {
            let url = folderURL.appendingPathComponent(path)
            let entity = self.managedObjectContext?.createEntity(fromContentsAtURL: url)
            
            // ignore unreadable files
            guard entity != nil else { continue }
            
            switch entity {
            case let group as ImageGroup:
                group.group = self
                self.addToNestedImages(group.nestedImages!)
            case let image as Image:
                image.group = self
            default:
                assert(false)
            }
        }
        
        self.addToNestedImages(self.images!)
    }
}
