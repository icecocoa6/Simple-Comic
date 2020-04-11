//
//  NSWindow+SimpleComic.swift
//  Simple Comic
//
//  Original version is created by Alexander Rauchfuss on 7/19/09.
//  Copyright 2009 Dancing Tortoise Software. All rights reserved.
//
//  Ported by Tomioka Taichi on 2020/03/24.
//

import Foundation
import AppKit

extension NSWindow {
    @objc func toolbarHeight() -> CGFloat
    {
        return self.frame.height - (self.contentView?.frame.height ?? 0)
    }


    @objc func isFullscreen() -> Bool
    {
        return self.styleMask.contains(.fullScreen)
    }
}
