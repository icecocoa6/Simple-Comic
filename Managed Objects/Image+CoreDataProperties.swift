//
//  Image+CoreDataProperties.swift
//  Simple Comic
//
//  Ported by Tomioka Taichi on 2020/03/24.
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
    @NSManaged public var group: ImageGroup?
    @NSManaged public var session: TSSTManagedSession?
    @NSManaged public var includedGroups: NSSet?

}

// MARK: Generated accessors for includedGroups
extension Image {

    @objc(addIncludedGroupsObject:)
    @NSManaged public func addToIncludedGroups(_ value: ImageGroup)

    @objc(removeIncludedGroupsObject:)
    @NSManaged public func removeFromIncludedGroups(_ value: ImageGroup)

    @objc(addIncludedGroups:)
    @NSManaged public func addToIncludedGroups(_ values: NSSet)

    @objc(removeIncludedGroups:)
    @NSManaged public func removeFromIncludedGroups(_ values: NSSet)

}
