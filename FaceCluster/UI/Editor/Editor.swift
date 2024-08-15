//
//  Editor.swift
//  FaceCluster
//
//  Created by El-Mundo on 21/06/2024.
//

import SwiftUI
import UniformTypeIdentifiers

struct Editor: View {
    @State var state = 0
    @State var preview = false
    @State var showExporter = false
    @State var showMessage = false
    @State var menuMessage = ""
    @State var menuMessageHeader = ""
    @State var cachedDoc: ProjectDocument?
    
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
                .padding(.leading, 32)
                
                Spacer()
                
                //Text("Bottom bar")
                Button() {
                    let proj = FaceClusterProject.getInstance()!
                    cachedDoc = ProjectDocument(project: proj)
                    showExporter = true
                } label: {
                    Label("Save Project", systemImage: "square.and.arrow.down.fill")
                }.buttonStyle(.borderedProminent).tint(.cyan)
                .padding(.trailing, 32)
                .controlSize(.large)
            }
            .fileExporter(isPresented: $showExporter, document: cachedDoc, contentType: faceClusterProjectFileExtension) { result in
                switch result {
                case .success(let url):
                    showInfo(String(localized: "Saved project to ") + url.path(percentEncoded: false), title: String(localized: "Success"))
                    break
                case .failure(let error):
                    showInfo(error.localizedDescription, title: String(localized: "Error"))
                    break
                }
                cachedDoc = nil
            }.frame(height: 24)
            .padding(.bottom, 6)
        }
        .sheet(isPresented: $showMessage) {
            VStack {
                Text(menuMessageHeader).font(.headline)
                Text(menuMessage)
                    .padding(.bottom, 12)
                    .padding(.horizontal, 24)
                Button("Continue") { showMessage = false }
                    .padding(.bottom, 12)
            }
        }
    }
    
    func showInfo(_ message: String, title: String="Info") {
        menuMessage = message
        menuMessageHeader = title
        showMessage = true
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
