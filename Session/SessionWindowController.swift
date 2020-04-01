//
//   Copyright (c) 2006-2009 Dancing Tortoise Software
//   Created by Alexander Rauchfuss
//
//   Permission is hereby granted, free of charge, to any person
//   obtaining a copy of this software and associated documentation
//   files (the "Software"), to deal in the Software without
//   restriction, including without limitation the rights to use,
//   copy, modify, merge, publish, distribute, sublicense, and/or
//   sell copies of the Software, and to permit persons to whom the
//   Software is furnished to do so, subject to the following
//   conditions:
//
//   The above copyright notice and this permission notice shall be
//   included in all copies or substantial portions of the Software.
//
//   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//   EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//   OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//   NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//   HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//   WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//   FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//   OTHER DEALINGS IN THE SOFTWARE.
//
//  SessionWindowController.swift
//  Simple Comic
//
//  Ported by Tomioka Taichi on 2020/03/29.
//

import Cocoa

let TSSTPageOrder =         "pageOrder"
let TSSTPageZoomRate =      "pageZoomRate"
let TSSTFullscreen =        "fullscreen"
let TSSTSavedSelection =    "savedSelection"
let TSSTThumbnailSize =     "thumbnailSize"
let TSSTTwoPageSpread =     "twoPageSpread"
let TSSTPageScaleOptions =  "scaleOptions"
let TSSTIgnoreDonation =    "ignoreDonation"
let TSSTScrollPosition =    "scrollPosition"
let TSSTConstrainScale =    "constrainScale"
let TSSTZoomLevel =         "zoomLevel"
let TSSTViewRotation =      "rotation"
let TSSTBackgroundColor =   "pageBackgroundColor"
let TSSTSessionRestore =    "sessionRestore"
let TSSTScrollersVisible =  "scrollersVisible"
let TSSTAutoPageTurn =      "autoPageTurn"
let TSSTWindowAutoResize =  "windowAutoResize"
let TSSTLoupeDiameter =     "loupeDiameter"
let TSSTLoupePower =           "loupePower"
let TSSTStatusbarVisible =  "statusBarVisisble"
let TSSTLonelyFirstPage =   "lonelyFirstPage"
let TSSTNestedArchives =       "nestedArchives"
let TSSTUpdateSelection =   "updateSelection"

let TSSTSessionEndNotification = "sessionEnd"

class SessionWindowController: NSWindowController, NSTextFieldDelegate, NSMenuItemValidation {
    // MARK: - Properties
    /* Controller for all of the page entities related to the session object */
    @IBOutlet var pageController: NSArrayController!

    /* Where the pages are composited.  Handles all of the drawing logic */
    @IBOutlet var pageView: PageView!
    /* There is an outlet to this so that the visibility of the
        scrollers can be manually controlled. */
    @IBOutlet var pageScrollView: NSScrollView!

    /*    Allows the user to jump to a specific page via a small slide in modal dialog. */
    @IBOutlet var jumpPanel: NSPanel!
    @IBOutlet var jumpField: NSTextField!

    /* Progress bar */
    @IBOutlet var progressBar: PolishedProgressBar!

    /* Page info window with caret. */
    @IBOutlet var infoWindow: InfoWindow!
    @IBOutlet var infoPicture: NSImageView!

    /* Localized image zoom loupe elements */
    @IBOutlet var loupeWindow: InfoWindow!
    @IBOutlet var zoomView: NSImageView!

    /* Panel and view for the page expose method */
    @IBOutlet var exposeBezel: NSPanel!
    @IBOutlet var exposeView: ThumbnailView!
    @IBOutlet var thumbnailPanel: InfoWindow!

    /* The session object used to maintain settings */
    @objc dynamic var session: Session?

    /* This var is bound to the session window name */
    @objc dynamic var pageNames: String?
    var pageTurn: Int = 0

    /* Exactly what it sounds like */
    @objc dynamic var pageSortDescriptor: NSArray?

    /* Manages the cursor hiding while in fullscreen */
    var mouseMovedTimer: Timer?

    var newSession: Bool = false

    var savedZoom: Float = 0.0

    enum PageSelectionMode: Int {
        case None = 0
        case Icon = 1
        case Delete = 2
        case Extract = 3
    };
    var _pageSelectionInProgress: PageSelectionMode = .None

    init(window: NSWindow?, session: Session) {
        super.init(window: window)

        self.pageTurn = 0
        self._pageSelectionInProgress = .None
        self.mouseMovedTimer = nil
        self.session = session
        let cascade = session.position == nil
        self.shouldCascadeWindows = cascade
        /* Make sure that the session does not start out in fullscreen, nor with the loupe enabled. */
        self.session?.loupe = false
        let fileNameSort = TSSTSortDescriptor.init(key: "imagePath", ascending: true)
        let archivePathSort = TSSTSortDescriptor.init(key: "group.path", ascending: true)
        self.pageSortDescriptor = [archivePathSort, fileNameSort]
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func awakeFromNib() {
        /* This needs to be set as the window subclass that the expose window
        uses has mouse events turned off by default */
        self.exposeBezel.ignoresMouseEvents = false
        self.exposeBezel.isFloatingPanel = true
        self.exposeBezel.windowController = self
        self.window?.acceptsMouseMovedEvents = true
        self.pageController.setSelectionIndex(self.session!.selection!.intValue)

        UserDefaults.standard.addObserver(self, forKeyPath: TSSTConstrainScale, options: [], context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: TSSTStatusbarVisible, options: [], context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: TSSTScrollersVisible, options: [], context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: TSSTBackgroundColor, options: [], context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: TSSTLoupeDiameter, options: [], context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: TSSTLoupePower, options: [], context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: TSSTPageOrder, options: [], context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: TSSTPageScaleOptions, options: [], context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: TSSTTwoPageSpread, options: [], context: nil)
        self.session?.addObserver(self, forKeyPath: TSSTPageOrder, options: [], context: nil)
        self.session?.addObserver(self, forKeyPath: TSSTPageScaleOptions, options: [], context: nil)
        self.session?.addObserver(self, forKeyPath: TSSTTwoPageSpread, options: [], context: nil)
        self.session?.addObserver(self, forKeyPath: "loupe", options: [], context: nil)
        self.session?.bind(NSBindingName(rawValue: "selection"), to: pageController!, withKeyPath: "selectionIndex", options: nil)

        self.pageScrollView.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification, object: self.pageScrollView, queue: nil) { (_) in
            self.resizeView()
        }
        self.pageController.addObserver(self, forKeyPath: "selectionIndex", options: [], context: nil)
        self.pageController.addObserver(self, forKeyPath: "arrangedObjects.@count", options: [], context: nil)

        self.progressBar.addObserver(self, forKeyPath: "currentValue", options: [], context: nil)
        self.progressBar.bind(NSBindingName(rawValue: "currentValue"), to: self.pageController!, withKeyPath: "selectionIndex", options: nil)
        self.progressBar.bind(NSBindingName(rawValue: "maxValue"), to: self.pageController!, withKeyPath: "arrangedObjects.@count", options: nil)
        self.progressBar.bind(NSBindingName(rawValue: "leftToRight"), to: session!, withKeyPath: TSSTPageOrder, options: nil)

        self.pageView.bind(NSBindingName(rawValue: "rotationValue"), to: self.session!, withKeyPath: TSSTViewRotation, options: nil)
        let newArea = NSTrackingArea.init(rect: self.progressBar.progressRect,
                                          options: [.mouseEnteredAndExited, .activeInKeyWindow, .activeInActiveApp],
                                          owner: self,
                                          userInfo: ["purpose" : "normalProgress"])
        self.progressBar.addTrackingArea(newArea)
        self.jumpField.delegate = self
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "SCMouseDragNotification"), object: self, queue: nil) {
            self.handleMouseDragged($0)
        }
        self.restoreSession()
    }

    override var windowNibName: NSNib.Name? { "TSSTSessionWindow" }

    deinit {
        self.exposeView.dataSource = nil
        UserDefaults.standard.removeObserver(self, forKeyPath: TSSTStatusbarVisible)
        UserDefaults.standard.removeObserver(self, forKeyPath: TSSTScrollersVisible)
        UserDefaults.standard.removeObserver(self, forKeyPath: TSSTBackgroundColor)
        UserDefaults.standard.removeObserver(self, forKeyPath: TSSTConstrainScale)
        UserDefaults.standard.removeObserver(self, forKeyPath: TSSTLoupeDiameter)
        UserDefaults.standard.removeObserver(self, forKeyPath: TSSTLoupePower)
        self.pageController.removeObserver(self, forKeyPath: "selectionIndex")
        self.pageController.removeObserver(self, forKeyPath: "arrangedObjects.@count")
        NotificationCenter.default.removeObserver(self)

        self.progressBar.removeObserver(self, forKeyPath: "currentValue")
        self.progressBar.unbind(NSBindingName(rawValue: "currentvalue"))
        self.progressBar.unbind(NSBindingName(rawValue: "maxValue"))
        self.progressBar.unbind(NSBindingName(rawValue: "leftToRight"))

        self.pageView.sessionController = nil
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        let contents = self.pageController.arrangedObjects as! [Any]
        if (contents.count <= 0) {
            self.close()
            return
        }

        switch keyPath {
        case TSSTScrollersVisible:
            self.scaleToWindow()
        case "currentValue":
            if object as? PolishedProgressBar == self.progressBar {
                self.pageController.setSelectionIndex(self.progressBar.currentValue)
            }
        case "arrangedObjects.@count":
            DispatchQueue.global().async {
                self.exposeView.processThumbs()
            }
            self.changeViewImages()
        case TSSTPageOrder:
            if object as? UserDefaults != UserDefaults.standard {
                UserDefaults.standard.set(self.session?.pageOrder, forKey: TSSTPageOrder)
            }
            self.exposeView.needsDisplay = true
            self.exposeView.buildTrackingRects()
            self.changeViewImages()
        case TSSTPageScaleOptions:
            if object as? UserDefaults != UserDefaults.standard {
                UserDefaults.standard.set(self.session?.scaleOptions, forKey: TSSTPageScaleOptions)
            }
            self.scaleToWindow()
        case TSSTTwoPageSpread:
            if object as? UserDefaults != UserDefaults.standard {
                UserDefaults.standard.set(self.session?.twoPageSpread, forKey: TSSTTwoPageSpread)
            }
            self.changeViewImages()
        case TSSTBackgroundColor:
            let color = try! NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: UserDefaults.standard.data(forKey: TSSTBackgroundColor)!)
            self.pageScrollView.backgroundColor = color!
        case TSSTStatusbarVisible:
            self.adjustStatusBar()
        case TSSTLoupeDiameter:
            let diameter = UserDefaults.standard.integer(forKey: TSSTLoupePower)
            self.loupeWindow.resize(toDiameter: CGFloat(diameter))
        case "loupe":
            self.refreshLoupePanel()
        case TSSTLoupePower:
            self.refreshLoupePanel()
        default:
            self.changeViewImages()
        }
    }

    // MARK: - Progress bar
    @objc func imageForPageAtIndex(_ index: Int) -> NSImage? {
        return (pageController.arrangedObjects as! [Image])[index].thumbnail
    }

    func nameForPageAtIndex(_ index: Int) -> String? {
        return (pageController.arrangedObjects as! [Image])[index].name
    }

    // MARK: - Event handling
    override func mouseEntered(with event: NSEvent) {
        let dict = event.trackingArea?.userInfo as? [String : String]
        let purpose = dict?["purpose"]
        if purpose == "normalProgress" {
            self.infoPanelSetupAtPoint(event.locationInWindow)
            self.window?.addChildWindow(infoWindow, ordered: .above)
        }
    }

    override func mouseMoved(with event: NSEvent) {
        let progressRect = progressBar.convert(progressBar.progressRect, to: nil)
        let loc = event.locationInWindow
        if NSMouseInRect(loc, progressRect, progressBar.isFlipped) {
            self.infoPanelSetupAtPoint(loc)
        }
        self.refreshLoupePanel()
    }

    override func mouseExited(with event: NSEvent) {
        if event.trackingArea != nil {
            self.infoWindow.parent?.removeChildWindow(self.infoWindow)
            self.infoWindow.orderOut(self)
        }
    }

    /* Handles mouse drag notifications relayed from progressbar */
    func handleMouseDragged(_ notification: Notification) {
        self.infoWindow.orderOut(self)
    }

    func refreshLoupePanel() {
        let loupe = session?.loupe?.boolValue ?? false
        let mouse = NSEvent.mouseLocation
        let point = CGRect.init(origin: mouse, size: CGSize.zero)
        let scrollPoint = self.pageScrollView.convert((self.window?.convertFromScreen(point).origin)!, from: nil)

        if NSMouseInRect(scrollPoint, self.pageScrollView.bounds, self.pageScrollView.isFlipped)
            && loupe
            && self.window?.isKeyWindow ?? false
            && self._pageSelectionInProgress == .None
            {
            if !self.loupeWindow.isVisible
                {
                self.window?.addChildWindow(loupeWindow, ordered: .above)
                NSCursor.hide()
            }

            let localPoint = self.pageView.convert((self.window?.convertFromScreen(point).origin)!, from: nil)
            var zoomRect = self.zoomView.frame
            self.loupeWindow.center(atPoint: mouse)
            zoomRect.origin = localPoint
            self.zoomView.image = self.pageView.image(inRect: zoomRect)
        }
        else
        {
            if self.loupeWindow.isVisible
                {
                self.loupeWindow.parent?.removeChildWindow(self.loupeWindow)
                self.loupeWindow.orderOut(self)
            }

            NSCursor.unhide()
        }
    }

    func infoPanelSetupAtPoint(_ _point: NSPoint) {
        var point = _point
        let bar = self.progressBar
        (self.infoWindow.contentView as! InfoView).bordered = false
        point.y = bar!.frame.maxY - 6
        let cursorPoint = bar?.convert(point, from: nil)
        let index = bar?.indexFor(point: cursorPoint!)

        let thumb = self.imageForPageAtIndex(index!)
        let thumbSize = sizeConstrainedByDimension(thumb!.size, 128)

        self.infoPicture.setFrameSize(thumbSize)
        self.infoPicture.image = thumb

        let area = CGRect.init(origin: point, size: CGSize.zero)
        let _cursorPoint = self.window?.convertToScreen(area).origin
        self.infoWindow.caret(atPoint: _cursorPoint!,
                              size: thumbSize,
                              withLimitLeft: (bar?.window!.frame.minX)!,
                              right: (bar?.window!.frame.maxX)!)
    }

    // MARK: - Actions

    @IBAction
    func changeTwoPage(_ sender: Any) {
        if let session = self.session {
            session.twoPageSpread = !session.twoPageSpread!.boolValue as NSNumber
        }
    }

    @IBAction
    func changePageOrder(_ sender: Any) {
        if let session = self.session {
            session.pageOrder = !session.pageOrder!.boolValue as NSNumber
        }
    }

    @IBAction
    func changeScaling(_ sender: Any) {
        let scaleType = (sender as AnyObject).tag % 400
        session?.scaleOptions = scaleType as NSNumber
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
    func pageRight(_ sender: Any) {
        self.pageTurn = 2

        if (self.session?.pageOrder!.boolValue)! {
            self.nextPage()
        } else {
            self.previousPage()
        }
    }

    /*! Method flips the page to the left calling nextPage or previousPage
        depending on the prefered page ordering.
    */
    @IBAction
    func pageLeft(_ sender: Any) {
        self.pageTurn = 1

        if (self.session?.pageOrder!.boolValue)! {
            self.previousPage()
        } else {
            self.nextPage()
        }
    }

    @IBAction
    func shiftPageRight(_ sender: Any) {
        if self.session?.pageOrder?.boolValue ?? false {
            self.pageController.selectNext(sender)
        } else {
            self.pageController.selectPrevious(sender)
        }
    }

    @IBAction
    func shiftPageLeft(_ sender: Any) {
        if self.session?.pageOrder?.boolValue ?? false {
            self.pageController.selectPrevious(sender)
        } else {
            self.pageController.selectNext(sender)
        }

    }

    @IBAction
    func skipRight(_ sender: Any) {
        var index: Int
        if self.session?.pageOrder?.boolValue ?? false {
            let contents = self.pageController.content as! [Any]
            index = min(self.pageController.selectionIndex + 10, contents.count - 1)
        } else {
            index = max(self.pageController.selectionIndex - 10, 0)
        }

        self.pageController.setSelectionIndex(index)
    }

    @IBAction
    func skipLeft(_ sender: Any) {
        var index: Int
        if self.session?.pageOrder?.boolValue ?? false {
            index = max(self.pageController.selectionIndex - 10, 0)
        } else {
            let contents = self.pageController.content as! [Any]
            index = min(self.pageController.selectionIndex + 10, contents.count - 1)
        }

        self.pageController.setSelectionIndex(index)
    }

    @IBAction
    func firstPage(_ sender: Any) {
        self.pageController.setSelectionIndex(0)
    }

    @IBAction
    func lastPage(_ sender: Any) {
        let contents = self.pageController.content as! [Any]
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
        let option: Int = (self.session?.scaleOptions!.intValue)!
        var previousZoom: Float = (self.session?.zoomLevel!.floatValue)!

        if option != 0 {
            previousZoom = Float(self.pageView.imageBounds.width / self.pageView.combinedImageSize().width)
        }

        self.session?.zoomLevel = previousZoom + 0.1 as NSNumber
        self.session?.scaleOptions = 0

        self.pageView.resizeView()
        self.refreshLoupePanel()
    }

    @IBAction
    func zoomOut(_ sender: Any) {
        let option: Int = (self.session?.scaleOptions!.intValue)!
        var previousZoom: Float = (self.session?.zoomLevel!.floatValue)!

        if option != 0 {
            previousZoom = Float(self.pageView.imageBounds.width / self.pageView.combinedImageSize().width)
        }

        self.session?.zoomLevel = previousZoom - 0.1 as NSNumber
        self.session?.scaleOptions = 0

        self.pageView.resizeView()
        self.refreshLoupePanel()
    }

    @IBAction
    func zoomReset(_ sender: Any) {
        self.session?.scaleOptions = 0
        self.session?.zoomLevel = 1.0
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
    func rotateRight(_ sender: Any) {
        var current: Int = (self.session?.rotation!.intValue)!
        current = (current + 1) % 4
        self.session?.rotation = current as NSNumber
        self.resizeWindow()
        self.refreshLoupePanel()
    }

    @IBAction
    func rotateLeft(_ sender: Any) {
        var current: Int = (self.session?.rotation!.intValue)!
        current = (current - 1) % 4
        self.session?.rotation = current as NSNumber
        self.resizeWindow()
        self.refreshLoupePanel()
    }

    @IBAction
    func noRotation(_ sender: Any) {
        self.session?.rotation = 0
        self.resizeWindow()
        self.refreshLoupePanel()
    }

    @IBAction
    func toggleLoupe(_ sender: Any) {
        let loupe = (self.session?.loupe!.boolValue)!
        self.session?.loupe = !loupe as NSNumber
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

    @IBAction @objc
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
    }

    @IBAction
    func setArchiveIcon(_ sender: Any) {
        self._pageSelectionInProgress = .Icon
        self.changeViewForSelection()
    }

    @IBAction
    func extractPage(_ sender: Any) {
        self._pageSelectionInProgress = .Extract
        self.changeViewForSelection()
    }

    func pageSelectionCanCrop() -> Bool {
        _pageSelectionInProgress == .Icon
    }

    func changeViewForSelection() {
        self.savedZoom = (self.session?.zoomLevel!.floatValue)!
        self.pageScrollView.hasVerticalScroller = false
        self.pageScrollView.hasHorizontalScroller = false
        self.refreshLoupePanel()

        let imageSize = self.pageView.combinedImageSize()
        var scrollerBounds = (self.pageView.enclosingScrollView?.bounds.size)!
        scrollerBounds.width -= 20
        scrollerBounds.height -= 20

        let factor: CGFloat
        if imageSize.width / imageSize.height > scrollerBounds.width / scrollerBounds.height {
            factor = scrollerBounds.width / imageSize.width
        } else {
            factor = scrollerBounds.height / imageSize.height
        }

        self.session?.zoomLevel = factor as NSNumber
        self.pageView.resizeView()
    }

    func canSelectPageIndex(_ selection: Int) -> Bool {
        let index = self.pageController.selectionIndex + selection
        let contents = self.pageController.arrangedObjects as! [Image]
        let selectedPage = contents[index]
        let selectedGroup = selectedPage.group

        /* Makes sure that the group is both an archive and not nested */
        return (selectedGroup?.isKind(of: Archive.self))! &&
            selectedGroup == selectedGroup?.topLevelGroup &&
            !selectedPage.text!.boolValue
    }

    func pageSelectionInProgress() -> Bool {
        self._pageSelectionInProgress != .None
    }

    func cancelPageSelection() {
        self.session?.zoomLevel = self.savedZoom as NSNumber
        self._pageSelectionInProgress = .None
        self.scaleToWindow()
    }

    func selectedPage(_ selection: Int, withCropRect crop: NSRect) {
        switch _pageSelectionInProgress {
        case .Icon:
            self.setIconWithSelection(selection, andCropRect: crop)
        case .Delete:
            self.deletePageWithSelection(selection)
        case .Extract:
            self.extractPageWithSelection(selection)
        default:
            break
        }

        self.session?.zoomLevel = self.savedZoom as NSNumber
        self._pageSelectionInProgress = .None
        self.scaleToWindow()
    }

    func deletePageWithSelection(_ selection: Int) {
        guard selection != -1 else { return }

        let index = self.pageController.selectionIndex + selection
        let contents = self.pageController.arrangedObjects as! [Image]
        let selectedPage = contents[index]
        self.pageController.removeObject(selectedPage)
        self.managedObjectContext.delete(selectedPage)
    }

    func extractPageWithSelection(_ selection: Int) {
        /*    selectpage returns prompts the user for which page they wish to use.
        If there is only one page or the user selects the first page 0 is returned,
        otherwise 1. */
        guard selection != -1 else { return }

        let index = self.pageController.selectionIndex + selection
        let contents = self.pageController.arrangedObjects as! [Image]
        let selectedPage = contents[index]

        let savePanel = NSSavePanel.init()
        savePanel.title = "Extract Page"
        savePanel.prompt = "Extract"
        savePanel.nameFieldStringValue = selectedPage.name!

        if savePanel.runModal() == .OK {
            try! selectedPage.pageData?.write(to: savePanel.url!)
        }
    }

    func setIconWithSelection(_ selection: Int, andCropRect cropRect: CGRect) {
        self.session?.zoomLevel = self.savedZoom as NSNumber

        guard selection != -1 else { return }

        let index = self.pageController.selectionIndex + selection
        let contents = self.pageController.arrangedObjects as! [Image]
        let selectedPage = contents[index]
        let selectedGroup = selectedPage.group

        /* Makes sure that the group is both an archive and not nested */
        if (selectedGroup?.isKind(of: Archive.self))! &&
            selectedGroup == selectedGroup?.topLevelGroup &&
            !selectedPage.text!.boolValue {
            let archive = selectedGroup as! Archive
            let archivePath = URL.init(fileURLWithPath: selectedGroup!.path!).standardizedFileURL.path

            if archive.quicklookCompatible() {
                let coverIndex = selectedPage.index!.intValue
                let xad = selectedGroup?.instance as! XADArchive
                let coverName = xad.rawName(ofEntry: Int32(coverIndex))

                UKXattrMetadataStore.setString(coverName?.string(withEncoding: String.Encoding.nonLossyASCII.rawValue),
                                               forKey: "QCCoverName",
                                               atPath: archivePath,
                                               traverseLink: false)
                UKXattrMetadataStore.setString(NSStringFromRect(cropRect),
                                               forKey: "QCCoverRect",
                                               atPath: archivePath,
                                               traverseLink: false)

                Process.launchedProcess(launchPath: "/usr/bin/touch", arguments: [archivePath])
            } else {
                var drawRect = CGRect.init(x: 0, y: 0, width: 496, height: 496)
                let iconImage = NSImage.init(size: drawRect.size)
                let size = cropRect.size == CGSize.zero
                    ? CGSize.init(width: CGFloat(selectedPage.width!.floatValue),
                                  height: CGFloat(selectedPage.height!.floatValue))
                    : cropRect.size
                drawRect = rectWithSizeCenteredInRect(size, drawRect)

                iconImage.lockFocus()
                NSGraphicsContext.current?.imageInterpolation = .high
                selectedPage.pageImage?.draw(in: drawRect, from: CGRect.init(origin: cropRect.origin, size: size), operation: .sourceOver, fraction: 1)
                iconImage.unlockFocus()

                let shadowImage = NSImage.init(size: CGSize.init(width: 512, height: 512))
                let thumbShadow = NSShadow.init()
                thumbShadow.shadowOffset = CGSize.init(width: 0.0, height: -8.0)
                thumbShadow.shadowBlurRadius = 25.0
                thumbShadow.shadowColor = NSColor.init(calibratedWhite: 0.2, alpha: 1.0)

                shadowImage.lockFocus()
                thumbShadow.set()
                iconImage.draw(in: CGRect.init(x: 16, y: 16, width: 496, height: 496), from: CGRect.zero, operation: .sourceOver, fraction: 1)
                shadowImage.unlockFocus()

                NSWorkspace.shared.setIcon(shadowImage, forFile: archivePath, options: [])
            }
        }
    }

    // MARK: - Convenience Methods

    func hideCursor() {
        self.mouseMovedTimer = nil

        if (self.window?.isFullscreen())! {
            NSCursor.setHiddenUntilMouseMoves(true)
        }
    }

    /*  When a session is launched this method is called.  It checks to see if the
    session was a saved session or one that is brand new.  If it was a saved
    session then all of the saved session information is passed to the window
    and view. */
    func restoreSession() {
        self.changeViewImages()
        self.scaleToWindow()
        self.adjustStatusBar()
        let loupeDiameter = UserDefaults.standard.integer(forKey: TSSTLoupeDiameter)
        self.loupeWindow.setFrame(CGRect.init(x: 0, y: 0, width: loupeDiameter, height: loupeDiameter), display: false)
        let color = try! NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: UserDefaults.standard.data(forKey: TSSTBackgroundColor)!)
        self.pageScrollView.backgroundColor = color!
        self.pageView.rotationValue = (self.session?.rotation!.intValue)!
        if let posData = self.session?.position {
            let positionValue = try! NSKeyedUnarchiver.unarchivedObject(ofClass: NSValue.self, from: posData)
            self.window?.setFrame(positionValue!.rectValue, display: false)

            if let scrollData = self.session?.scrollPosition {
                self.shouldCascadeWindows = false
                let pos = try! NSKeyedUnarchiver.unarchivedObject(ofClass: NSValue.self, from: scrollData)
                self.pageView.scroll(pos!.pointValue)
            }
        } else {
            self.newSession = true
            self.shouldCascadeWindows = true
            self.window?.zoom(self)
            self.pageView.correctViewPoint()
        }
    }

    /*  This method figures out which pages should be displayed in the view.
    To do so it looks at which page is currently selected as well as its aspect ratio
    and that of the next image */
    func changeViewImages() {
        let contents = self.pageController.arrangedObjects as! [Image]
        let count = contents.count
        let index = self.pageController.selectionIndex
        let pageOne = contents[index]
        var pageTwo = (index + 1) < count ? contents[index + 1] : nil
        var titleString = pageOne.name!

        let currentAllowed = !pageOne.shouldDisplayAlone() && !(index == 0 && UserDefaults.standard.bool(forKey: TSSTLonelyFirstPage))

        if currentAllowed && self.session?.twoPageSpread?.boolValue ?? false && pageTwo != nil && !pageTwo!.shouldDisplayAlone() {
            if self.session?.pageOrder?.boolValue ?? false {
                titleString = "\(titleString) \(pageTwo!.name!)"
            } else {
                titleString = "\(pageTwo!.name!) \(titleString)"
            }
        } else {
            pageTwo = nil
        }

        let representationPath = pageOne.group != nil
            ? (pageOne.group?.topLevelGroup as! ImageGroup).path
            : pageOne.imagePath
        self.window?.representedFilename = representationPath!
        self.window?.title = titleString
        self.pageNames = titleString

        if pageOne.imageSource != nil {
            self.pageView.setSource(first: pageOne.imageSource!,
                                    CGSize.init(width: CGFloat(pageOne.width!.floatValue),
                                                height: CGFloat(pageOne.height!.floatValue)),
                                    second: pageTwo?.imageSource,
                                    CGSize.init(width: CGFloat(pageTwo?.width?.floatValue ?? 0),
                                                height: CGFloat(pageTwo?.height?.floatValue ?? 0)))
        }

        self.scaleToWindow()
        self.pageView.correctViewPoint()
        self.refreshLoupePanel()
    }

    func resizeWindow() {
        if self.window?.isFullscreen() ?? false {
            let allowedRect = self.window!.screen!.frame
            self.window?.setFrame(allowedRect, display: true, animate: false)
        } else if UserDefaults.standard.bool(forKey: TSSTWindowAutoResize) {
            let allowedRect = self.window!.screen!.frame
            let frame = self.window!.frame
            let rect = CGRect.init(x: frame.minX,
                                   y: allowedRect.minY,
                                   width: allowedRect.maxX - frame.minX,
                                   height: frame.maxY - allowedRect.minY)
            let zoomFrame = self.optimalPageViewRectForRect(rect)
            self.window?.setFrame(zoomFrame, display: true, animate: false)
        }
    }

    func scaleToWindow() {
        var hasVert = false
        var hasHor = false
        var scaling = session?.scaleOptions?.intValue ?? 0

        if _pageSelectionInProgress != .None || !UserDefaults.standard.bool(forKey: TSSTScrollersVisible) {
            scaling = 1
        } else if self.currentPageIsText() {
            scaling = 2
        }

        switch scaling {
        case 0:
            hasVert = true
            hasHor = true
        case 2:
            self.session?.zoomLevel = 1.0
            if self.pageView.rotationValue == 1 || self.pageView.rotationValue == 3 {
                hasHor = true
            } else {
                hasVert = true
            }
        default:
            self.session?.zoomLevel = 1.0
        }

        self.pageScrollView.hasVerticalScroller = hasVert
        self.pageScrollView.hasHorizontalScroller = hasHor

        if self._pageSelectionInProgress == .None {
            self.resizeWindow()
        }

        self.pageView.resizeView()
        self.refreshLoupePanel()
    }

    func adjustStatusBar() {
        let statusBar = UserDefaults.standard.bool(forKey: TSSTStatusbarVisible)

        if statusBar {
            var scrollViewRect = self.window!.contentView!.frame
            scrollViewRect = CGRect.init(x: scrollViewRect.minX,
                                         y: scrollViewRect.minY + 23,
                                         width: scrollViewRect.width,
                                         height: scrollViewRect.height - 23)

            self.window?.setContentBorderThickness(23, for: .minY)
            self.pageScrollView.frame = scrollViewRect
            self.progressBar.isHidden = false
            self.resizeWindow()
        } else {
            let scrollViewRect = self.window!.contentView!.frame
            self.progressBar.isHidden = true
            self.pageScrollView.frame = scrollViewRect
            self.window?.setContentBorderThickness(0, for: .minY)
            self.resizeWindow()
        }
    }

    /*! Selects the next non visible page.  Logic looks figures out which
    images are currently visible and then skips over them.
    */
    func nextPage() {
        if !(self.session?.twoPageSpread?.boolValue ?? true) {
            self.pageController.selectNext(self)
            return
        }

        let contents = self.pageController.arrangedObjects as! [Image]
        let numberOfImages = contents.count
        let selectionIndex = self.pageController.selectionIndex
        if numberOfImages <= selectionIndex + 1 {
            return
        }

        let current = !contents[selectionIndex].shouldDisplayAlone() && !(selectionIndex == 0 && UserDefaults.standard.bool(forKey: TSSTLonelyFirstPage))
        let next = !contents[selectionIndex + 1].shouldDisplayAlone()

        if (!current || !next) && (selectionIndex + 1 < numberOfImages) {
            self.pageController.setSelectionIndex(selectionIndex + 1)
        } else if selectionIndex + 2 < numberOfImages {
            self.pageController.setSelectionIndex(selectionIndex + 2)
        } else if (selectionIndex + 1 < numberOfImages) && !next {
            self.pageController.setSelectionIndex(selectionIndex + 1)
        }
    }

    /*! Selects the previous non visible page.  Logic looks figures out which
    images are currently visible and then skips over them.
    */
    func previousPage() {
        if !(self.session?.twoPageSpread?.boolValue ?? true) {
            self.pageController.selectPrevious(self)
            return
        }

        let selectionIndex = self.pageController.selectionIndex
        if selectionIndex >= 2 {
            let contents = self.pageController.arrangedObjects as! [Image]
            let previousPage = !contents[selectionIndex - 1].shouldDisplayAlone()
            let pageBeforeLast = !contents[selectionIndex - 2].shouldDisplayAlone()
                && !(selectionIndex - 2 == 0 && UserDefaults.standard.bool(forKey: TSSTLonelyFirstPage))

            if !previousPage || !pageBeforeLast {
                self.pageController.setSelectionIndex(selectionIndex - 1)
            } else {
                self.pageController.setSelectionIndex(selectionIndex - 2)
            }
        } else if 1 <= selectionIndex {
            self.pageController.setSelectionIndex(selectionIndex - 1)
        }
    }

    /*! This method is called in preparation for saving. */
    func updateSessionObject() {
        let window = self.window!

        if window.isFullscreen() {
            self.session?.scrollPosition = nil
        } else {
            let posData = try! NSKeyedArchiver.archivedData(withRootObject: window.frame, requiringSecureCoding: true)
            self.session?.position = posData

            let scrData = try! NSKeyedArchiver.archivedData(withRootObject: self.pageView.enclosingScrollView!.documentVisibleRect.origin, requiringSecureCoding: true)
            self.session?.scrollPosition = scrData
        }
    }

    func killTopOptionalUIElement() {
        if self.exposeBezel.isVisible {
            self.exposeBezel.removeChildWindow(thumbnailPanel)
            self.thumbnailPanel.orderOut(self)
            self.exposeBezel.orderOut(self)
        } else if self.window!.isFullscreen() {
            self.window!.toggleFullScreen(self)
        } else if self.session?.loupe?.boolValue ?? false {
            self.session?.loupe = false
        }
    }

    func killAllOptionalUIElements() {
        if self.window!.isFullscreen() {
            self.window?.toggleFullScreen(self)
        }

        self.session?.loupe = false
        self.refreshLoupePanel()
        self.exposeBezel.removeChildWindow(self.thumbnailPanel)
        self.thumbnailPanel.orderOut(self)
        self.exposeBezel.orderOut(self)
    }

    // MARK: - Binding Methods

    @objc var managedObjectContext: NSManagedObjectContext {
        (NSApp.delegate as! SimpleComicAppDelegate).managedObjectContext
    }

    var canTurnPageLeft: Bool {
        if self.session!.pageOrder!.boolValue {
            return self.canTurnPreviousPage
        } else {
            return self.canTurnPageNext
        }
    }
    var canTurnPageRight: Bool {
        if self.session!.pageOrder!.boolValue {
            return self.canTurnPageNext
        } else {
            return self.canTurnPreviousPage
        }
    }

    /*    TODO: make the following a bit smarter.  Also the next/previous page turn logic
    ie. Should not be able to turn the page if 2 pages from the end */
    var canTurnPreviousPage: Bool { pageController.selectionIndex > 0 }
    var canTurnPageNext: Bool {
        let selectionIndex = self.pageController.selectionIndex
        let contents = self.pageController.content as! [Any]
        if selectionIndex >= (contents.count - 1) {
            return false
        }

        if (selectionIndex + 1) == (contents.count - 1) && self.session!.twoPageSpread!.boolValue {
            let arrangedPages = self.pageController.arrangedObjects as! [Image]
            let displayCurrentAlone = arrangedPages[selectionIndex].shouldDisplayAlone()
            let displayNextAlone = arrangedPages[selectionIndex + 1].shouldDisplayAlone()

            if !displayCurrentAlone && !displayNextAlone {
                return false
            }
        }

        return true
    }

    // MARK: - Menus
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard _pageSelectionInProgress == .None else { return false }

        if menuItem.action == #selector(NSWindow.toggleFullScreen(_:)) {
            let state = self.window!.isFullscreen()
                ? NSControl.StateValue.on
                : NSControl.StateValue.off
            menuItem.state = state
            return true
        } else if menuItem.action == #selector(changeTwoPage(_:)) {
            let state = self.session!.pageOrder!.boolValue
                ? NSControl.StateValue.on
                : NSControl.StateValue.off;
            menuItem.state = state
            return true
        } else if menuItem.action == #selector(changePageOrder(_:)) {
            if self.session!.pageOrder!.boolValue {
                menuItem.title = NSLocalizedString("Right To Left", tableName: "Right to left page order menu item text", comment: "")
            } else {
                menuItem.title = NSLocalizedString("Left To Right", tableName: "Left to right page order menu item text", comment: "")
            }
            return true
        } else if menuItem.action == #selector(pageRight(_:)) {
            return self.canTurnPageRight
        }
        else if menuItem.action == #selector(pageLeft(_:)) {
            return self.canTurnPageLeft
        } else if menuItem.action == #selector(firstPage(_:)) {
            return self.pageController.selectionIndex > 0
        } else if menuItem.action == #selector(lastPage(_:)) {
            let contents = self.pageController.content as! [Any]
            return self.pageController.selectionIndex < (contents.count - 1)
        } else if menuItem.action == #selector(shiftPageRight(_:)) {
            return self.canTurnPageRight
        } else if menuItem.action == #selector(shiftPageLeft(_:)) {
            return self.canTurnPageLeft
        } else if menuItem.action == #selector(skipRight(_:)) {
            return self.canTurnPageRight
        } else if menuItem.action == #selector(skipLeft(_:)) {
            return self.canTurnPageLeft
        } else if menuItem.action == #selector(setArchiveIcon(_:)) {
            return self.session!.rotation!.intValue == 0
        } else if menuItem.action == #selector(extractPage(_:)) {
            return self.session!.rotation!.intValue == 0
        } else if menuItem.action == #selector(removePages(_:)) {
            return self.session!.rotation!.intValue == 0
        } else if menuItem.tag == 400 {
            let state = self.session!.scaleOptions!.intValue == 0
                ? NSControl.StateValue.on
                : NSControl.StateValue.off
            menuItem.state = state
            return true
        } else if menuItem.tag == 401 {
            let state = self.session!.scaleOptions!.intValue == 1
                ? NSControl.StateValue.on
                : NSControl.StateValue.off
            menuItem.state = state
            return true
        } else if menuItem.tag == 402 {
            let state = self.session!.scaleOptions!.intValue == 2
                ? NSControl.StateValue.on
                : NSControl.StateValue.off
            menuItem.state = state
            return true
        } else if menuItem.action == #selector(launchJumpPanel(_:)) {
            return true
        } else if menuItem.action == #selector(togglePageExpose(_:)) {
            return true
        } else if menuItem.action == #selector(toggleLoupe(_:)) {
            return true
        } else if menuItem.action == #selector(zoomIn(_:)) {
            return true
        } else if menuItem.action == #selector(zoomOut(_:)) {
            return true
        } else if menuItem.action == #selector(zoomReset(_:)) {
            return true
        } else if menuItem.action == #selector(rotateLeft(_:)) {
            return true
        } else if menuItem.action == #selector(rotateRight(_:)) {
            return true
        } else if menuItem.action == #selector(noRotation(_:)) {
            return true
        }

        return false
    }

    // MARK: Delegates
    func control(_ control: NSControl, didFailToFormatString string: String, errorDescription error: String?) -> Bool {
        let contents = self.pageController.arrangedObjects as! [Any]
        let pageNumber = Int.init(string)
        if pageNumber == nil || contents.count < pageNumber! {
            self.jumpField.integerValue = contents.count
        } else {
            NSSound.beep()
            self.jumpField.integerValue = self.pageController.selectionIndex + 1
        }

        return true
    }

    func prepareToEnd() {
        self.window?.acceptsMouseMovedEvents = false
        self.mouseMovedTimer?.invalidate()
        self.mouseMovedTimer = nil

        NSCursor.unhide()
        NSApp.presentationOptions = NSApplication.PresentationOptions.init()

        self.progressBar.removeObserver(self, forKeyPath: "currentValue")
        self.progressBar.unbind(NSBindingName(rawValue: "currentValue"))
        self.progressBar.unbind(NSBindingName(rawValue: "maxValue"))
        self.progressBar.unbind(NSBindingName(rawValue: "leftToRight"))

        self.pageView.unbind(NSBindingName(rawValue: TSSTViewRotation))

        self.pageController.unbind(NSBindingName(rawValue: "currentValue"))

        self.session?.removeObserver(self, forKeyPath: TSSTPageOrder)
        self.session?.removeObserver(self, forKeyPath: TSSTPageScaleOptions)
        self.session?.removeObserver(self, forKeyPath: TSSTTwoPageSpread)
        self.session?.removeObserver(self, forKeyPath: "loupe")
        self.session?.unbind(NSBindingName(rawValue: TSSTViewRotation))
        self.session?.unbind(NSBindingName(rawValue: "selection"))
    }

    func windowShouldClose(_ sender: Any) -> Bool {
        self.prepareToEnd()
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: TSSTSessionEndNotification), object: self)
        return true
    }

    func windowDidBecomeKey(_ notification: Notification) {
        guard notification.object as? NSWindow == self.window else { return }

        NSApp.presentationOptions = NSApplication.PresentationOptions.init()

        if self.session?.loupe?.boolValue ?? false {
            NSCursor.hide()
        }

        self.refreshLoupePanel()
    }

    func windowDidResignKey(_ notification: Notification) {
        if notification.object as? NSPanel == self.exposeBezel {
            self.exposeBezel.orderOut(self)
        }

        if notification.object as? NSWindow == self.window {
            NSCursor.unhide()
            self.refreshLoupePanel()
            self.infoWindow.parent?.removeChildWindow(self.infoWindow)
            self.infoWindow.orderOut(self)
        }
    }

    func windowDidResize(_ notification: Notification) {
        guard notification.object as? NSWindow == self.window else { return }

        self.infoWindow.parent?.removeChildWindow(self.infoWindow)
        self.infoWindow.orderOut(self)

        let statusBar = UserDefaults.standard.bool(forKey: TSSTStatusbarVisible)

        guard statusBar else { return }

        let mouse = NSEvent.mouseLocation
        let point = CGRect.init(origin: mouse, size: CGSize.zero)
        let mouseLocation = self.window?.convertFromScreen(point).origin
        let progressRect = self.window?.contentView?.convert(self.progressBar.progressRect, from: self.progressBar)
        let cursorInside = NSMouseInRect(mouseLocation!, progressRect!, (self.window?.contentView!.isFlipped)!)

        if cursorInside && !self.pageView.inLiveResize {
            self.infoPanelSetupAtPoint(mouseLocation!)
            self.window?.addChildWindow(self.infoWindow, ordered: .above)
        }
    }

    /*    This method deals with window resizing.  It is called every time the user clicks
    the nice little plus button in the upper left of the window. */
    func windowWillUseStandardFrame(_ sender: NSWindow, defaultFrame: CGRect) -> CGRect {
        return (sender == self.window)
            ? self.optimalPageViewRectForRect(defaultFrame)
            : defaultFrame
    }

    func optimalPageViewRectForRect(_ boundingRect: CGRect) -> CGRect {
        let maxImageSize = self.pageView.combinedImageSize(forZoom: CGFloat(self.session!.zoomLevel!.floatValue))
        var vertOffset = self.window!.contentBorderThickness(for: .minY) + self.window!.toolbarHeight()

        if self.pageScrollView.hasHorizontalScroller {
            vertOffset += self.pageScrollView.horizontalScroller!.frame.height
        }
        let horOffset = self.pageScrollView.hasVerticalScroller
            ? self.pageScrollView.verticalScroller!.frame.width
            : 0
        let minSize = self.window!.minSize
        var correctedFrame = boundingRect
        correctedFrame.size.width = max(correctedFrame.width, minSize.width) - horOffset
        correctedFrame.size.height = max(correctedFrame.height, minSize.height) - vertOffset
        var newSize: CGSize = CGSize.zero

        if self.session!.scaleOptions!.intValue == 1 && !self.currentPageIsText() {
            var scale: CGFloat
            if maxImageSize.width < correctedFrame.width && maxImageSize.height < correctedFrame.height {
                scale = 1
            } else if correctedFrame.width / correctedFrame.height < maxImageSize.width / maxImageSize.height {
                scale = correctedFrame.width / maxImageSize.width
            } else {
                scale = correctedFrame.height / maxImageSize.height
            }

            newSize = maxImageSize.scaleBy(scale)
        } else {
            newSize.width = min(maxImageSize.width, correctedFrame.width)
            newSize.height = min(maxImageSize.height, correctedFrame.height)
        }

        newSize.width = max(minSize.width, newSize.width + horOffset)
        newSize.height = max(minSize.height, newSize.height + vertOffset)

        return CGRect.init(x: boundingRect.minX, y: boundingRect.maxY - newSize.height, width: newSize.width, height: newSize.height)
    }

    func resizeView() {
        self.pageView.resizeView()
    }

    func currentPageIsText() -> Bool {
        let set = self.pageController.selectionIndexes
        if set.count == 0 {
            return false
        }
        let page = self.pageController.selectedObjects[0] as! Image
        return page.text!.boolValue
    }

    func toolbarWillAddItem(_ notification: Notification) {
        let item = notification.userInfo!["item"] as! NSToolbarItem

        if item.label == "Page Scaling" {
            item.view?.bind(NSBindingName(rawValue: "selectedIndex"), to: self, withKeyPath: "session.scaleOptions", options: nil)
        } else if item.label == "Page Order" {
            item.view?.bind(NSBindingName(rawValue: "selectedIndex"), to: self, withKeyPath: "session.pageOrder", options: nil)
        } else if item.label == "Page Layout" {
            item.view?.bind(NSBindingName(rawValue: "selectedIndex"), to: self, withKeyPath: "session.twoPageSpread", options: nil)
        } else if item.label == "Loupe" {
            item.view?.bind(NSBindingName(rawValue: "value"), to: self, withKeyPath: "session.loupe", options: nil)
        }
    }

    // MARK: - Fullscreen Delegate Methods

    func window(_ window: NSWindow, willUseFullScreenPresentationOptions: NSApplication.PresentationOptions) -> NSApplication.PresentationOptions {
        if self.window == window {
            return [.hideDock, .autoHideToolbar, .autoHideMenuBar, .fullScreen]
        }

        return []
    }

    func windowWillEnterFullScreen(_ notification: NSNotification) {
    }

    func windowDidEnterFullScreen(_ notification: NSNotification) {
        self.refreshLoupePanel()
    }

    func windowDidExitFullScreen(_ notification: NSNotification) {
        self.resizeWindow()
    }

    func window(_ window: NSWindow, startCustomAnimationToEnterFullScreenWithDuration duration: TimeInterval) {
        self.invalidateRestorableState()

        let screenFrame = self.window!.screen!.visibleFrame
        let propsedFrame = screenFrame

        // The center frame for each window is used during the 1st half of the fullscreen animation and is
        // the window at its original size but moved to the center of its eventual full screen frame.
        //    NSRect centerWindowFrame = rectWithSizeCenteredInRect(startingFrame.size, screenFrame);

        // Our animation will be broken into two stages.
        // First, we'll move the window to the center of the primary screen and then we'll enlarge
        // it its full screen size.
        //
        NSAnimationContext.runAnimationGroup({ (context) in
            context.duration = duration / 4
            window.animator().setFrame(propsedFrame, display: true)
        }) {
            NSAnimationContext.runAnimationGroup { (context) in
                context.duration = duration / 4
                window.animator().setFrame(propsedFrame, display: true)
            }
        }
    }

    func customWindowsToEnterFullScreenForWindow(_ window: NSWindow) -> [NSWindow] {
        return [self.window!]
    }
}
