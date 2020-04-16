//
//  CGVector+SimpleComic.swift
//  Simple Comic
//
//  Created by Tomioka Taichi on 2020/04/17.
//

import Foundation

extension CGVector {
    static func +(lhs: CGVector, rhs: CGVector) -> CGVector {
        CGVector(dx: lhs.dx + rhs.dx, dy: lhs.dy + rhs.dy)
    }
    
    static func -(lhs: CGVector, rhs: CGVector) -> CGVector {
        CGVector(dx: lhs.dx - rhs.dx, dy: lhs.dy - rhs.dy)
    }
    
    static func *(lhs: CGFloat, rhs: CGVector) -> CGVector {
        CGVector(dx: lhs * rhs.dx, dy: lhs * rhs.dy)
    }
    
    static func /(lhs: CGVector, rhs: CGFloat) -> CGVector {
        CGVector(dx: lhs.dx / rhs, dy: lhs.dy / rhs)
    }
    
    init(_ point: CGPoint) {
        self.init(dx: point.x, dy: point.y)
    }
    
    init(_ size: CGSize) {
        self.init(dx: size.width, dy: size.height)
    }
}

extension CGPoint {
    init(_ vector: CGVector) {
        self.init(x: vector.dx, y: vector.dy)
    }
}

extension CGSize {
    init(_ vector: CGVector) {
        self.init(width: vector.dx, height: vector.dy)
    }
}
