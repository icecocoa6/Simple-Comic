//
//  ColorTransformer.swift
//  Simple Comic
//
//  Created by Tomioka Taichi on 2020/04/11.
//

import Cocoa

class ColorTransformer: NSSecureUnarchiveFromDataTransformer {
    override class func transformedValueClass() -> AnyClass {
        return NSColor.self
    }
    
    override class func allowsReverseTransformation() -> Bool {
        return true
    }
    
    override func transformedValue(_ value: Any?) -> Any? {
        return try! NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: value as! Data)
    }
    
    override func reverseTransformedValue(_ value: Any?) -> Any? {
        return try! NSKeyedArchiver.archivedData(withRootObject: value as! NSColor, requiringSecureCoding: true)
    }
}

extension NSValueTransformerName {
    static let ColorTransformer = NSValueTransformerName(rawValue: "ColorTransformer")
}
