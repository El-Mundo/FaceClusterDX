//
//  NetworkEditor.swift
//  FaceCluster
//
//  Created by El-Mundo on 19/06/2024.
//

import SwiftUI

struct NetworkEditor: View {
    @State var preview = false
    
    var body: some View {
        VStack {
            HStack {
                ZStack {
                    if(!preview) {
                        NetworkView()
                    } else {
                        Rectangle()
                    }
                }
                .padding(.top, 12)
                
                VStack {
                    Text("Toolbar")
                }
                .frame(width: 180)
                .padding(.trailing, 12)
            }
            
            HStack {
                Text("Bottom bar")
            }
            .frame(height: 12)
            .padding(.bottom, 6)
        }
        .frame(minWidth: 640, maxWidth: .infinity, minHeight: 320, maxHeight: .infinity)
    }
}

#Preview {
    NetworkEditor(preview: true)
}
