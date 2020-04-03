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
}

@objc enum PageAdjustmentMode: Int, Codable {
    case none = 0
    case fitToWindow = 1
    case fitToWidth = 2
}
