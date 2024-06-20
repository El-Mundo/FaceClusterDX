//
//  FacePreview.swift
//  FaceCluster
//
//  Created by El-Mundo on 04/06/2024.
//

import Foundation
import SwiftUI

struct FacePreview: View {
    @State var preview = false
    @State var image: CGImage? = nil
    @State var boxes: [[Double]] = []
    
    var body : some View {
        ZStack {
            Text("df")
            
            if(image != nil) {
                let nsImage = NSImage.init(cgImage: image!, size: .zero)
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .overlay(
                         ZStack {
                             GeometryReader{ (geometry: GeometryProxy) in
                                     ForEach(boxes , id: \.self){ (box: [Double]) in
                                         let w = geometry.size.width
                                         let h = geometry.size.height
                                         let ori = CGPoint(x: box[0] * w, y: box[1] * -h + h)
                                         let ran = CGSize(width: box[2] * w, height: box[3] * -h)
                                         Rectangle().path(in: CGRect(origin: ori, size: ran)).stroke(Color.purple, lineWidth: 2.0)
                                     }
                                 }
                         }
                )
            }
        }
    }
    
}

#Preview {
    FacePreview(preview: true)
}
