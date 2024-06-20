//
//  FaceClusterApp.swift
//  FaceCluster
//
//  Created by El-Mundo on 01/06/2024.
//

import SwiftUI

@main
struct FaceClusterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup(id: "Main") {
            ContentView(app: self)
                .frame(minWidth: 360, maxWidth: .infinity, minHeight: 320, maxHeight: .infinity, alignment: .center)
                .navigationTitle("MacOS Face Clustering Toolkit")
            //.fixedSize()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }

}

