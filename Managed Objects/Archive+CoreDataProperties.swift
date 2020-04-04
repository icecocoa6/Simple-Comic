//
//  Archive+CoreDataProperties.swift
//  Simple Comic
//
//  Created by 冨岡太一 on 2020/04/05.
//
//

import Foundation
import CoreData


extension Archive {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Archive> {
        return NSFetchRequest<Archive>(entityName: "Archive")
    }

    @NSManaged public var password: String?
    @NSManaged public var solidDirectory: URL?

}
