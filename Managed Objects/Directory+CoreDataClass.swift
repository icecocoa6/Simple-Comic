//
//  Directory+CoreDataClass.swift
//  Simple Comic
//
//  Created by Tomioka Taichi on 2020/04/18.
//
//

import Foundation
import CoreData
import Cocoa

public class Directory: PhysicalContainer {
    convenience init(context: NSManagedObjectContext, url: URL) {
        self.init(context: context)
        self.url = url
        self.name = url.lastPathComponent
        self.nestedFolderContents()
    }
    
    func nestedFolderContents() {
        let folderURL = self.url!
        let nestedFiles: [String]
        do {
            nestedFiles = try FileManager.default.contentsOfDirectory(atPath: self.url!.path)
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
            case let group as PhysicalContainer:
                group.parent = self
                group.imageList = self.imageList
            case let image as Image:
                image.group = self
                image.imageList = self.imageList
            default:
                assert(false)
            }
        }
    }
}
