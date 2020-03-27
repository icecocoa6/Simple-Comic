//
//  Comparable+SimpleComic.swift
//  Simple Comic
//
//  Created by Tomioka Taichi on 2020/03/26.
//

import Foundation

extension Comparable {
    func clamp(_ limits: ClosedRange<Self>) -> Self {
        return min(max(limits.lowerBound, self), limits.upperBound)
    }
}
