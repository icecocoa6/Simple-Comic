//
//  Image+CoreDataProperties.swift
//  Simple Comic
//
//  Created by Tomioka Taichi on 2020/03/23.
//
//

import Foundation
import CoreData


extension Image {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Image> {
        return NSFetchRequest<Image>(entityName: "Image")
    }

    @NSManaged public var height: NSNumber?
    @NSManaged public var index: NSNumber?
    @NSManaged public var width: NSNumber?
    @NSManaged public var imagePath: String?
    @NSManaged public var text: NSNumber?
    @NSManaged public var aspectRatio: NSNumber?
    @NSManaged public var thumbnailData: Data?
    @NSManaged public var group: TSSTManagedGroup?
    @NSManaged public var session: TSSTManagedSession?

}
