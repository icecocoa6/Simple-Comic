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
    
    func fit(into rect: CGRect) -> CGRect {
        let s = self.scaleBy(min(rect.height / self.height, rect.width / self.width, 1.0))
        let x = rect.minX + ((rect.width - s.width) / 2)
        let y = rect.minY + ((rect.height - s.height) / 2)
        return CGRect(x: x, y: y, width: s.width, height: s.height)
    }
    
    func adjust(to size: CGSize) -> CGSize {
        return self.scaleBy(min(size.width / self.width, size.height / self.height))
    }
}
