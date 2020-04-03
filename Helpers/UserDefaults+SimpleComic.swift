//
//  UserDefaults+SimpleComic.swift
//  Simple Comic
//
//  Created by Tomioka Taichi on 2020/04/01.
//

import Foundation

extension UserDefaults {
    fileprivate static let TSSTPageScaleOptions = "scaleOptions"
    
    @objc dynamic var constrainScale: Bool {
        get { self.bool(forKey: TSSTConstrainScale) }
        set(value) { self.set(value, forKey: TSSTConstrainScale) }
    }
    @objc dynamic var statusBarVisible: Bool {
        get { self.bool(forKey: TSSTStatusbarVisible) }
        set(value) { self.set(value, forKey: TSSTStatusbarVisible) }
    }
    @objc dynamic var scrollersVisible: Bool {
        get { self.bool(forKey: TSSTScrollersVisible) }
        set(value) { self.set(value, forKey: TSSTScrollersVisible) }
    }
    @objc dynamic var backgroundColor: Data {
        get { self.data(forKey: TSSTBackgroundColor)! }
        set(value) { self.set(value, forKey: TSSTBackgroundColor) }
    }
    @objc dynamic var loupeDiameter: Float {
        get { self.float(forKey: TSSTLoupeDiameter) }
        set(value) { self.set(value, forKey: TSSTLoupeDiameter) }
    }
    @objc dynamic var loupePower: Float {
        get { self.float(forKey: TSSTLoupePower) }
        set(value) { self.set(value, forKey: TSSTLoupePower) }
    }
    @objc dynamic var pageOrder: Bool {
        get { self.bool(forKey: TSSTPageOrder) }
        set(value) { self.set(value, forKey: TSSTPageOrder) }
    }
    @objc dynamic var rawAdjustmentMode: Int {
        get { self.integer(forKey: UserDefaults.TSSTPageScaleOptions) }
        set(value) { self.set(value, forKey: UserDefaults.TSSTPageScaleOptions) }
    }
    @objc dynamic var twoPageSpread: Bool {
        get { self.bool(forKey: TSSTTwoPageSpread) }
        set(value) { self.set(value, forKey: TSSTTwoPageSpread) }
    }
    
    func setupDefaults() {
        let inits = [
            TSSTPageOrder: false,
            TSSTPageZoomRate: 0.1,
            UserDefaults.TSSTPageScaleOptions: 1,
            TSSTThumbnailSize: 100,
            TSSTTwoPageSpread: true,
            TSSTIgnoreDonation: false,
            TSSTConstrainScale: true,
            TSSTScrollersVisible: true,
            TSSTSessionRestore: true,
            TSSTAutoPageTurn: true,
            TSSTBackgroundColor: try! NSKeyedArchiver.archivedData(withRootObject: NSColor.white, requiringSecureCoding: true),
            TSSTWindowAutoResize: true,
            TSSTLoupeDiameter: 500,
            TSSTLoupePower: 2.0,
            TSSTStatusbarVisible: true,
            TSSTLonelyFirstPage: true,
            TSSTNestedArchives: true,
            TSSTUpdateSelection: 0
        ] as [String: Any]

        self.register(defaults: inits)
    }
}

