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
    
    convenience init(context: NSManagedObjectContext, url: URL) {
        self.init(context: context)
        self.path = url.path
        self.name = url.lastPathComponent
        self.nestedArchiveContents()
    }
    
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
        guard _instance == nil else { return _instance }
        guard FileManager.default.fileExists(atPath: self.path!) else { return nil }
        guard FileManager.default.isReadableFile(atPath: self.path!) else { return nil }
        
        _instance = XADArchive(file: self.path!, delegate: self, error: nil)
        
        if _instance == nil {
            let alert = NSAlert()
            alert.messageText = "Invalid Archive Found"
            alert.informativeText = "This application just ignores the invalid archive file. Check the archive at '\(self.path!)'."
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return nil
        }
        
        if let password = self.password
        {
            _instance!.setPassword(password)
        }
        return _instance
    }
    
    override func dataFor(pageIndex: Int) -> Data? {
        let source = self.instance

        groupLock.lock()
        defer { groupLock.unlock() }
        
        let imageData = source?.contents(ofEntry: Int32(pageIndex))
        
        if source?.isSolid() ?? false {
            let url = self.url(forDataAt: Int32(pageIndex), in: source!)

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
        guard let imageArchive = self.instance else { return }
        
        let numOfEntries = imageArchive.numberOfEntries()
        for counter in 0 ..< numOfEntries
        {
            let url = try! write(dataAt: counter, in: imageArchive)
            
            let entity = self.managedObjectContext?.createEntity(fromContentsAtURL: url)
            switch entity {
            case let image as Image:
                image.index = counter as NSNumber
                image.group = self
            case let group as ImageGroup:
                group.nested = true
                group.group = self
                self.addToNestedImages(group.nestedImages!)
            default:
                break
            }
        }
        
        self.addToNestedImages(self.images!)
    }
    
    var quicklookCompatible: Bool {
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
