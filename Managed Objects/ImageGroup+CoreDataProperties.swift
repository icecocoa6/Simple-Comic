//
//  ImageGroup+CoreDataProperties.swift
//  Simple Comic
//
//  Created by 冨岡太一 on 2020/04/18.
//
//

import Foundation
import CoreData


extension ImageGroup {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ImageGroup> {
        return NSFetchRequest<ImageGroup>(entityName: "ImageGroup")
    }

    @NSManaged public var modified: TimeInterval
    @NSManaged public var name: String?
    @NSManaged public var pathData: Data?
    @NSManaged public var parent: ImageGroup?
    @NSManaged public var children: NSSet?
    @NSManaged public var images: NSSet?
    @NSManaged public var nestedImages: NSSet?
    @NSManaged public var session: Session?

}

// MARK: Generated accessors for children
extension ImageGroup {

    @objc(addChildrenObject:)
    @NSManaged public func addToChildren(_ value: ImageGroup)

    @objc(removeChildrenObject:)
    @NSManaged public func removeFromChildren(_ value: ImageGroup)

    @objc(addChildren:)
    @NSManaged public func addToChildren(_ values: NSSet)

    @objc(removeChildren:)
    @NSManaged public func removeFromChildren(_ values: NSSet)

}

// MARK: Generated accessors for images
extension ImageGroup {

    @objc(addImagesObject:)
    @NSManaged public func addToImages(_ value: Image)

    @objc(removeImagesObject:)
    @NSManaged public func removeFromImages(_ value: Image)

    @objc(addImages:)
    @NSManaged public func addToImages(_ values: NSSet)

    @objc(removeImages:)
    @NSManaged public func removeFromImages(_ values: NSSet)

}

// MARK: Generated accessors for nestedImages
extension ImageGroup {

    @objc(addNestedImagesObject:)
    @NSManaged public func addToNestedImages(_ value: Image)

    @objc(removeNestedImagesObject:)
    @NSManaged public func removeFromNestedImages(_ value: Image)

    @objc(addNestedImages:)
    @NSManaged public func addToNestedImages(_ values: NSSet)

    @objc(removeNestedImages:)
    @NSManaged public func removeFromNestedImages(_ values: NSSet)

}
