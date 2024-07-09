//
//  NetworkEditor.swift
//  FaceCluster
//
//  Created by El-Mundo on 19/06/2024.
//

import SwiftUI

var networkEditorInstance: NetworkEditor?

struct NetworkEditor: View {
    @Environment(\.self) var environment
    
    @State var preview = false
    //var toolbar = NetworkToolbar()
    @State var faceInfo = [String]()
    @State var editButtonText = "Edit"
    /// Set this less than 1 for single selection. No greater than 10 for performance
    @State var radius: Float = 2.0
    @State var isEditing = false
    @State var console = ""
    @State var camera = SIMD3<Float>(0, 0, -5.0)
    @State var clusteringThreshold: Float = 10.0
    @State var showDisabled = true
    @State var clusterDisplayMode = 2
    @State private var backgroundColour: Color = Color(red: 0, green: 0, blue: 0)
    var context: Editor?
    var clusterUpdateReqruied: Bool = false
    
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
                    let cx = "\(round(camera.x*100)/100)"
                    let cy = "\(round(camera.y*100)/100)"
                    let cz = "\(round(camera.z*100)/100)"
                    Text("View: \(cx), \(cy), \(cz)")
                        .frame(height: 12)
                        .padding(.top, 12)
                    Button {
                        NetworkView.camera = SIMD3<Float>(0, 0, -5.0)
                        camera = SIMD3<Float>(0, 0, -5.0)
                    } label: {
                        Text("Reset")
                    }
                    .buttonStyle(.bordered)
                    .padding(.bottom, 12)
                    
                    Text("Selected face:")
                        .frame(height: 12)
                    VStack(alignment: .leading, spacing: 0) {
                        if(faceInfo.count == 5) {
                            Text(faceInfo[0]).lineLimit(1)
                            Text(faceInfo[1]).lineLimit(2)
                            Text(faceInfo[2]).lineLimit(1)
                            Text(faceInfo[3]).lineLimit(1)
                            Text(faceInfo[4]).lineLimit(1)
                        } else if(faceInfo.count == 2) {
                            Text(faceInfo[0])
                            Text(faceInfo[1])
                        }
                    }
                    .frame(height: 96)
                    Button {
                        NetworkView.allowEditing = !NetworkView.allowEditing
                        editButtonText = NetworkView.allowEditing ? "Preview" : "Edit"
                    } label: {
                        Text(editButtonText)
                    }
                    .controlSize(.large)
                    .frame(height: 32)
                    .padding(.bottom, 12)
                    
                    if(!NetworkView.allowEditing) {
                        HStack {
                            Text("Distance:")
                            TextField("Clustering distance", value: $clusteringThreshold, format: .number)
                                .frame(width: 32)
                                .onSubmit {
                                    if(clusteringThreshold < 0) {
                                        clusteringThreshold = 0
                                    }
                                }
                            Button {
                                NetworkEditor.networkDisplayed?.generateClusters(faceMapBuffer: NetworkEditor.networkDisplayedFacemapBuffer, distanceBuffer: NetworkEditor.networkDisplayedPointDistanceBuffer, clusteringThreshold)
                                NetworkView.clusterUpdateRequested = true
                            } label: {
                                Text("Cluster")
                            }
                            .controlSize(.large)
                        }
                    }
                    
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
                    
                    Picker("", selection: $clusterDisplayMode) {
                        Text("Hidden").tag(0 as Int)
                        Text("Lines").tag(1 as Int)
                        Text("Polygon").tag(2 as Int)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.bottom, 12)
                    
                    Toggle(isOn: $showDisabled) {
                                Text("Show deactivated")
                            }
                            .toggleStyle(.checkbox)
                            .onChange(of: showDisabled, {
                                NetworkView.showDisabledFaces = showDisabled
                            })
                    
                    ColorPicker("Background", selection: $backgroundColour)
                        .onChange(of: backgroundColour, {
                            let colour = backgroundColour.resolve(in: environment)
                            NetworkView.backgroundColour = SIMD3<Double>(Double(colour.red), Double(colour.green), Double(colour.blue))
                        })
                    
                    Text("Console")
                        .padding(.top, 12)
                    ScrollViewReader { reader in
                        ScrollView {
                        Text(console)
                                .font(.subheadline)
                                .id("editor_console")
                                .padding(2)
                        }
                        .frame(minWidth: 160, maxWidth: 160, minHeight: 32, maxHeight: .infinity, alignment: .topLeading)
                        .background(.white)
                        .border(.black)
                        .onAppear() {
                            console = MediaManager.importMessage
                            networkEditorInstance = self
                        }
                        .onChange(of: console) {
                            reader.scrollTo("editor_console", anchor: .bottom)
                        }
                      }
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .padding(.trailing, 12)
                .frame(width: 180)
            }
        }
        .frame(minWidth: 450, maxWidth: .infinity, minHeight: 450, maxHeight: .infinity)
    }
}

#Preview {
    NetworkEditor(preview: true, context: nil)
}
