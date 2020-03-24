//
//  PDF+CoreDataProperties.swift
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


extension PDF {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PDF> {
        return NSFetchRequest<PDF>(entityName: "PDF")
    }


}
