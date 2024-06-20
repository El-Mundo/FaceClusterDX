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
    
    @Environment(\.openWindow) var openWindow
    @Environment(\.dismissWindow) var dismissWindow
    
    var body: some View {
        if(state == 0) {
            FileImporter(handleImportFunc: returnURL, context: self)
        } else if(state == 1) {
            VideoPreview(context: self)
        } else if(state == 2) {
            ProgressBar(context: self)
        } else if(state == 3) {
            
        } else if(state == 4) {
            VStack{
                Text("No face images found in all extracted video frames.\nRedirecting to the import menu.")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                
                Button(action: {
                    state = 0
                }, label: {
                    Text("Redirect")
                })
                .controlSize(.large)
                .padding(.top, 12)
            }.frame(minWidth: 240, minHeight: 120)
        } else if(state == 5) {
            /*VStack { }
            .onAppear() {
                openWindow(id: "Editor")
                dismissWindow(id: "Main")
            }*/
            NetworkEditor()
        }
    }
    
    func resetPB() {
        pbProgress = 0.0
        pbInfo = ""
    }
    
    func openEditor() {
        if let window = NSApplication.shared.windows.first(where: { $0.identifier == NSUserInterfaceItemIdentifier("WindowB") }) {
                window.makeKeyAndOrderFront(nil)
            } else {
                let window = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                    styleMask: [.titled, .closable, .resizable],
                    backing: .buffered, defer: false)
                window.identifier = NSUserInterfaceItemIdentifier("WindowB")
                window.title = "Window B"
                window.contentView = NSHostingView(rootView: NetworkEditor())
                window.makeKeyAndOrderFront(nil)
            }
    }

}

#Preview {
    ContentView(state: 4, app: nil)
}
