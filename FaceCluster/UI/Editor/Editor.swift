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
    
    var body: some View {
        VStack {
            if(state == 0) {
                NetworkEditor(preview: preview)
            } else if(state == 1) {
                Rectangle()
            } else {
                Circle()
            }
            
            HStack {
                HStack {
                    Picker("", selection: $state) {
                        Text("Network").tag(0 as Int)
                        Text("Faces").tag(1 as Int)
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
            NetworkEditor.networkDisplayedFacemapBuffer = nil
            NetworkEditor.networkDisplayedPointDistanceBuffer = nil
        }
        //print(state)
    }
}

#Preview {
    Editor(preview: true)
}
