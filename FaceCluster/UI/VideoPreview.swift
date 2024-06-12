//
//  VideoPreview.swift
//  FaceCluster
//
//  Created by El-Mundo on 01/06/2024.
//

import Foundation
import SwiftUI
import AVKit

struct VideoPreview: View {
    @State var preview = false
    @State var fps: Float=0
    @State var dimension: CGSize=CGSize.zero
    
    let context: ContentView?
    let minVideoWidth: CGFloat = 480, minVideoHeight: CGFloat = 240
    let padding: CGFloat = 20
    
    var body: some View {
        VStack {
            if(preview) {
                //Preview
                Text("Video Preview Frame")
                    .frame(minWidth: minVideoWidth, maxWidth: .infinity, minHeight: minVideoHeight, maxHeight: .infinity)
                    .border(/*@START_MENU_TOKEN@*/Color.black/*@END_MENU_TOKEN@*/)
                    .padding(.horizontal, padding)
                    .padding(.top, padding)
                Text("Resolution 0x0, 24 fps")
                    .frame(minHeight: 12, maxHeight: 12)
            } else {
                //Runtime
                VideoPlayer(player: AVPlayer(url: MediaManager.instance!.getURL()))
                    .frame(minWidth: minVideoWidth, maxWidth: .infinity, minHeight: minVideoHeight, maxHeight: .infinity)
                    .padding(.horizontal, padding)
                    .padding(.top, padding)
                let txt = String(localized: "Resolution").appending(" \(Int(dimension.width))x\(Int(dimension.height)), \(fps) fps")
                Text(txt)
                    .frame(minHeight: 12, maxHeight: 12)
            }
        }
        .frame(alignment: .top)
        .onAppear() {
            if(!preview) {
                MediaManager.instance!.getInfo(display: self)
            }
        }
        
        VPToolbarView(context: self)
    }
}

#Preview {
    VideoPreview(preview: true, context: nil)
}
