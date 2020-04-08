//
//  ImagePack.swift
//  Simple Comic
//
//  Created by Tomioka Taichi on 2020/04/07.
//

import Foundation

class ImagePack {
    class Key: NSObject {
        let image: Image
        let index: Int
        
        init(image: Image, index: Int) {
            self.image = image
            self.index = index
        }
        
        override func isEqual(_ object: Any?) -> Bool {
            if let key = object as? Key {
                return key.image == self.image && key.index == self.index
            }
            return false
        }
        
        override var hash: Int {
            return self.image.hash ^ self.index
        }
    }

    static let globalCache: NSCache<Key, CGImage> = {
        let cache = NSCache<Key, CGImage>()
        cache.totalCostLimit = 2 * 1024 * 1024 * 1024
        return cache
    }()
    private let image: Image
    private var cgImageSource: CGImageSource? = nil

    init(image: Image) {
        self.image = image
    }

    var count: Int {
        if self.cgImageSource == nil { self.cgImageSource = self.image.imageSource }
        return CGImageSourceGetCount(self.cgImageSource!)
    }

    func image(at index: Int) -> CGImage {
        if let cache = ImagePack.globalCache.object(forKey: ImagePack.Key(image: self.image, index: index)) {
            return cache
        }
        if self.cgImageSource == nil { self.cgImageSource = self.image.imageSource }
        let img = CGImageSourceCreateImageAtIndex(self.cgImageSource!, index, nil)!
        let bytes = img.bytesPerRow * img.height
        ImagePack.globalCache.setObject(img, forKey: ImagePack.Key(image: self.image, index: index), cost: bytes)
        return img
    }

    func property(at index: Int) -> [CFString: Any] {
        if self.cgImageSource == nil { self.cgImageSource = self.image.imageSource }
        return CGImageSourceCopyPropertiesAtIndex(self.cgImageSource!, index, nil) as! [CFString: Any]
    }
}
