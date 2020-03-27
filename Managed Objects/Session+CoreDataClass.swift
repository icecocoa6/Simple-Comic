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
    
    var pageScaling: PageScaling {
        get { PageScaling.init(rawValue: scaleOptions?.intValue ?? 0) ?? .noScale }
        set(value) { scaleOptions = value.rawValue as NSNumber }
    }
}

enum PageScaling: Int {
    case noScale = 0
    case fitToWindow = 1
    case fitToWidth = 2
}
