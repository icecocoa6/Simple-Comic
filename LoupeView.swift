//
//  LoupeView.swift
//  Simple Comic
//
//  Created by Tomioka Taichi on 2020/04/18.
//

import Cocoa
import SwiftUI

class LoupeWindow: NSWindow {
    private var viewModel: LoupeViewModel {
        (self.contentView as! NSHostingView<LoupeView>).rootView.viewModel
    }
    
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: NSWindow.StyleMask.borderless, backing: backingStoreType, defer: flag)
        
        self.backgroundColor = NSColor.clear
        self.isOpaque = false
        self.ignoresMouseEvents = true
    }
    
    override func awakeFromNib() {
        self.contentView = NSHostingView(rootView: LoupeView())
    }
    
    func moveCenter(atPoint _center: NSPoint)
    {
        let center = CGVector(_center)
        let size = CGVector(self.frame.size)
        self.setFrameOrigin(CGPoint(center - size / 2.0))
        self.invalidateShadow()
    }
    
    var image: NSImage? {
        get { viewModel.image }
        set(value) { viewModel.image = value }
    }
    
    var diameter: CGFloat {
        get { viewModel.diameter }
        set(value) {
            viewModel.diameter = value
            let center = CGVector(self.frame.center)
            let size = CGVector(dx: diameter, dy: diameter)
            let origin = center - size / 2.0
            self.setFrame(CGRect(origin: CGPoint(origin), size: CGSize(size)),
                          display: true, animate: false)
        }
    }
}

class LoupeViewModel: ObservableObject {
    @Published var image: NSImage? = nil
    @Published var diameter: CGFloat = 200.0
}

struct LoupeView: View {
    @ObservedObject var viewModel = LoupeViewModel()
    let lineWidth: CGFloat = 4.0
    
    var body: some View {
        ZStack {
            if viewModel.image != nil {
                SwiftUI.Image(nsImage: viewModel.image!)
                    .clipShape(Circle())
                Circle()
                    .inset(by: lineWidth / 2)
                    .stroke(lineWidth: lineWidth)
                    .foregroundColor(Color.white)
            }
        }.frame(width: viewModel.diameter,
                height: viewModel.diameter,
                alignment: .center)
    }
}

struct LoupeView_Previews: PreviewProvider {
    static var previews: some View {
        LoupeView()
    }
}
