//
//  SessionWindowController+SimpleComicAction.swift
//  Simple Comic
//
//  Created by Tomioka Taichi on 2020/04/11.
//

import Foundation
import AppKit

@objc protocol SimpleComicAction {
    func changeTwoPage(_ sender: Any)
    func changePageOrder(_ sender: Any)
    func changeScaling(_ sender: Any)
    func turnPage(_ sender: Any)
    func pageRight(_ sender: Any?)
    func pageLeft(_ sender: Any?)
    func shiftPageRight(_ sender: Any)
    func shiftPageLeft(_ sender: Any)
    func skipRight(_ sender: Any)
    func skipLeft(_ sender: Any)
    func firstPage(_ sender: Any)
    func lastPage(_ sender: Any)
    func zoom(_ sender: Any)
    func zoomIn(_ sender: Any)
    func zoomOut(_ sender: Any)
    func zoomReset(_ sender: Any)
    func rotate(_ sender: Any)
    func rotateRight(_ sender: Any?)
    func rotateLeft(_ sender: Any?)
    func noRotation(_ sender: Any)
    func toggleLoupe(_ sender: Any)
    func togglePageExpose(_ sender: Any)
    func launchJumpPanel(_ sender: Any)
    func cancelJumpPanel(_ sender: Any)
    func goToPage(_ sender: Any)
    func removePages(_ sender: Any)
    func setArchiveIcon(_ sender: Any)
    func extractPage(_ sender: Any)
}

extension SessionWindowController: SimpleComicAction {
    @IBAction
    func changeTwoPage(_ sender: Any) {
        session.twoPageSpread = !session.twoPageSpread
    }

    @IBAction
    func changePageOrder(_ sender: Any) {
        session.pageOrder = !session.pageOrder
    }

    @IBAction
    func changeScaling(_ sender: Any) {
        let scaleType = (sender as AnyObject).tag % 400
        session.adjustmentMode = PageAdjustmentMode(rawValue: scaleType)!
    }

    @IBAction
    func turnPage(_ sender: Any) {
        let ctrl = sender as! NSSegmentedControl
        let cell = ctrl.cell as! NSSegmentedCell
        let segmentTag = cell.tag(forSegment: ctrl.selectedSegment)

        if segmentTag == 701 {
            self.pageLeft(self)
        } else if segmentTag == 702 {
            self.pageRight(self)
        }
    }

    /*! Method flips the page to the right calling nextPage or previousPage
        depending on the prefered page ordering.
    */
    @IBAction
    func pageRight(_ sender: Any?) {
        self.pageTurn = .right
        self.turnPage(to: orderTo(side: .right))
    }

    /*! Method flips the page to the left calling nextPage or previousPage
        depending on the prefered page ordering.
    */
    @IBAction
    func pageLeft(_ sender: Any?) {
        self.pageTurn = .left
        self.turnPage(to: orderTo(side: .left))
    }

    @IBAction
    func shiftPageRight(_ sender: Any) {
        self.pageController.select(orderTo(side: .right), sender: sender)
    }

    @IBAction
    func shiftPageLeft(_ sender: Any) {
        self.pageController.select(orderTo(side: .left), sender: sender)
    }

    @IBAction
    func skipRight(_ sender: Any) {
        self.pageController.moveSelection(to: orderTo(side: .right), by: 10, sender: sender)
    }

    @IBAction
    func skipLeft(_ sender: Any) {
        self.pageController.moveSelection(to: orderTo(side: .left), by: 10, sender: sender)
    }

    @IBAction
    func firstPage(_ sender: Any) {
        self.pageController.setSelectionIndex(0)
    }

    @IBAction
    func lastPage(_ sender: Any) {
        let contents = self.pageController.sortedImages
        self.pageController.setSelectionIndex(contents.count - 1)
    }

    @IBAction
    func zoom(_ sender: Any) {
        let ctrl = sender as! NSSegmentedControl
        let cell = ctrl.cell as! NSSegmentedCell
        let segmentTag = cell.tag(forSegment: ctrl.selectedSegment)

        if segmentTag == 801 {
            self.zoomIn(self)
        } else if segmentTag == 802 {
            self.zoomOut(self)
        } else if segmentTag == 803 {
            self.zoomReset(self)
        }
    }
    
    @IBAction
    func zoomIn(_ sender: Any) {
        self.zoom(by: 0.1)
    }

    @IBAction
    func zoomOut(_ sender: Any) {
        self.zoom(by: -0.1)
    }

    @IBAction
    func zoomReset(_ sender: Any) {
        self.session.adjustmentMode = .none
        self.session.zoomLevel = 1.0
        self.pageView.resizeView()
        self.refreshLoupePanel()
    }

    @IBAction
    func rotate(_ sender: Any) {
        let ctrl = sender as! NSSegmentedControl
        let cell = ctrl.cell as! NSSegmentedCell
        let segmentTag = cell.tag(forSegment: ctrl.selectedSegment)

        if segmentTag == 901 {
            self.rotateLeft(self)
        } else if segmentTag == 902 {
            self.rotateRight(self)
        }
    }

    @IBAction
    func rotateRight(_ sender: Any?) {
        var current: Int16 = self.session.rotation
        current = (current + 1) % 4
        self.session.rotation = current
        self.resizeWindow()
        self.refreshLoupePanel()
    }

    @IBAction
    func rotateLeft(_ sender: Any?) {
        var current = self.session.rotation
        current = (current + 3) % 4
        self.session.rotation = current
        self.resizeWindow()
        self.refreshLoupePanel()
    }

    @IBAction
    func noRotation(_ sender: Any) {
        self.session.rotation = 0
        self.resizeWindow()
        self.refreshLoupePanel()
    }

    @IBAction
    func toggleLoupe(_ sender: Any) {
        let loupe = self.session.loupe
        self.session.loupe = !loupe
    }

    @IBAction
    func togglePageExpose(_ sender: Any) {
        if self.exposeBezel.isVisible {
            self.thumbnailPanel.parent?.removeChildWindow(self.thumbnailPanel)
            self.thumbnailPanel.orderOut(self)
            self.exposeBezel.orderOut(self)
            self.window?.makeKeyAndOrderFront(self)
            self.window?.makeFirstResponder(pageView)
        } else {
            NSCursor.unhide()
            self.exposeView.buildTrackingRects()
            self.exposeBezel.setFrame((self.window?.screen!.frame)!, display: false)
            self.exposeBezel.makeKeyAndOrderFront(self)
            DispatchQueue.global(qos: .userInteractive).async {
                self.exposeView.processThumbs()
            }
        }
    }

    @IBAction
    func launchJumpPanel(_ sender: Any) {
        self.jumpField.integerValue = self.pageController.selectionIndex + 1
        self.window?.beginSheet(self.jumpPanel)
    }

    @IBAction
    func cancelJumpPanel(_ sender: Any) {
        self.window?.endSheet(self.jumpPanel, returnCode: .abort)
    }

    @IBAction
    func goToPage(_ sender: Any) {
        if self.jumpField.integerValue != NSNotFound {
            let index = max(0, self.jumpField.integerValue - 1)
            self.pageController.setSelectionIndex(index)
        }

        self.window?.endSheet(self.jumpPanel, returnCode: .continue)
    }

    @IBAction
    func removePages(_ sender: Any) {
        self._pageSelectionInProgress = .Delete
        self.changeViewForSelection()
        self.pageView.startImageSelect(canCrop: false,
                                       onComplete: self.selectedPage,
                                       onCancel: self.cancelPageSelection)
    }

    @IBAction
    func setArchiveIcon(_ sender: Any) {
        self._pageSelectionInProgress = .Icon
        self.changeViewForSelection()
        self.pageView.startImageSelect(canCrop: true,
                                       onComplete: self.selectedPage,
                                       onCancel: self.cancelPageSelection)
    }

    @IBAction
    func extractPage(_ sender: Any) {
        self._pageSelectionInProgress = .Extract
        self.changeViewForSelection()
        self.pageView.startImageSelect(canCrop: false,
                                       onComplete: self.selectedPage,
                                       onCancel: self.cancelPageSelection)
    }
}
