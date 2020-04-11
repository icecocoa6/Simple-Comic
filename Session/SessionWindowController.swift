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

let TSSTPageOrder = "pageOrder"
let TSSTPageZoomRate = "pageZoomRate"
let TSSTFullscreen = "fullscreen"
let TSSTSavedSelection = "savedSelection"
let TSSTThumbnailSize = "thumbnailSize"
let TSSTTwoPageSpread = "twoPageSpread"
let TSSTIgnoreDonation = "ignoreDonation"
let TSSTScrollPosition = "scrollPosition"
let TSSTConstrainScale = "constrainScale"
let TSSTZoomLevel = "zoomLevel"
let TSSTViewRotation = "rotation"
let TSSTBackgroundColor = "backgroundColor"
let TSSTSessionRestore = "sessionRestore"
let TSSTScrollersVisible = "scrollersVisible"
let TSSTAutoPageTurn = "autoPageTurn"
let TSSTWindowAutoResize = "windowAutoResize"
let TSSTLoupeDiameter = "loupeDiameter"
let TSSTLoupePower = "loupePower"
let TSSTStatusbarVisible = "statusBarVisisble"
let TSSTLonelyFirstPage = "lonelyFirstPage"

let TSSTSessionEndNotification = "sessionEnd"

class NotificationObservation: NSObject {
    let center: NotificationCenter
    let observer: NSObjectProtocol

    init(center: NotificationCenter, observer: NSObjectProtocol) {
        self.center = center
        self.observer = observer
    }

    func invalidate() {
        center.removeObserver(observer)
    }

    deinit {
        self.invalidate()
    }
}

extension NotificationCenter {
    func observe(forName name: NSNotification.Name?, object obj: Any?, queue: OperationQueue?, using block: @escaping (Notification) -> Void) -> NotificationObservation {
        return NotificationObservation(center: self,
                                       observer: self.addObserver(forName: name, object: obj, queue: queue, using: block))
    }
}

extension Notification.Name {
    struct SimpleComic {
        static let sessionWillLoad = Notification.Name("SimpleComic.SessionWillLoad")
        static let sessionDidLoad = Notification.Name("SimpleComic.SessionDidLoad")
    }
}

class SessionWindowController: NSWindowController, NSTextFieldDelegate, NSMenuItemValidation, PageViewDelegate {
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

    @IBOutlet var titlebarAccessory: NSView!
    @IBOutlet var progressInditator: NSProgressIndicator!

    /* The session object used to maintain settings */
    @objc dynamic var session: Session?

    /* This var is bound to the session window name */
    @objc dynamic var pageNames: String?
    var pageTurn: Orientation.Horizontal = .left

    /* Exactly what it sounds like */
    @objc dynamic var pageSortDescriptor: NSArray?

    /* Manages the cursor hiding while in fullscreen */
    var mouseMovedTimer: Timer?

    var newSession: Bool = false

    var savedZoom: Float = 0.0

    var observers: [Any] = []

    enum PageSelectionMode: Int {
        case None = 0
        case Icon = 1
        case Delete = 2
        case Extract = 3
    };

    var pageSelectionMode: PageSelectionMode = .None
    var _pageSelectionInProgress: PageSelectionMode {
        get { self.pageSelectionMode }
        set(value) { self.pageSelectionMode = value }
    }

    init(window: NSWindow?, session: Session) {
        super.init(window: window)

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

        let vc = NSTitlebarAccessoryViewController()
        vc.view = self.titlebarAccessory
        vc.layoutAttribute = .right
        self.window?.addTitlebarAccessoryViewController(vc)

        self.observers.removeAll()
        let defaults = UserDefaults.standard
        self.observers += [
            defaults.observe(\.constrainScale) { (_, _) in
                self.changeViewImages()
            },
            defaults.observe(\.statusBarVisible) { (_, _) in
                self.adjustStatusBar()
            },
            defaults.observe(\.scrollersVisible) { (_, _) in
                self.scaleToWindow()
            },
            defaults.observe(\.backgroundColor, options: .new) { (_, change) in
                let color = try! NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: change.newValue!)
                self.pageScrollView.backgroundColor = color!
            },
            defaults.observe(\.loupeDiameter, options: .new) { (_, change) in
                self.loupeWindow!.resize(toDiameter: CGFloat(change.newValue!))
            },
            defaults.observe(\.loupePower) { (_, _) in
                self.refreshLoupePanel()
            },
            defaults.observe(\.pageOrder) { (_, _) in
                self.exposeView.needsDisplay = true
                self.exposeView.buildTrackingRects()
                self.changeViewImages()
            },
            defaults.observe(\.rawAdjustmentMode) { (_, _) in
                self.scaleToWindow()
            },
            defaults.observe(\.twoPageSpread) { (_, _) in
                self.changeViewImages()
            }
        ]

        if let session = self.session {
            self.observers += [
                session.observe(\.pageOrder, options: .new) { _, change in
                    UserDefaults.standard[keyPath: \.pageOrder] = change.newValue!!.boolValue
                },
                session.observe(\.rawAdjustmentMode, options: .new) { _, change in
                    UserDefaults.standard[keyPath: \.rawAdjustmentMode] = change.newValue!!.intValue
                },
                session.observe(\.twoPageSpread, options: .new) { _, change in
                    UserDefaults.standard[keyPath: \.twoPageSpread] = change.newValue!!.boolValue
                },
                session.observe(\Session.loupe) { _, _ in self.refreshLoupePanel() }
            ]

            session.bind(NSBindingName(rawValue: "selection"), to: pageController!, withKeyPath: "selectionIndex", options: nil)
        }
        self.pageScrollView.postsFrameChangedNotifications = true
        self.observers += [
            NotificationCenter.default.observe(forName: NSView.frameDidChangeNotification, object: self.pageScrollView, queue: nil) { (_) in
                self.resizeView()
            }
        ]

        self.observers += [
            self.pageController.observe(\.selectionIndex) { _, _ in
                self.changeViewImages()
            },
            self.pageController.observe(\.arrangedObjects, options: .new) { (_, change) in
                let objs = change.newValue as? [Image]
                if objs != nil && objs!.count <= 0 {
                    self.close()
                } else {
                    DispatchQueue.global().async {
                        self.exposeView.processThumbs()
                    }
                    self.changeViewImages()
                }
            }
        ]

        self.observers += [
            self.progressBar.observe(\.currentValue, options: .new) { (_, change) in
                self.pageController.setSelectionIndex(change.newValue!)
            }
        ]
        self.progressBar.bind(NSBindingName(rawValue: "currentValue"), to: self.pageController!, withKeyPath: "selectionIndex", options: nil)
        self.progressBar.bind(NSBindingName.maxValue, to: self.pageController!, withKeyPath: "arrangedObjects.@count", options: nil)
        self.progressBar.bind(NSBindingName(rawValue: "leftToRight"), to: session!, withKeyPath: TSSTPageOrder, options: nil)

        self.pageView.bind(NSBindingName(rawValue: "rotationValue"), to: self.session!, withKeyPath: TSSTViewRotation, options: nil)
        let newArea = NSTrackingArea.init(rect: self.progressBar.progressRect,
                                          options: [.mouseEnteredAndExited, .activeInKeyWindow, .activeInActiveApp],
                                          owner: self,
                                          userInfo: ["purpose": "normalProgress"])
        self.progressBar.addTrackingArea(newArea)
        self.jumpField.delegate = self
        self.observers += [
            NotificationCenter.default.observe(forName: NSNotification.Name(rawValue: "SCMouseDragNotification"), object: self, queue: nil) {
                self.handleMouseDragged($0)
            },
            NotificationCenter.default.observe(forName: NSNotification.Name.SimpleComic.sessionWillLoad,
                                               object: self,
                                               queue: OperationQueue.main) { notification in
                self.progressInditator.startAnimation(self)
                self.processingWorkers += 1
            },
            NotificationCenter.default.observe(forName: NSNotification.Name.SimpleComic.sessionDidLoad,
                                               object: self,
                                               queue: OperationQueue.main) { notification in
                self.processingWorkers -= 1
                if self.processingWorkers == 0 {
                    self.progressInditator.stopAnimation(self)
                }
            }
        ]

        self.restoreSession()
    }
    
    var processingWorkers: Int = 0

    override var windowNibName: NSNib.Name? { "TSSTSessionWindow" }

    deinit {
        self.exposeView.dataSource = nil
        NotificationCenter.default.removeObserver(self)

        self.progressBar.unbind(NSBindingName(rawValue: "currentvalue"))
        self.progressBar.unbind(NSBindingName(rawValue: "maxValue"))
        self.progressBar.unbind(NSBindingName(rawValue: "leftToRight"))

        self.pageView.delegate = nil
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
        let dict = event.trackingArea?.userInfo as? [String: String]
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
            && self._pageSelectionInProgress == .None {
            if !self.loupeWindow.isVisible {
                self.window?.addChildWindow(loupeWindow, ordered: .above)
                NSCursor.hide()
            }

            let localPoint = self.pageView.convert(self.window!.convertFromScreen(point).origin, from: nil)
            let zoomRect = CGRect(origin: localPoint, size: self.zoomView.frame.size)
            self.loupeWindow.center(atPoint: mouse)
            self.zoomView.image = self.pageView.image(inRect: zoomRect)
        } else {
            if self.loupeWindow.isVisible {
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
        let thumbSize = thumb!.size.adjust(to: CGSize(width: 128, height: 128))

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
        session?.adjustmentMode = PageAdjustmentMode(rawValue: scaleType)!
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

    func zoom(by scale: CGFloat) {
        var previousZoom = CGFloat(self.session!.zoomLevel!.floatValue)

        if self.session!.adjustmentMode != .none {
            previousZoom = self.pageView.imageBounds.width / self.pageView.combinedImageSize().width
        }

        self.session?.zoomLevel = previousZoom + scale as NSNumber
        self.session?.adjustmentMode = .none

        self.pageView.resizeView()
        self.refreshLoupePanel()
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
        self.session?.adjustmentMode = .none
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
    func rotateRight(_ sender: Any?) {
        var current: Int = (self.session?.rotation!.intValue)!
        current = (current + 1) % 4
        self.session?.rotation = current as NSNumber
        self.resizeWindow()
        self.refreshLoupePanel()
    }

    @IBAction
    func rotateLeft(_ sender: Any?) {
        var current: Int = (self.session?.rotation!.intValue)!
        current = (current + 3) % 4
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

    func changeViewForSelection() {
        self.savedZoom = (self.session?.zoomLevel!.floatValue)!
        self.pageScrollView.hasVerticalScroller = false
        self.pageScrollView.hasHorizontalScroller = false
        self.refreshLoupePanel()

        let imageSize = self.pageView.combinedImageSize()
        var scrollerBounds = (self.pageView.enclosingScrollView?.bounds.size)!
        scrollerBounds.width -= 20
        scrollerBounds.height -= 20

        let factor = max(scrollerBounds.width / imageSize.width, scrollerBounds.height / imageSize.height)
        self.session?.zoomLevel = factor as NSNumber

        self.pageView.resizeView()
    }

    func canSelectPage(_ selection: Order) -> Bool {
        let index = (selection == .prev) ? self.pageController.selectionIndex : (self.pageController.selectionIndex + 1)
        let contents = self.pageController.arrangedObjects as! [Image]
        let selectedPage = contents[index]
        let selectedGroup = selectedPage.group

        /* Makes sure that the group is both an archive and not nested */
        return (selectedGroup?.isKind(of: Archive.self))! &&
            selectedGroup == selectedGroup?.topLevelGroup &&
            !selectedPage.text!.boolValue
    }

    var pageSelectionInProgress: Bool {
        self._pageSelectionInProgress != .None
    }

    func cancelPageSelection() {
        self.session?.zoomLevel = self.savedZoom as NSNumber
        self._pageSelectionInProgress = .None
        self.scaleToWindow()
    }

    func selectedPage(_ selection: Int, withCropRect crop: NSRect) {
        switch _pageSelectionInProgress {
        case .None:
            break
        case .Icon:
            self.setIconWithSelection(selection, andCropRect: crop)
        case .Delete:
            self.deletePageWithSelection(selection)
        case .Extract:
            self.extractPageWithSelection(selection)
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

    fileprivate func saveQuickLookMetadataOfFile(atPath archivePath: String, name coverString: String, rect cropRect: CGRect) {
        UKXattrMetadataStore.setString(coverString,
                                       forKey: "QCCoverName",
                                       atPath: archivePath,
                                       traverseLink: false)
        UKXattrMetadataStore.setString(NSStringFromRect(cropRect),
                                       forKey: "QCCoverRect",
                                       atPath: archivePath,
                                       traverseLink: false)

        Process.launchedProcess(launchPath: "/usr/bin/touch", arguments: [archivePath])
    }

    fileprivate func createIcon(from source: NSImage, in cropRect: CGRect) -> NSImage {
        let size = cropRect.size == CGSize.zero ? source.size : cropRect.size
        let shadowImage = NSImage.init(size: CGSize.init(width: 512, height: 512))
        var drawRect = CGRect.init(x: 0, y: 0, width: 496, height: 496)
        let iconImage = NSImage.init(size: drawRect.size)
        drawRect = size.fit(into: drawRect)

        iconImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        source.draw(in: drawRect, from: CGRect.init(origin: cropRect.origin, size: size), operation: .sourceOver, fraction: 1)
        iconImage.unlockFocus()


        let thumbShadow = NSShadow.init()
        thumbShadow.shadowOffset = CGSize.init(width: 0.0, height: -8.0)
        thumbShadow.shadowBlurRadius = 25.0
        thumbShadow.shadowColor = NSColor.init(calibratedWhite: 0.2, alpha: 1.0)

        shadowImage.lockFocus()
        thumbShadow.set()
        iconImage.draw(in: CGRect.init(x: 16, y: 16, width: 496, height: 496), from: CGRect.zero, operation: .sourceOver, fraction: 1)
        shadowImage.unlockFocus()

        return shadowImage
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
                let xad = archive.instance!
                let coverIndex = selectedPage.index!.intValue
                let coverName = xad.rawName(ofEntry: Int32(coverIndex))
                let coverString = coverName!.string(withEncoding: String.Encoding.nonLossyASCII.rawValue)!
                self.saveQuickLookMetadataOfFile(atPath: archivePath, name: coverString, rect: cropRect)
            } else if let source = selectedPage.pageImage {
                let shadowImage = self.createIcon(from: source, in: cropRect)
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

        NotificationCenter.default.post(name: NSNotification.Name.SimpleComic.sessionWillLoad, object: self)
        DispatchQueue.global().async {
            if pageOne.imageSource != nil {
                self.pageView.setSource(first: ImagePack(image: pageOne),
                                        CGSize.init(width: CGFloat(pageOne.width!.floatValue),
                                                    height: CGFloat(pageOne.height!.floatValue)),
                                        second: (pageTwo != nil) ? ImagePack(image: pageTwo!) : nil,
                                        CGSize.init(width: CGFloat(pageTwo?.width?.floatValue ?? 0),
                                                    height: CGFloat(pageTwo?.height?.floatValue ?? 0)))
            }
            
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name.SimpleComic.sessionDidLoad, object: self)
                self.pageView.resizeView()
                self.scaleToWindow()
                self.pageView.correctViewPoint()
                self.refreshLoupePanel()
            }
        }
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

    fileprivate var pageScaleMode: PageAdjustmentMode {
        if _pageSelectionInProgress != .None || !UserDefaults.standard.bool(forKey: TSSTScrollersVisible) {
            return .fitToWindow
        } else if self.currentPageIsText {
            return .fitToWidth
        }

        return self.session?.adjustmentMode ?? .none
    }

    func scaleToWindow() {
        var hasVert = false
        var hasHor = false

        switch self.pageScaleMode {
        case .none:
            hasVert = true
            hasHor = true
        case .fitToWindow:
            self.session?.zoomLevel = 1.0
        case .fitToWidth:
            self.session?.zoomLevel = 1.0
            if case .horizontal = self.pageView.pageOrientation {
                hasHor = true
            } else {
                hasVert = true
            }
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
            self.pageScrollView.frame = scrollViewRect
            self.window?.setContentBorderThickness(23, for: .minY)
            self.progressBar.isHidden = false
        } else {
            let scrollViewRect = self.window!.contentView!.frame
            self.pageScrollView.frame = scrollViewRect
            self.window?.setContentBorderThickness(0, for: .minY)
            self.progressBar.isHidden = true
        }

        self.resizeWindow()
    }

    func hasTwoPagesSpreadableFrom(index: Int) -> Bool {
        guard self.session?.twoPageSpread?.boolValue ?? false else { return false }

        let contents = self.pageController.arrangedObjects as! [Image]
        guard (0 ..< contents.count - 1).contains(index) else { return false }

        if index == 0 && UserDefaults.standard.bool(forKey: TSSTLonelyFirstPage) {
            return false
        } else {
            let fst = contents[index]
            let snd = contents[index + 1]
            return !fst.shouldDisplayAlone() && !snd.shouldDisplayAlone()
        }
    }

    func turnPage(to order: Order) {
        let selectionIndex = self.pageController.selectionIndex
        let base = order == .prev ? selectionIndex - 2: selectionIndex

        if hasTwoPagesSpreadableFrom(index: base) {
            self.pageController.select(order, by: 2, sender: self)
        } else {
            self.pageController.select(order, sender: self)
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

    @objc enum Order: Int {
        case prev
        case next
    }

    func orderTo(side: Orientation.Horizontal) -> Order {
        switch side {
        case .left:
            return self.session!.pageOrder!.boolValue ? .prev : .next
        case .right:
            return self.session!.pageOrder!.boolValue ? .next : .prev
        }
    }

    func canTurnTo(_ side: Orientation.Horizontal) -> Bool {
        return canTurnTo(orderTo(side: side))
    }

    func canTurnTo(_ side: Order) -> Bool {
        switch side {
        case .prev:
            return pageController.selectionIndex > 0
        case .next:
            let selectionIndex = self.pageController.selectionIndex
            let contents = self.pageController.content as! [Any]
            if selectionIndex + 1 >= contents.count {
                return false
            }

            let lastTwoPages =
                selectionIndex == contents.count - 2 &&
                self.hasTwoPagesSpreadableFrom(index: selectionIndex)
            if lastTwoPages {
                return false
            }

            return true
        }
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
            menuItem.state = self.session!.pageOrder!.boolValue ? .on : .off
            return true
        } else if menuItem.action == #selector(changePageOrder(_:)) {
            if self.session!.pageOrder!.boolValue {
                menuItem.title = NSLocalizedString("Right To Left", tableName: "Right to left page order menu item text", comment: "")
            } else {
                menuItem.title = NSLocalizedString("Left To Right", tableName: "Left to right page order menu item text", comment: "")
            }
            return true
        } else if menuItem.action == #selector(pageRight(_:)) {
            return self.canTurnTo(.right)
        }
        else if menuItem.action == #selector(pageLeft(_:)) {
            return self.canTurnTo(.left)
        } else if menuItem.action == #selector(firstPage(_:)) {
            return self.pageController.selectionIndex > 0
        } else if menuItem.action == #selector(lastPage(_:)) {
            let contents = self.pageController.content as! [Any]
            return self.pageController.selectionIndex < (contents.count - 1)
        } else if menuItem.action == #selector(shiftPageRight(_:)) {
            return self.canTurnTo(.right)
        } else if menuItem.action == #selector(shiftPageLeft(_:)) {
            return self.canTurnTo(.left)
        } else if menuItem.action == #selector(skipRight(_:)) {
            return self.canTurnTo(.right)
        } else if menuItem.action == #selector(skipLeft(_:)) {
            return self.canTurnTo(.left)
        } else if menuItem.action == #selector(setArchiveIcon(_:)) {
            return self.session!.rotation!.intValue == 0
        } else if menuItem.action == #selector(extractPage(_:)) {
            return self.session!.rotation!.intValue == 0
        } else if menuItem.action == #selector(removePages(_:)) {
            return self.session!.rotation!.intValue == 0
        } else if menuItem.tag == 400 {
            menuItem.state = self.pageScaleMode == .none ? .on : .off
            return true
        } else if menuItem.tag == 401 {
            menuItem.state = self.pageScaleMode == .fitToWindow ? .on : .off
            return true
        } else if menuItem.tag == 402 {
            menuItem.state = self.pageScaleMode == .fitToWidth ? .on : .off
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

        self.observers.removeAll()

        NSCursor.unhide()
        NSApp.presentationOptions = NSApplication.PresentationOptions.init()

        self.progressBar.unbind(NSBindingName(rawValue: "currentValue"))
        self.progressBar.unbind(NSBindingName(rawValue: "maxValue"))
        self.progressBar.unbind(NSBindingName(rawValue: "leftToRight"))

        self.pageView.unbind(NSBindingName(rawValue: TSSTViewRotation))

        self.pageController.unbind(NSBindingName(rawValue: "currentValue"))

        self.session?.unbind(NSBindingName(rawValue: TSSTViewRotation))
        self.session?.unbind(NSBindingName(rawValue: "selection"))
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
        var correctedFrame = boundingRect.size
        correctedFrame.width = max(boundingRect.width, minSize.width) - horOffset
        correctedFrame.height = max(boundingRect.height, minSize.height) - vertOffset

        let newSize: CGSize
        if self.pageScaleMode == .fitToWindow {
            let wratio = correctedFrame.width / maxImageSize.width
            let hratio = correctedFrame.height / maxImageSize.height
            newSize = maxImageSize.scaleBy(min(wratio, hratio, 1.0))
        } else {
            newSize = CGSize(width: min(maxImageSize.width, correctedFrame.width),
                             height: min(maxImageSize.height, correctedFrame.height))
        }

        let size = CGSize(width: max(minSize.width, newSize.width + horOffset),
                          height: max(minSize.height, newSize.height + vertOffset))
        return CGRect.init(x: boundingRect.minX, y: boundingRect.maxY - size.height, width: size.width, height: size.height)
    }

    func resizeView() {
        self.pageView.resizeView()
    }

    var currentPageIsText: Bool {
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
            item.view?.bind(NSBindingName(rawValue: "selectedIndex"), to: self, withKeyPath: "session.rawAdjustmentMode", options: nil)
        } else if item.label == "Page Order" {
            item.view?.bind(NSBindingName(rawValue: "selectedIndex"), to: self, withKeyPath: "session.pageOrder", options: nil)
        } else if item.label == "Page Layout" {
            item.view?.bind(NSBindingName(rawValue: "selectedIndex"), to: self, withKeyPath: "session.twoPageSpread", options: nil)
        } else if item.label == "Loupe" {
            item.view?.bind(NSBindingName(rawValue: "value"), to: self, withKeyPath: "session.loupe", options: nil)
        }
    }
}

extension SessionWindowController: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
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

    // MARK: - Fullscreen Delegate Methods

    func window(_ window: NSWindow, willUseFullScreenPresentationOptions: NSApplication.PresentationOptions) -> NSApplication.PresentationOptions {
        if self.window == window {
            return [.hideDock, .autoHideToolbar, .autoHideMenuBar, .fullScreen]
        }

        return []
    }

    func windowWillEnterFullScreen(_ notification: Notification) {
    }

    func windowDidEnterFullScreen(_ notification: Notification) {
        self.refreshLoupePanel()
    }

    func windowDidExitFullScreen(_ notification: Notification) {
        self.resizeWindow()
    }
}

extension NSArrayController {
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
}
