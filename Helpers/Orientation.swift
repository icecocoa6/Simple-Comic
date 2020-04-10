//
//  Orientation.swift
//  Simple Comic
//
//  Created by Tomioka Taichi on 2020/04/10.
//

import Foundation

enum Orientation {
    enum Vertical {
        case up
        case down
    }
    
    @objc enum Horizontal: Int {
        case left
        case right
    }
    
    case vertical(Vertical)
    case horizontal(Horizontal)
    
    static let up = Orientation.vertical(.up)
    static let down = Orientation.vertical(.down)
    static let left = Orientation.horizontal(.left)
    static let right = Orientation.horizontal(.right)
    
    func rotate(by r: OrthogonalRotation) -> Orientation {
        switch r {
        case .r0_4:
            return self
        case .r1_4:
            switch self {
            case .vertical(.up):
                return .horizontal(.left)
            case .horizontal(.left):
                return .vertical(.down)
            case .vertical(.down):
                return .horizontal(.right)
            case .horizontal(.right):
                return .vertical(.up)
            }
        case .r2_4:
            switch self {
            case .vertical(.up):
                return .vertical(.down)
            case .horizontal(.left):
                return .horizontal(.right)
            case .vertical(.down):
                return .vertical(.up)
            case .horizontal(.right):
                return .horizontal(.left)
            }
        case .r3_4:
            switch self {
            case .vertical(.up):
                return .horizontal(.right)
            case .horizontal(.left):
                return .vertical(.up)
            case .vertical(.down):
                return .horizontal(.left)
            case .horizontal(.right):
                return .vertical(.down)
            }
        }
    }
}

func * (lhs: OrthogonalRotation, rhs: Orientation) -> Orientation {
    return rhs.rotate(by: lhs)
}
