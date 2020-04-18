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
    let groupLock = NSLock.init()

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
        self.url = url
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
        super.didTurnIntoFault()
        self._instance = nil
    }
    
    private var _instance: XADArchive?
    public var instance: XADArchive? {
        guard _instance == nil else { return _instance }
        guard FileManager.default.fileExists(atPath: self.url!.path) else { return nil }
        guard FileManager.default.isReadableFile(atPath: self.url!.path) else { return nil }
        
        _instance = XADArchive(file: self.url!.path, delegate: self, error: nil)
        
        if _instance == nil {
            let alert = NSAlert()
            alert.messageText = "Invalid Archive Found"
            alert.informativeText = "This application just ignores the invalid archive file. Check the archive at '\(self.url!)'."
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
                image.imageList = self.imageList
            case let group as ImageGroup:
                group.parent = self
                group.imageList = self.imageList
            default:
                break
            }
        }
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
            self.password = app.passwordForArchive(withPath: self.url!)
        }
        
        archive.setPassword(self.password!)
    }
}
