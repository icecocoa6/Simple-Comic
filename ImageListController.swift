//
//  ImageListController.swift
//  Simple Comic
//
//  Created by Tomioka Taichi on 2020/04/20.
//

import Cocoa

class ImageListController: NSArrayController {
    var sortedImages: [Image] {
        self.arrangedObjects as! [Image]
    }
    
    func select(_ order: SessionWindowController.Order, sender: Any?) {
        switch order {
        case .prev:
            self.selectPrevious(sender)
        case .next:
            self.selectNext(sender)
        }
    }

    /// selects a page next/previous to the current page by `diff` pages, but **does nothing when it exceeds its boundary**.
    func select(_ order: SessionWindowController.Order, by diff: Int, sender: Any?) {
        let contents = self.content as? [Any?]
        let count = contents?.count ?? 0
        let index: Int
        switch order {
        case .prev:
            index = self.selectionIndex - diff
        case .next:
            index = self.selectionIndex + diff
        }
        if (0 ..< count).contains(index) {
            self.setSelectionIndex(index)
        }
    }

    /// selects a page next/previous to the current page by `diff` pages, and it **stops at its boundary**.
    func moveSelection(to order: SessionWindowController.Order, by diff: Int, sender: Any?) {
        let contents = self.content as? [Any?]
        let count = contents?.count ?? 0
        let index: Int
        switch order {
        case .prev:
            index = self.selectionIndex - diff
        case .next:
            index = self.selectionIndex + diff
        }
        self.setSelectionIndex(index.clamp(0 ... (count - 1)))
    }
    
    func canSelectPage(_ selection: SessionWindowController.Order) -> Bool {
        let index = (selection == .prev) ? self.selectionIndex : (self.selectionIndex + 1)
        let contents = self.sortedImages
        let selectedPage = contents[index]

        return selectedPage.isExtractable
    }
    
    func hasTwoPagesSpreadable(from _index: Int? = nil) -> Bool {
        let index = _index ?? self.selectionIndex
        let contents = self.self.sortedImages
        guard (0 ..< contents.count - 1).contains(index) else { return false }

        if index == 0 && UserDefaults.standard.bool(forKey: TSSTLonelyFirstPage) {
            return false
        } else {
            let fst = contents[index]
            let snd = contents[index + 1]
            return !fst.shouldDisplayAlone() && !snd.shouldDisplayAlone()
        }
    }
    
    func canTurnTo(_ side: SessionWindowController.Order) -> Bool {
        switch side {
        case .prev:
            return self.selectionIndex > 0
        case .next:
            let selectionIndex = self.selectionIndex
            let contents = self.content as! [Any]
            if selectionIndex + 1 >= contents.count {
                return false
            }

            let lastTwoPages =
                selectionIndex == contents.count - 2 &&
                self.hasTwoPagesSpreadable(from: selectionIndex)
            if lastTwoPages {
                return false
            }

            return true
        }
    }
    
    func pagesShouldDisplay() -> (Image, Image?) {
        let contents = self.sortedImages
        let count = contents.count
        let index = self.selectionIndex
        let pageOne = contents[index]
        let pageTwo = (index + 1) < count ? contents[index + 1] : nil

        if !self.hasTwoPagesSpreadable() {
            return (pageOne, nil)
        }
        return (pageOne, pageTwo)
    }
    
    var currentPageIsText: Bool {
        let set = self.selectionIndexes
        if set.isEmpty {
            return false
        }
        let page = self.selectedObjects[0] as! Image
        return page.text
    }
}

