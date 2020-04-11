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
import AppKit
import CoreData


public class Archive: ImageGroup {
    @objc static let archiveExtensions = [
        "rar", "cbr", "zip", "cbz", "7z", "cb7", "lha", "lzh", "tar"
    ]
    
    @objc static let quicklookExtensions = [
        "cbr", "cbz"
    ]
    
    private lazy var tempDir: URL = {
        let pwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        return try! FileManager.default.url(for: .itemReplacementDirectory,
                                in: .userDomainMask,
                                appropriateFor: pwd,
                                create: true)
    }()
    
    deinit {
        try? FileManager.default.removeItem(atPath: tempDir.path)
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
    
    override public func willTurnIntoFault() {
        if self.nested?.boolValue ?? false
        {
            try! FileManager.default.removeItem(atPath: self.path!)
        }
    }
    
    private var _instance: XADArchive?
    public var instance: XADArchive? {
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
        let source = self.instance!

        groupLock.lock()
        defer { groupLock.unlock() }
        
        let imageData = source.contents(ofEntry: Int32(pageIndex))
        
        if source.isSolid() {
            let url = self.url(forDataAt: Int32(pageIndex), in: source)

            if FileManager.default.fileExists(atPath: url.path) {
                return try! Data(contentsOf: url)
            }

            try! imageData!.write(to: url, options: .atomicWrite)
        }
        
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
    
    fileprivate func url(forDataAt index: Int32, in imageArchive: XADArchive) -> URL {
        let fileName = URL.init(fileURLWithPath: imageArchive.name(ofEntry: index)!)
        let archivePath = tempDir.appendingPathComponent("\(index)").appendingPathComponent("\(fileName.lastPathComponent)")
        return archivePath
    }
    
    fileprivate func write(dataAt index: Int32, in imageArchive: XADArchive) throws -> URL {
        let archivePath = url(forDataAt: index, in: imageArchive)
        try FileManager.default.createDirectory(at: archivePath.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true,
                                                 attributes: nil)
        let fileData = imageArchive.contents(ofEntry: index)
        try fileData?.write(to: archivePath, options: .atomicWrite)
        return archivePath
    }
    
    func nestedArchiveContents()
    {
        let imageArchive = self.instance
        
        let numOfEntries = imageArchive?.numberOfEntries() ?? 0
        for counter in 0 ..< numOfEntries
        {
            let fileName = URL.init(fileURLWithPath: (imageArchive?.name(ofEntry: counter)!)!)
            guard fileName.lastPathComponent != "" && fileName.lastPathComponent.first != "." else { continue }
            
            let ext = fileName.pathExtension.lowercased()
            let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, ext as CFString, nil)!.takeRetainedValue()
            
            if Image.imageExtensions.contains(uti as String)
            {
                let entity = Image.init(context: self.managedObjectContext!)
                entity.imagePath = fileName.lastPathComponent
                entity.index = counter as NSNumber
                entity.group = self
            }
            else if Archive.archiveExtensions.contains(ext)
            {
                let archivePath = try! write(dataAt: counter, in: imageArchive!)
                
                let entity = Archive.init(context: self.managedObjectContext!)
                entity.name = fileName.lastPathComponent
                entity.nested = true
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
            else if UTTypeConformsTo(uti, kUTTypePDF)
            {
                let archivePath = try! write(dataAt: counter, in: imageArchive!)
                
                let entity = PDF.init(context: self.managedObjectContext!)
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
