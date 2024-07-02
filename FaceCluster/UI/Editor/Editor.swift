//
//  Editor.swift
//  FaceCluster
//
//  Created by El-Mundo on 21/06/2024.
//

import SwiftUI

struct Editor: View {
    @State var state = 0
    @State var preview = false
    var freezeNetworkView = false
    
    var body: some View {
        VStack {
            if(state == 0) {
                NetworkEditor(preview: preview, context: self)
            } else if(state == 1) {
                FrameView(network: MediaManager.instance!.getEditFaceNetwork()!)
            } else {
                Overview(network: MediaManager.instance!.getEditFaceNetwork()!, context: self)
            }
            
            HStack {
                HStack {
                    Picker("", selection: $state) {
                        Text("Network").tag(0 as Int)
                        Text("Frames").tag(1 as Int)
                        Text("Overview").tag(2 as Int)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                .frame(width: 240, alignment: .bottom)
                .onChange(of: state, changeState)
                
                Text("Bottom bar")
            }
            .frame(height: 12)
            .padding(.bottom, 6)
        }
    }
    
    func changeState() {
        if(state != 0) {
            if(freezeNetworkView) {
                state = 0
                networkEditorInstance?.console += String(localized: "Cannot switch mode when generating clusters\n\n")
            } else {
                NetworkEditor.networkDisplayedFacemapBuffer = nil
                NetworkEditor.networkDisplayedPointDistanceBuffer = nil
            }
        }
        //print(state)
    }
}

#Preview {
    Editor(preview: true)
}
