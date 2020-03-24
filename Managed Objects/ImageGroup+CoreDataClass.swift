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

import Foundation
import CoreData


public class ImageGroup: NSManagedObject {
    @objc var instance: Any? { return nil }
    let groupLock = NSLock.init()
    
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
            let fileExtension = URL.init(fileURLWithPath: path).pathExtension.lowercased()
            let fullPath = folderURL.appendingPathComponent(path)
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: fullPath.path, isDirectory: &isDirectory)
            let uti = try! NSWorkspace.shared.type(ofFile: fullPath.path)
            
            guard exists && fullPath.lastPathComponent.first != "." else { continue }
            
            if isDirectory.boolValue
            {
                let entity = ImageGroup.init(context: self.managedObjectContext!)
                entity.path = fullPath.path
                entity.name = path
                entity.nestedFolderContents()
                entity.group = self
                self.addToNestedImages(entity.nestedImages!)
            }
            else if Archive.archiveExtensions.contains(fileExtension)
            {
                let entity = Archive.init(context: self.managedObjectContext!)
                entity.path = fullPath.path
                entity.name = path
                entity.nestedArchiveContents()
                entity.group = self
                self.addToNestedImages(entity.nestedImages!)
            }
            else if UTTypeConformsTo(uti as CFString, kUTTypePDF)
            {
                let entity = PDF.init(context: self.managedObjectContext!)
                entity.path = fullPath.path
                entity.name = path
                entity.pdfContents()
                entity.group = self
                self.addToNestedImages(entity.nestedImages!)
            }
            else if Image.imageExtensions.contains(uti)
            {
                let entity = Image.init(context: self.managedObjectContext!)
                entity.imagePath = fullPath.path
                entity.group = self
            }
            else if Image.textExtensions.contains(fileExtension)
            {
                let entity = Image.init(context: self.managedObjectContext!)
                entity.imagePath = fullPath.path
                entity.text = true
                entity.group = self
            }
        }
        
        self.addToNestedImages(self.images!)
    }
}
