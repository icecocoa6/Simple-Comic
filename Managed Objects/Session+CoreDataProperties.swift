//
//  Session+CoreDataProperties.swift
//  Simple Comic
//
//  Created by 冨岡太一 on 2020/04/18.
//
//

import Foundation
import CoreData


extension Session {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Session> {
        return NSFetchRequest<Session>(entityName: "Session")
    }

    @NSManaged public var fullscreen: Bool
    @NSManaged public var loupe: Bool
    @NSManaged public var pageOrder: Bool
    @NSManaged public var position: Data?
    @NSManaged public var rawAdjustmentMode: Int16
    @NSManaged public var rotation: Int16
    @NSManaged public var scrollPosition: Data?
    @NSManaged public var selection: Int16
    @NSManaged public var twoPageSpread: Bool
    @NSManaged public var zoomLevel: Float
    @NSManaged public var groups: NSSet?
    @NSManaged public var images: NSSet?

}

// MARK: Generated accessors for groups
extension Session {

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
extension Session {

    @objc(addImagesObject:)
    @NSManaged public func addToImages(_ value: Image)

    @objc(removeImagesObject:)
    @NSManaged public func removeFromImages(_ value: Image)

    @objc(addImages:)
    @NSManaged public func addToImages(_ values: NSSet)

    @objc(removeImages:)
    @NSManaged public func removeFromImages(_ values: NSSet)

}
