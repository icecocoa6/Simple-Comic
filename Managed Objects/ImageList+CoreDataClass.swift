//
//  ImageList+CoreDataClass.swift
//  Simple Comic
//
//  Created by Tomioka Taichi on 2020/04/18.
//
//

import Foundation
import CoreData


public class ImageList: NSManagedObject {
    private func allImages(in group: ImageGroup) -> Set<Image> {
        var result = Set<Image>(group.images?.allObjects as! [Image])
        for group in group.children ?? [] {
            result.formUnion(allImages(in: group as! ImageGroup))
        }
        return result
    }
    
    @objc var allImages: Set<Image> {
        var result = Set<Image>(self.images!.allObjects as! [Image])
        for group in self.groups ?? [] {
            let grp = group as! ImageGroup
            result.formUnion(self.allImages(in: grp))
        }
        return result
    }
}
