//
//  PDF+CoreDataProperties.swift
//  Simple Comic
//
//  Created by 冨岡太一 on 2020/04/18.
//
//

import Foundation
import CoreData


extension PDF {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PDF> {
        return NSFetchRequest<PDF>(entityName: "PDF")
    }


}
