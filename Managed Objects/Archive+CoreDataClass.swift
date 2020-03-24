//
//  Archive+CoreDataClass.swift
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


public class Archive: ImageGroup {
    @objc static let archiveExtensions = [
        "rar", "cbr", "zip", "cbz", "7z", "cb7", "lha", "lzh", "tar"
    ]
    
    @objc static let quicklookExtensions = [
        "cbr", "cbz"
    ]
    
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
    
    override public func willTurnIntoFault() {
        if self.nested?.boolValue ?? false
        {
            try! FileManager.default.removeItem(atPath: self.path!)
        }
        
        if let solid = self.solidDirectory
        {
            try! FileManager.default.removeItem(atPath: solid)
        }
    }
    
    private var _instance: XADArchive?
    override public var instance: Any? {
        guard _instance == nil else { return _instance; }
        guard FileManager.default.fileExists(atPath: self.path!) else { return nil; }
        
        _instance = XADArchive.init(file: self.path!, delegate: self, error: nil)!
        if let password = self.password
        {
            _instance!.setPassword(password)
        }
        return _instance
    }
    
    override func dataFor(pageIndex: Int) -> Data? {
        let instance = self.instance! as! XADArchive
        
        if let solidDirectory = self.solidDirectory
        {
            let name = URL.init(fileURLWithPath: (instance.name(ofEntry: Int32(pageIndex)))!)
            let filename = String.init(format: "%li.%@", pageIndex, name.pathExtension)
            let url = URL.init(fileURLWithPath: filename, relativeTo: URL.init(fileURLWithPath: solidDirectory))
            
            if FileManager.default.fileExists(atPath: url.path)
            {
                return try! Data.init(contentsOf: url)
            }
            
            groupLock.lock()
            let imageData = instance.contents(ofEntry: Int32(pageIndex))
            groupLock.unlock()
            try! imageData!.write(to: url)
            return imageData
        }
        groupLock.lock()
        let imageData = instance.contents(ofEntry: Int32(pageIndex))
        groupLock.unlock()
        return imageData
    }
    
    override var topLevelGroup: NSManagedObject {
        var group: ImageGroup? = self
        var parent = group
        
        while let grp = group
        {
            group = grp.group
            parent = (group != nil && grp.isKind(of: Archive.self)) ? group : parent
        }
        
        return parent!
    }
    
    @objc func nestedArchiveContents()
    {
        let imageArchive = self.instance as! XADArchive?
        var collision = 0
        
        if imageArchive?.isSolid() ?? false
        {
            var archivePath: URL? = nil
            repeat {
                let name = String.init(format: "SC-images-%i", collision)
                archivePath = URL.init(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(name)
                collision += 1
                if (try? FileManager.default.createDirectory(at: archivePath!, withIntermediateDirectories: true)) != nil
                {
                    break
                }
            } while true
            self.solidDirectory = archivePath?.path
        }
        
        let numOfEntries = imageArchive?.numberOfEntries() ?? 0
        for counter in 0 ..< numOfEntries
        {
            let fileName = URL.init(fileURLWithPath: (imageArchive?.name(ofEntry: counter)!)!)
            guard fileName.lastPathComponent != "" && fileName.lastPathComponent.first != "." else { continue }
            
            let ext = fileName.pathExtension.lowercased()
            let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, ext as CFString, nil)?.takeRetainedValue()
            
            if Image.imageExtensions.contains(uti! as String)
            {
                let entity = Image.init(context: self.managedObjectContext!)
                entity.imagePath = fileName.lastPathComponent
                entity.index = counter as NSNumber
                entity.group = self
            }
            else if ((UserDefaults.standard.value(forKey: TSSTNestedArchives) as! NSNumber?)?.boolValue ?? false) && Archive.archiveExtensions.contains(ext)
            {
                let fileData = imageArchive?.contents(ofEntry: counter)
                let entity = Archive.init(context: self.managedObjectContext!)
                entity.name = fileName.lastPathComponent
                entity.nested = true
                
                var collision = 0
                var archivePath: URL
                repeat {
                    let name = String.init(format: "%i-%@", collision, fileName.lastPathComponent)
                    archivePath = URL.init(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(name)
                    collision += 1
                } while FileManager.default.fileExists(atPath: archivePath.path)
                
                try! FileManager.default.createDirectory(at: archivePath.deletingLastPathComponent(), withIntermediateDirectories: true)
                FileManager.default.createFile(atPath: archivePath.path, contents: fileData)
                
                entity.path = archivePath.path
                entity.nestedArchiveContents()
                entity.group = self
                self.addToNestedImages(entity.nestedImages!)
            }
            else if Image.textExtensions.contains(ext)
            {
                let entity = Image.init(context: self.managedObjectContext!)
                entity.imagePath = fileName.lastPathComponent
                entity.index = counter as NSNumber
                entity.text = true
                entity.group = self
            }
            else if UTTypeConformsTo(uti!, kUTTypePDF)
            {
                let entity = PDF.init(context: self.managedObjectContext!)
                
                var archivePath = URL.init(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName.lastPathComponent)
                var collision = 0
                while FileManager.default.fileExists(atPath: archivePath.path)
                {
                    collision += 1
                    let name = String.init(format: "%i-%@", collision, fileName.lastPathComponent)
                    archivePath = URL.init(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(name)
                }
                
                let fileData = imageArchive?.contents(ofEntry: counter)
                try! fileData?.write(to: archivePath, options: .atomicWrite)
                
                entity.path = archivePath.path
                entity.nested = true
                entity.pdfContents()
                entity.group = self
                self.addToNestedImages(entity.nestedImages!)
            }
        }
        
        self.addToNestedImages(self.images!)
    }
    
    @objc func quicklookCompatible() -> Bool {
        guard let name = self.name else { return false }
        let ext = URL.init(fileURLWithPath: name).pathExtension.lowercased()
        return Archive.quicklookExtensions.contains(ext)
    }
    
    override public func archiveNeedsPassword(_ archive: XADArchive!) {
        if self.password == nil
        {
            let app = NSApp.delegate as! SimpleComicAppDelegate
            self.password = app.passwordForArchive(withPath: self.path!)
        }
        
        archive.setPassword(self.password!)
    }
}
