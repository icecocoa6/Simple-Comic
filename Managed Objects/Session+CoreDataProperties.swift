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
    @NSManaged public var imageList: ImageList?

}
