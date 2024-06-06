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
    let context: ContentView?
    let minVideoWidth: CGFloat = 480, minVideoHeight: CGFloat = 320
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
            } else {
                //Runtime
                VideoPlayer(player: AVPlayer(url: MediaManager.instance!.getURL()))
                    .frame(minWidth: minVideoWidth, maxWidth: .infinity, minHeight: minVideoHeight, maxHeight: .infinity)
                    .padding(.horizontal, padding)
                    .padding(.top, padding)
            }
        }
        .frame(alignment: .top)
        
        VPToolbarView(context: self)
    }
}

#Preview {
    VideoPreview(preview: true, context: nil)
}
