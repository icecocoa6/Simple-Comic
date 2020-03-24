//
//  Session+CoreDataProperties.swift
//  Simple Comic
//
//  Original version is created by Alexander Rauchfuss on 2/9/08.
//  Copyright 2008 Dancing Tortoise Software. All rights reserved.
//
//  Ported by Tomioka Taichi on 2020/03/24.
//
//

import Foundation
import CoreData


extension Session {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Session> {
        return NSFetchRequest<Session>(entityName: "Session")
    }

    @NSManaged public var scaleOptions: NSNumber?
    @NSManaged public var rotation: NSNumber?
    @NSManaged public var position: Data?
    @NSManaged public var fullscreen: NSNumber?
    @NSManaged public var zoomLevel: NSNumber?
    @NSManaged public var twoPageSpread: NSNumber?
    @NSManaged public var scrollPosition: Data?
    @NSManaged public var selection: NSNumber?
    @NSManaged public var pageOrder: NSNumber?
    @NSManaged public var loupe: NSNumber?
    @NSManaged public var images: NSSet?
    @NSManaged public var groups: NSSet?

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
