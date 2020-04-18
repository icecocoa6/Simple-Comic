//
//  SimpleComicAppDelegate.swift
//  Simple Comic
//
//    Copyright (c) 2006-2009 Dancing Tortoise Software
//
//    Permission is hereby granted, free of charge, to any person
//    obtaining a copy of this software and associated documentation
//    files (the "Software"), to deal in the Software without
//    restriction, including without limitation the rights to use,
//    copy, modify, merge, publish, distribute, sublicense, and/or
//    sell copies of the Software, and to permit persons to whom the
//    Software is furnished to do so, subject to the following
//    conditions:
//
//    The above copyright notice and this permission notice shall be
//    included in all copies or substantial portions of the Software.
//
//    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//    EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//    OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//    NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//    HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//    WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//    FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//    OTHER DEALINGS IN THE SOFTWARE.
//
//  Ported by Tomioka Taichi on 2020/03/28.
//

import Cocoa


class SimpleComicAppDelegate: NSObject, NSApplicationDelegate {
    /*  When opening encrypted zip or rar archives this panel is
     made visible as a modal so the user can enter a password. */
    @IBOutlet var passwordPanel: NSPanel!
    @IBOutlet var passwordField: NSSecureTextField!

    /*  This panel appears when the text encoding auto-detection fails */
    @IBOutlet var encodingPanel: NSPanel!
    @IBOutlet var encodingTestField: NSTextField!
    var encodingTestData: Data?
    @objc var encodingSelection: NSInteger = 0
    @IBOutlet var encodingPopup: NSPopUpButton!

    @IBOutlet var launchPanel: NSPanel!

    /*  Core Data stuff. */
    var managedObjectModel: NSManagedObjectModel? = NSManagedObjectModel.mergedModel(from: nil)
    var _managedObjectContext: NSManagedObjectContext?
    var _persistentStoreCoordinator: NSPersistentStoreCoordinator?

    /*  Window controller for preferences. */
    var preferences: NSWindowController?

    /*  This is the array that maintains all of the session window managers. */
    var sessions: [SessionWindowController] = []

    /*    Vars to delay the loading of files from an app launch until the core data store
     has finished initializing */
    var launchInProgress: Bool = false
    var optionHeldAtlaunch: Bool = false
    var launchFiles: [String]? = nil

    class func setupTemplateImages() {
        NSImage.init(named: "org_size")?.isTemplate = true
        NSImage.init(named: "Loupe")?.isTemplate = true
        NSImage.init(named: "rotate_l")?.isTemplate = true
        NSImage.init(named: "rotate_r")?.isTemplate = true
        NSImage.init(named: "win_scale")?.isTemplate = true
        NSImage.init(named: "hor_scale")?.isTemplate = true
        NSImage.init(named: "one_page")?.isTemplate = true
        NSImage.init(named: "two_page")?.isTemplate = true
        NSImage.init(named: "rl_order")?.isTemplate = true
        NSImage.init(named: "lr_order")?.isTemplate = true
        NSImage.init(named: "equal")?.isTemplate = true
        NSImage.init(named: "thumbnails")?.isTemplate = true
        NSImage.init(named: "extract")?.isTemplate = true
    }
    
    override init() {
        super.init()
        ValueTransformer.setValueTransformer(ColorTransformer(), forName: NSValueTransformerName.ColorTransformer)
    }

    // MARK: - Application Delegate

    /*    Stores any files that were opened on launch till applicationDidFinishLaunching:
        is called. */
    func applicationWillFinishLaunching(_ notification: Notification) {
        launchFiles = []
        launchInProgress = true
        preferences = nil;
        optionHeldAtlaunch = false

        UserDefaults.standard.setupDefaults()

        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: TSSTSessionEndNotification),
                                               object: nil,
                                               queue: nil) {
            self.endSession($0)
        }

        Self.setupTemplateImages()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        self.generateEncodingMenu()

        sessions = [];
        self.sessionRelaunch()
        launchInProgress = false;

        if launchFiles != nil {
            let session = self.newSessionWithFiles(launchFiles!)
            self.windowForSession(session)

            launchFiles = nil;
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {

        /* Goes through if the user has auto save turned off */
        if !UserDefaults.standard.bool(forKey: TSSTSessionRestore) {
            return .terminateNow
        }

        /* TODO: some day I really need to add the fallback error handling */
        if !self.saveContext() {
            // Error handling wasn't implemented. Fall back to displaying a "quit anyway" panel.
            let alertPanel = NSAlert.init()
            alertPanel.messageText = "Quit without saving session?";
            alertPanel.informativeText = "Could not save session while quitting.";
            alertPanel.addButton(withTitle: "Quit")
            alertPanel.addButton(withTitle: "Cancel")
            if (alertPanel.runModal() == .alertSecondButtonReturn) {
                return .terminateCancel
            }
        }

        return .terminateNow
    }

    func windowWillReturnUndoManager(window: NSWindow?) -> UndoManager? {
        return self.managedObjectContext.undoManager
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        if launchInProgress {
            launchFiles = filenames
        } else {
            let session = self.newSessionWithFiles(filenames)
            self.windowForSession(session)
        }
    }

    // MARK: - CoreData

    @objc var managedObjectContext: NSManagedObjectContext {
        guard self._managedObjectContext == nil else { return self._managedObjectContext! }

        _managedObjectContext = NSManagedObjectContext.init(concurrencyType: .privateQueueConcurrencyType)
        _managedObjectContext!.persistentStoreCoordinator = self.persistentStoreCoordinator

        return self._managedObjectContext!
    }

    var persistentStoreCoordinator: NSPersistentStoreCoordinator {
        guard self._persistentStoreCoordinator == nil else { return _persistentStoreCoordinator! }

        if !FileManager.default.fileExists(atPath: self.applicationSupportFolder.path) {
            try! FileManager.default.createDirectory(at: applicationSupportFolder, withIntermediateDirectories: true, attributes: nil)
        }

        let url = self.applicationSupportFolder.appendingPathComponent("SimpleComic.sql")
        let storeInfo = try? NSPersistentStoreCoordinator.metadataForPersistentStore(ofType: NSSQLiteStoreType, at: url, options: nil)

        if storeInfo != nil && storeInfo!["viewVersion"] as? String != "Version 1708" {
            try! FileManager.default.removeItem(at: url)
        }
        self._persistentStoreCoordinator = NSPersistentStoreCoordinator.init(managedObjectModel: self.managedObjectModel!)

        do {
            try self._persistentStoreCoordinator?.addPersistentStore(ofType: NSSQLiteStoreType,
                                                                     configurationName: nil,
                                                                     at: url,
                                                                     options: [NSMigratePersistentStoresAutomaticallyOption: true])
        }
        catch {
            NSApp.presentError(error)
        }

        let store = self._persistentStoreCoordinator?.persistentStore(for: url)
        var metadata = self._persistentStoreCoordinator?.metadata(for: store!)
        metadata!["viewVersion"] = "Version 1708"
        self._persistentStoreCoordinator?.setMetadata(metadata, for: store!)

        return _persistentStoreCoordinator!
    }

    /*  Method creates an application support directory for Simpl Comic if one
    is does not already exist.
    @return The absolute path to Simple Comic's application support directory
    as a string.  */
    var applicationSupportFolder: URL {
        let paths = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)
        let basePath = (paths.count > 0) ? paths[0] : NSTemporaryDirectory()
        return URL.init(fileURLWithPath: basePath).appendingPathComponent("Simple Comic")
    }

    func saveContext() -> Bool {
        for controller in sessions {
            controller.updateSessionObject()
        }

        let context = self.managedObjectContext;

        if (!context.commitEditing()) {
            print("%@: unable to commit editing before saving", Self.self);
        }

        if (context.hasChanges) {
            do {
                try context.save()
            }
            catch {
                NSApp.presentError(error)
                return false
            }
        }

        return true
    }

    // MARK: - Session Management

    func windowForSession(_ session: Session) {
        guard session.images!.count > 0 else { return }
        guard (sessions.allSatisfy { $0.session != session }) else { return }

        let comicWindow = SessionWindowController.init(window: nil, session: session)
        sessions.append(comicWindow)
        comicWindow.showWindow(self)
    }

    func endSession(_ notification: Notification) {
        let controller = notification.object as! SessionWindowController
        if let index = sessions.firstIndex(of: controller) {
            sessions.remove(at: index)
        }
        self.managedObjectContext.delete(controller.session!)
    }

    func sessionRelaunch() {
        let sessionRequest = NSFetchRequest<NSFetchRequestResult>.init(entityName: "Session")
        let sessions = try! self.managedObjectContext.fetch(sessionRequest) as! [Session]

        for session in sessions {
            if (session.groups?.count ?? 0) > 0 {
                self.windowForSession(session)
            } else {
                self.managedObjectContext.delete(session)
            }
        }
    }

    func newSessionWithFiles(_ files: [String]) -> Session {
        let session = Session.init(context: self.managedObjectContext)
        session.rawAdjustmentMode = Int16(UserDefaults.standard.rawAdjustmentMode)
        session.pageOrder = UserDefaults.standard.pageOrder
        session.twoPageSpread = UserDefaults.standard.twoPageSpread

        self.addFiles(urls: files.map { URL(fileURLWithPath: $0) }, toSession: session)
        return session
    }

    func addFiles(urls: [URL], toSession session: Session) {
        for url in urls {
            session.addFile(atURL: url)
        }
    }

    // MARK: - Actions

    @IBAction
    func addPages(_ sender: Any) {
        // Creates a new modal.
        let modal = NSOpenPanel.init()
        modal.allowsMultipleSelection = true
        modal.canChooseDirectories = true
        modal.allowedFileTypes = Archive.archiveExtensions + Image.imageExtensions + [(kUTTypeFolder as String)]

        if modal.runModal() != .cancel {
            let paths = modal.urls.map { $0.path }
            let session = self.newSessionWithFiles(paths)
            self.windowForSession(session)
        }
    }

    @IBAction
    func modalOK(_ sender: Any) {
        NSApp.stopModal(withCode: .OK)
    }

    @IBAction
    func modalCancel(_ sender: Any) {
        NSApp.stopModal(withCode: .cancel)
    }

    @IBAction
    func openPreferences(_ sender: Any) {
        if preferences == nil {
            preferences = NSWindowController(windowNibName: "Preferences")
        }
        preferences?.showWindow(self)
    }

    // MARK: - Archive Encoding Handling

    @IBAction
    func testEncodingMenu(_ sender: Any) {
        NSApp.runModal(for: encodingPanel!)
    }

    func generateEncodingMenu() {
        let encodingMenu = encodingPopup.menu
        self.encodingSelection = 0
        encodingMenu?.autoenablesItems = false
        for item in encodingMenu!.items {
            encodingMenu?.removeItem(item)
        }

        for encoding in String.availableStringEncodings {
            let encodingName = String.localizedName(of: encoding)
            let item = NSMenuItem.init(title: encodingName, action: nil, keyEquivalent: "")
            item.representedObject = encoding
            encodingMenu?.addItem(item)
        }

        encodingPopup.bind(NSBindingName(rawValue: "selectedIndex"), to: self, withKeyPath: "encodingSelection", options: nil)
    }

    func updateEncodingMenuTestedAgainst(data: Data) {
        for item in encodingPopup.menu!.items {
            let encoding = item.representedObject! as! String.Encoding
            item.isEnabled = false
            guard !item.isSeparatorItem else { continue }

            let text = String.init(data: data, encoding: encoding)
            item.isEnabled = (text != nil) ? true : false
        }
    }

    func passwordForArchive(withPath path: String) -> String? {
        var password: String? = nil
        passwordField?.stringValue = ""

        if NSApp.runModal(for: passwordPanel!) != NSApplication.ModalResponse.cancel {
            password = passwordField?.stringValue
        }

        passwordPanel?.close()
        return password
    }

    override func archive(_ archive: XADArchive!, encodingFor data: Data!, guess: UInt, confidence: Float) -> UInt {
        return guess
//            if(confidence < 0.8 || !testText)
//            {
//                NSMenu * encodingMenu = [encodingPopup menu];
//                [self updateEncodingMenuTestedAgainst: data];
//                NSArray * encodingIdentifiers = [[encodingMenu itemArray] valueForKey: @"representedObject"];
//
//                NSUInteger index = [encodingIdentifiers indexOfObject: @(guess)];
//                NSUInteger counter = 0;
//        //        NSStringEncoding encoding;
//                NSNumber * encoding;
//                while(!testText)
//                {
//                    [testText release];
//                    encoding = encodingIdentifiers[counter];
//                    if ([encoding class] != [NSNull class]) {
//                        testText = [[NSString alloc] initWithData: data encoding: [encoding unsignedIntegerValue]];
//                    }
//                    index = counter++;
//                }
//
//                if(index != NSNotFound)
//                {
//                    self.encodingSelection = index;
//                }
//
//                encodingTestData = data;
//
//                [self testEncoding: self];
//                guess = NSNotFound;
//                if([NSApp runModalForWindow: encodingPanel] != NSModalResponseCancel)
//                {
//                    guess = [[[encodingMenu itemAtIndex: encodingSelection] representedObject] unsignedIntegerValue];
//                }
//                [encodingPanel close];
//                [archive setNameEncoding: guess];
//            }
//            return guess;
    }

    @IBAction
    func testEncoding(_ sender: Any) {
        let item = encodingPopup.menu?.items[encodingSelection]
        let testText = String.init(data: encodingTestData!, encoding: item?.representedObject as! String.Encoding)

        encodingTestField.stringValue = testText ?? "invalid Selection"
    }

    @IBAction
    func actionStub(_ sender: Any) {
        // do nothing
    }

    @IBAction
    func endLaunchPanel(_ sender: Any) {
        launchPanel?.close()
    }
}
