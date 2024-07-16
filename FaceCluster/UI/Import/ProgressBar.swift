//
//  ProgressView.swift
//  FaceCluster
//
//  Created by El-Mundo on 04/06/2024.
//

import Foundation
import SwiftUI

struct ProgressBar: View {
    @State var preview = false
    var context: ContentView?
    
    public static var progressBinding: Binding<CGFloat>? = nil
    
    let pbMinWidth: CGFloat = 128, pbMaxWidth: CGFloat = 256, pbMinHeight: CGFloat = 32, pbMaxHeight: CGFloat = 32

    var body: some View {
        VStack {
            Text(preview ? "Preview" : context!.pbInfo).padding(.top, 12)
            
            HStack {
                ProgressView(value: preview ? 0 : context!.pbProgress)
                    .frame(minWidth: pbMinWidth, maxWidth: pbMaxWidth, minHeight: pbMinHeight, maxHeight: pbMaxHeight)
                    .padding(.leading, 24)
                Text(preview ? "5%" : toPercentage(d: context!.pbProgress))
                
                Button(String(localized: "Terminate")) {
                    if(!preview) {
                        NSApplication.shared.terminate(nil)
                    }
                }
                .frame(width: 96, height: 48)
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.large)
            }
        }.onAppear() {
            guard let m = MediaManager.instance else { return }
            if(!m.getIsVideo()) {
                MediaManager.instance?.loadExistingProject(context: context!)
            }
            ProgressBar.progressBinding = context?.$pbProgress
        }
    }
    
}

func toPercentage(d: Double) -> String {
    let p = Int(d * 100)
    return "\(p)%"
}

#Preview {
    ProgressBar(preview: true, context: nil)
}
