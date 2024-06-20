//
//  FileImporter.swift
//  FaceCluster
//
//  Created by El-Mundo on 01/06/2024.
//

import SwiftUI

struct FileImporter: View {
    @State private var showVideoImporter = false
    @State private var showProjectImporter = false
    @State private var tooltip = ""
    var handleImportFunc: (URL, Bool, ContentView?) -> Void
    var context: ContentView?
    
    let buttonFrameWidth: CGFloat = 160, buttonFrameHeight: CGFloat = 48
    let buttonWidth: CGFloat = 120
    let panelMinWidth: CGFloat = 320, panelMinHeight: CGFloat = 360
    public static let toolbarColor = Color(red: 0.87, green: 0.87, blue: 0.87)

    var body: some View {
        HStack {
            VStack {
                Button {
                    showVideoImporter = true
                } label: {
                    Label(String(localized: "Import Video File"), systemImage: "movieclapper")
                        .frame(width: buttonWidth)
                }
                .frame(width: buttonFrameWidth, height: buttonFrameHeight)
                .controlSize(.large)
                .onHover(perform: { hovering in
                    if(hovering) {
                        tooltip = String(localized: "Help ImportVideo")
                    } else {
                        tooltip = ""
                    }
                })
                .fileImporter(
                    isPresented: $showVideoImporter,
                    allowedContentTypes: [.movie],
                    allowsMultipleSelection: false
                ) { result in
                    switch result {
                    case .success(let files):
                        files.forEach { file in
                            // gain access to the directory
                            let gotAccess = file.startAccessingSecurityScopedResource()
                            if !gotAccess { return }
                            // access the directory URL
                            // (read templates in the directory, make a bookmark, etc.)
                            handleImportFunc(file, true, context)
                            // release access
                            file.stopAccessingSecurityScopedResource()
                        }
                    case .failure(let error):
                        // handle error
                        print(error)
                    }
                }
  
                Button {
                    showProjectImporter = true
                } label: {
                    Label(String(localized: "Load Existing Project"), systemImage: "doc.circle")
                        .frame(width: buttonWidth)
                }
                .frame(width: buttonFrameWidth, height: buttonFrameHeight)
                .controlSize(.large)
                .onHover(perform: { hovering in
                    if(hovering) {
                        tooltip = String(localized: "Help ImportProject")
                    } else {
                        tooltip = ""
                    }
                })
                .fileImporter(
                    isPresented: $showProjectImporter,
                    allowedContentTypes: [.json],
                    allowsMultipleSelection: false
                ) { result in
                    switch result {
                    case .success(let files):
                        files.forEach { file in
                            // gain access to the directory
                            let gotAccess = file.startAccessingSecurityScopedResource()
                            if !gotAccess { return }
                            // access the directory URL
                            // (read templates in the directory, make a bookmark, etc.)
                            handleImportFunc(file, false, context)
                            // release access
                            file.stopAccessingSecurityScopedResource()
                        }
                    case .failure(let error):
                        // handle error
                        print(error)
                    }
                }
                
                Button(action: {NSApplication.shared.terminate(nil)}, label: {
                    Text("Exit ")
                        .frame(width: buttonWidth)
                })
                .frame(width: buttonFrameWidth, height: buttonFrameHeight)
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.large)
                
                Text(tooltip)
                    .frame(minHeight: 24, maxHeight: 64, alignment: .bottom)
                    .padding(.bottom, 24)
                    .multilineTextAlignment(.center)
            }
            .frame(minWidth: buttonFrameWidth, maxWidth: buttonFrameWidth, maxHeight: .infinity, alignment: .leading)
            .padding(.horizontal, buttonFrameWidth / 8)
            .background(FileImporter.toolbarColor)
            
            VStack {
                
            }
            .padding(.leading, buttonFrameWidth / 4)
            .padding(.trailing, buttonFrameWidth / 4)
            .frame(minWidth: panelMinWidth, maxWidth: .infinity, alignment: .center)
        }
        .frame(minWidth: buttonFrameWidth + panelMinWidth, maxWidth: .infinity, minHeight: max(panelMinHeight, buttonFrameHeight * 4), alignment: .leading)
    }
    
}

func returnURL(url: URL, isVideo: Bool, view: ContentView?) {
    print("Processing file: \(url.absoluteString)")
    
    if(MediaManager.instance == nil) {
        MediaManager.instance = MediaManager(importedURL: url, isVideo: isVideo)
    } else {
        MediaManager.instance!.setMediaFile(importedURL: url, isVideo: isVideo)
    }
    
    if(isVideo) {
        view?.state = 1
    } else {
        view?.state = 2
    }
}

#Preview {
    FileImporter(handleImportFunc: returnURL, context: nil)
}
