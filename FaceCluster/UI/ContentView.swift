//
//  ContentView.swift
//  FaceCluster
//
//  Created by El-Mundo on 01/06/2024.
//

import SwiftUI
import AVKit

struct ContentView: View {
    ///0-Import file, 1-Preview video, 2-Import project
    @State var state = 0
    @State var pbProgress = 0.0
    @State var pbInfo = ""
    
    var app: FaceClusterApp?
    
    var body: some View {
        if(state == 0) {
            FileImporter(handleImportFunc: returnURL, context: self)
        } else if(state == 1) {
            VideoPreview(context: self)
        } else if(state == 2) {
            ProgressBar(context: self)
        } else if(state == 3) {
            
        }
    }
    
    func resetPB() {
        pbProgress = 0.0
        pbInfo = ""
    }

}

#Preview {
    ContentView(app: nil)
}
