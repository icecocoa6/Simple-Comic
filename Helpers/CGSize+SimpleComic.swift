//
//  CGSize+SimpleComic.swift
//  Simple Comic
//
//  Created by Tomioka Taichi on 2020/03/31.
//

import Foundation

extension CGSize {
    func scaleBy(x sx: CGFloat, y sy: CGFloat) -> CGSize
    {
        return self.applying(CGAffineTransform.init(scaleX: sx, y: sy))
    }
    
    func scaleBy(_ s: CGFloat) -> CGSize
    {
        return self.scaleBy(x: s, y: s)
    }
    
    var transposed: CGSize {
        return Self.init(width: height, height: width)
    }
    
    func scaleTo(width: CGFloat) -> CGSize {
        guard self.width > 0 else { return CGSize.zero }
        return self.scaleBy(width / self.width)
    }
    
    func scaleTo(height: CGFloat) -> CGSize {
        guard self.height > 0 else { return CGSize.zero }
        return self.scaleBy(height / self.height)
    }
}
