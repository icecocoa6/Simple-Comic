//
//  OrthogonalRotation.swift
//  Simple Comic
//
//  Created by Tomioka Taichi on 2020/04/10.
//

import Foundation
import AppKit

enum OrthogonalRotation: Int {
    case r0_4 = 0
    case r1_4 = 3
    case r2_4 = 2
    case r3_4 = 1
    static let r4_4 = r0_4
    
    func affineTransform(withSize size: CGSize) -> NSAffineTransform {
        let transform = NSAffineTransform()
        switch self {
        case .r0_4:
            break
        case .r3_4:
            transform.rotate(byDegrees: 270)
            transform.translateX(by: -size.height, yBy: 0)
        case .r2_4:
            transform.rotate(byDegrees: 180)
            transform.translateX(by: -size.width, yBy: -size.height)
        case .r1_4:
            transform.rotate(byDegrees: 90)
            transform.translateX(by: 0, yBy: -size.width)
        }
        return transform
    }
    
    var caTransform: CATransform3D {
        switch self {
        case .r0_4:
            return CATransform3DIdentity
        case .r1_4:
            return CATransform3DMakeRotation(.pi / 2, 0, 0, 1)
        case .r2_4:
            return CATransform3DMakeRotation(.pi, 0, 0, 1)
        case .r3_4:
            return CATransform3DMakeRotation(-.pi / 2, 0, 0, 1)
        }
    }
}


func * (lhs: OrthogonalRotation, rhs: OrthogonalRotation) -> OrthogonalRotation {
    return OrthogonalRotation.init(rawValue: (lhs.rawValue + rhs.rawValue) % 4)!
}
