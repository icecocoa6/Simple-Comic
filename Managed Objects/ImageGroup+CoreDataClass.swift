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
    @objc var url: URL? {
        get {
            do {
                var stale = false
                return try URL(resolvingBookmarkData: self.pathData!,
                               options: .withoutUI,
                               relativeTo: nil,
                               bookmarkDataIsStale: &stale)
            }
            catch {
                self.managedObjectContext?.delete(self)
                NSApp.presentError(error)
                return nil
            }
        }
        set(_value) {
            guard let url = _value else { return }

            do {
                self.pathData = try url.bookmarkData(options: .minimalBookmark,
                                                     includingResourceValuesForKeys: nil,
                                                     relativeTo: nil)
            }
            catch {
                NSApp.presentError(error)
            }
        }
    }
    
    func dataFor(pageIndex: Int) -> Data? {
        return nil
    }

    var topLevelGroup: NSManagedObject {
        return self.parent?.topLevelGroup ?? self
    }
}
