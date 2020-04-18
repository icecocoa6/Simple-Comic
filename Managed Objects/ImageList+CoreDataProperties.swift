//
//  ImageList+CoreDataProperties.swift
//  Simple Comic
//
//  Created by 冨岡太一 on 2020/04/18.
//
//

import Foundation
import CoreData


extension ImageList {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ImageList> {
        return NSFetchRequest<ImageList>(entityName: "ImageList")
    }

    @NSManaged public var images: NSSet?
    @NSManaged public var groups: NSSet?
    @NSManaged public var session: Session?

}

// MARK: Generated accessors for images
extension ImageList {

    @objc(addImagesObject:)
    @NSManaged public func addToImages(_ value: Image)

    @objc(removeImagesObject:)
    @NSManaged public func removeFromImages(_ value: Image)

    @objc(addImages:)
    @NSManaged public func addToImages(_ values: NSSet)

    @objc(removeImages:)
    @NSManaged public func removeFromImages(_ values: NSSet)

}

// MARK: Generated accessors for groups
extension ImageList {

    @objc(addGroupsObject:)
    @NSManaged public func addToGroups(_ value: PhysicalContainer)

    @objc(removeGroupsObject:)
    @NSManaged public func removeFromGroups(_ value: PhysicalContainer)

    @objc(addGroups:)
    @NSManaged public func addToGroups(_ values: NSSet)

    @objc(removeGroups:)
    @NSManaged public func removeFromGroups(_ values: NSSet)

}
