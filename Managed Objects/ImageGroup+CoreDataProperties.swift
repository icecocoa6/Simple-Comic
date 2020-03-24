//
//  ImageGroup+CoreDataProperties.swift
//  Simple Comic
//
//  Created by 冨岡太一 on 2020/03/24.
//
//

import Foundation
import CoreData


extension ImageGroup {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ImageGroup> {
        return NSFetchRequest<ImageGroup>(entityName: "ImageGroup")
    }

    @NSManaged public var pathData: Data?
    @NSManaged public var nested: NSNumber?
    @NSManaged public var modified: Date?
    @NSManaged public var name: String?
    @NSManaged public var groups: NSSet?
    @NSManaged public var images: NSSet?
    @NSManaged public var session: Session?
    @NSManaged public var group: ImageGroup?
    @NSManaged public var nestedImages: NSSet?

}

// MARK: Generated accessors for groups
extension ImageGroup {

    @objc(addGroupsObject:)
    @NSManaged public func addToGroups(_ value: ImageGroup)

    @objc(removeGroupsObject:)
    @NSManaged public func removeFromGroups(_ value: ImageGroup)

    @objc(addGroups:)
    @NSManaged public func addToGroups(_ values: NSSet)

    @objc(removeGroups:)
    @NSManaged public func removeFromGroups(_ values: NSSet)

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
