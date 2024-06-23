//
//  NetworkEditor.swift
//  FaceCluster
//
//  Created by El-Mundo on 19/06/2024.
//

import SwiftUI

struct NetworkEditor: View {
    @State var preview = false
    //var toolbar = NetworkToolbar()
    @State var faceInfo = ""
    @State var editButtonText = "Edit"
    /// Set this less than 1 for single selection. No greater than 10 for performance
    @State var radius: Float = 2.0
    @State var isEditing = false
    @State var log = ""
    
    static var networkDisplayed: FaceNetwork?
    static var networkDisplayedFacemapBuffer: MTLBuffer?
    static var networkDisplayedPointDistanceBuffer: MTLBuffer?
    
    var body: some View {
        VStack {
            HStack {
                ZStack {
                    if(!preview) {
                        NetworkView(context: self)
                    } else {
                        Rectangle()
                    }
                }
                
                VStack {
                    Text("Selected face:")
                        .frame(height: 12)
                    Text(faceInfo)
                        .frame(height: 128)
                    Button {
                        NetworkView.allowEditing = !NetworkView.allowEditing
                        editButtonText = NetworkView.allowEditing ? "Preview" : "Edit"
                    } label: {
                        Text(editButtonText)
                    }
                    .controlSize(.large)
                    
                    Button {
                        NetworkEditor.networkDisplayed?.generateClusters(faceMapBuffer: NetworkEditor.networkDisplayedFacemapBuffer, distanceBuffer: NetworkEditor.networkDisplayedPointDistanceBuffer)
                    } label: {
                        Text("Cluster")
                    }
                    .controlSize(.large)
                    
                    if(NetworkView.allowEditing) {
                        Slider(
                            value: $radius,
                            in: 0.98...10.0,
                            onEditingChanged: { editing in
                                isEditing = editing
                            }
                        )
                        Text("Select range: ".appending(radius < 0.999 ? "Single" : "\(radius)"))
                            .foregroundColor(isEditing ? .red : .blue)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .padding(.trailing, 12)
                .frame(width: 180)
            }
        }
        .frame(minWidth: 12, maxWidth: .infinity, minHeight: 24, maxHeight: .infinity)
    }
}

#Preview {
    NetworkEditor(preview: true)
}
