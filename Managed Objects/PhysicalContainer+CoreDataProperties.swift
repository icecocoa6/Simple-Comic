//
//  PhysicalContainer+CoreDataProperties.swift
//  Simple Comic
//
//  Created by 冨岡太一 on 2020/04/19.
//
//

import Foundation
import CoreData


extension PhysicalContainer {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PhysicalContainer> {
        return NSFetchRequest<PhysicalContainer>(entityName: "PhysicalContainer")
    }

    @NSManaged public var modified: TimeInterval
    @NSManaged public var name: String?
    @NSManaged public var pathData: Data?
    @NSManaged public var children: NSSet?
    @NSManaged public var imageList: ImageList?
    @NSManaged public var images: NSSet?
    @NSManaged public var parent: PhysicalContainer?

}

// MARK: Generated accessors for children
extension PhysicalContainer {

    @objc(addChildrenObject:)
    @NSManaged public func addToChildren(_ value: PhysicalContainer)

    @objc(removeChildrenObject:)
    @NSManaged public func removeFromChildren(_ value: PhysicalContainer)

    @objc(addChildren:)
    @NSManaged public func addToChildren(_ values: NSSet)

    @objc(removeChildren:)
    @NSManaged public func removeFromChildren(_ values: NSSet)

}

// MARK: Generated accessors for images
extension PhysicalContainer {

    @objc(addImagesObject:)
    @NSManaged public func addToImages(_ value: Image)

    @objc(removeImagesObject:)
    @NSManaged public func removeFromImages(_ value: Image)

    @objc(addImages:)
    @NSManaged public func addToImages(_ values: NSSet)

    @objc(removeImages:)
    @NSManaged public func removeFromImages(_ values: NSSet)

}
