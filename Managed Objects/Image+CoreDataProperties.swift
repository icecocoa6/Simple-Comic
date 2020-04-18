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
    @NSManaged public var group: ImageGroup?
    @NSManaged public var includedGroups: NSSet?
    @NSManaged public var session: Session?

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
