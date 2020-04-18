//
//  Image+CoreDataProperties.swift
//  Simple Comic
//
//  Created by 冨岡太一 on 2020/04/18.
//
//

import Foundation
import CoreData


extension Image {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Image> {
        return NSFetchRequest<Image>(entityName: "Image")
    }

    @NSManaged public var aspectRatio: NSNumber?
    @NSManaged public var height: Double
    @NSManaged public var imageURL: URL?
    @NSManaged public var index: NSNumber?
    @NSManaged public var text: Bool
    @NSManaged public var thumbnailData: Data?
    @NSManaged public var width: Double
    @NSManaged public var group: PhysicalContainer?
    @NSManaged public var imageList: ImageList?

}
