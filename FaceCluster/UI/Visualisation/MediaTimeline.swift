//
//  MediaTimeline.swift
//  FaceCluster
//
//  Created by El-Mundo on 15/08/2024.
//

import Foundation
import SwiftUI

struct MediaTimeline: View {
    @Environment(\.self) var environment
    var project: FaceClusterProject
    @State var showFaceTexture = false
    @State private var backgroundColour: Color = Color(red: NetworkView.backgroundColour.x, green: NetworkView.backgroundColour.y, blue: NetworkView.backgroundColour.z)
    @State var xStretch: Float = TimelineRenderer.xStretch
    @State var selectedCluster: String?
    
    @State var scaling: Float = TimelineRenderer.scaling
    @State var xMode: Int = TimelineRenderer.xMode
    @State var allAttributes: [String] = []
    
    @State var mergedClusterId: [String : Int] = [:]
    @State var yMode: String = "Cluster"
    
    var body: some View {
        HStack {
            TimelineRenderer(project: project, context: self)
                .edgesIgnoringSafeArea(.all)
            NavigationStack {
                ForEach(mergedClusterId.keys.sorted(), id: \.self) { c in
                    HStack {
                        Text("\(c)")
                        Rectangle().fill(Color(red: Double(CLUSTER_PALETTE[(mergedClusterId[c] ?? 0) % 14][0])/255, green: Double(CLUSTER_PALETTE[(mergedClusterId[c] ?? 0) % 14][1])/255, blue: Double(CLUSTER_PALETTE[(mergedClusterId[c] ?? 0) % 14][2])/255))
                            .frame(width: 32, height:  32)
                    }.frame(height: 64)
                }
            }.frame(width: 64)
        }
        HStack {
            ColorPicker("Background", selection: $backgroundColour)
            .onChange(of: backgroundColour, {
                let colour = backgroundColour.resolve(in: environment)
                NetworkView.backgroundColour = SIMD3<Double>(Double(colour.red), Double(colour.green), Double(colour.blue))
            })
            
            Toggle(isOn: $showFaceTexture) {
                Text("Show Face Texture")
            }
            .toggleStyle(.switch)
            .onChange(of: showFaceTexture, {
                NetworkView.allowMultipleSelection = showFaceTexture
            })
            
            Text("X Axis")
            Picker("", selection: $xMode) {
                Text("Merged").tag(0 as Int)
                Text("Collapsed").tag(1 as Int)
                Text("Active").tag(2 as Int)
            }
            .onChange(of: xMode, {
                TimelineRenderer.xMode = xMode
            })
            
            Text("Y Axis")
            Picker("", selection: $yMode) {
                Text("Cluster").tag("Cluster")
                ForEach(allAttributes, id: \.self) { c in
                    Text(c).tag(c)
                }
            }
            .onAppear() {
                for path in project.paths {
                    guard let temp = try? FaceNetwork(url: AppDelegate.workspace.appending(component: path)) else { continue }
                    for attribute in temp.attributes {
                        if(attribute.type == .Decimal || attribute.type == .Integer) {
                            if(!allAttributes.contains(attribute.name)) {
                                allAttributes.append(attribute.name)
                            }
                        }
                    }
                }
            }
            .onChange(of: yMode, {
                TimelineRenderer.yMode = yMode
            })
            
            
            Text("Scaling ")
            Slider(value: $scaling, in: 0.5...2.0)
            .onChange(of: scaling, {
                TimelineRenderer.scaling = scaling
            })
            
            Text("X Stretch ")
            Slider(value: $xStretch, in: 0.1...2.0)
            .onChange(of: xStretch, {
                TimelineRenderer.xStretch = xStretch
            })
        }
    }
}
