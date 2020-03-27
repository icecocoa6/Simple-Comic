//
//  Configuration.swift
//  Simple Comic
//
//  Created by Tomioka Taichi on 2020/03/27.
//

import Foundation

enum BuildConfiguration {
    case debug
    case `default`
    case release
    
    #if BUILD_DEBUG
    static let current: BuildConfiguration = .debug
    #elseif BUILD_DEFAULT
    static let current: BuildConfiguration = .default
    #elseif BUILD_RELEASE
    static let current: BuildConfiguration = .release
    #endif
}
