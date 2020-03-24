//
//  ToolbarItem.swift
//  Simple Comic
//
//  Created by Alexander Rauchfuss on 7/18/09.
//  Copyright 2009 Dancing Tortoise Software. All rights reserved.
//
//  Ported by Tomioka Taichi on 2020/03/24.
//

import Cocoa

class ToolbarItem: NSToolbarItem {
    override func validate() {
        let toolbarDelegate = self.toolbar?.delegate as! TSSTSessionWindowController
        let control = self.view as! NSControl
        control.isEnabled = !toolbarDelegate.pageSelectionInProgress()
    }
}

class PageTurnToolbarItem: ToolbarItem {
    override func validate() {
        let toolbarDelegate = self.toolbar?.delegate as! TSSTSessionWindowController
        let control = self.view as! NSSegmentedControl
        control.setEnabled(toolbarDelegate.canTurnPageLeft(), forSegment: 0)
        control.setEnabled(toolbarDelegate.canTurnPageRight(), forSegment: 1)
        super.validate()
    }
}
