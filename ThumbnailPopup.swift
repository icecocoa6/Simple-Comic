//
//  ThumbnailPopup.swift
//  Simple Comic
//
//  Created by Tomioka Taichi on 2020/04/15.
//

import SwiftUI
import Combine

class ThumbnailPopupViewModel: ObservableObject {
    @Published var image: NSImage?
    @Published var caret: CGFloat
    
    init(image: NSImage?, caret: CGFloat) {
        self.image = image
        self.caret = caret
    }
}

struct Bubble: Shape {
    @Binding var radius: CGFloat
    @Binding var caretSize: CGSize
    @Binding var caretPos: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: caretPos + caretSize.width / 2, y: rect.maxY - caretSize.height))
        path.addLine(to: CGPoint(x: caretPos, y: rect.maxY))
        path.addLine(to: CGPoint(x: caretPos - caretSize.width / 2, y: rect.maxY - caretSize.height))
        path.addArc(tangent1End: CGPoint(x: 0, y: rect.maxY - caretSize.height),
                    tangent2End: CGPoint(x: 0, y: rect.midY),
                    radius: radius)
        path.addArc(tangent1End: CGPoint(x: 0, y: 0),
                    tangent2End: CGPoint(x: rect.midX, y: 0),
                    radius: radius)
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: 0),
                    tangent2End: CGPoint(x: rect.maxX, y: rect.midY),
                    radius: radius)
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY - caretSize.height),
                    tangent2End: CGPoint(x: caretPos + caretSize.width / 2, y: rect.maxY - caretSize.height),
                    radius: radius)
        path.closeSubpath()
        return path
    }
}

struct ThumbnailPopup: View {
    @State private(set) var radius: CGFloat = 5
    @State private(set) var caretSize: CGSize = CGSize(width: 10, height: 5)
    @ObservedObject var viewModel = ThumbnailPopupViewModel(image: nil, caret: 0.0)
    
    var body: some View {
        ZStack {
            Bubble(radius: $radius, caretSize: $caretSize, caretPos: $viewModel.caret)
                .foregroundColor(Color.white)
            if viewModel.image != nil {
                SwiftUI.Image(nsImage: viewModel.image!)
                    .padding(.leading, radius)
                    .padding(.trailing, radius)
                    .padding(.top, radius)
                    .padding(.bottom, radius + caretSize.height)
            }
        }
    }
}

struct ThumbnailPopup_Previews: PreviewProvider {
    static var previews: some View {
        return ThumbnailPopup()
    }
}
