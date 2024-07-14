//
//  NetworkOverview.swift
//  FaceCluster
//
//  Created by El-Mundo on 28/06/2024.
//

import SwiftUI

struct NetworkOverview: View {
    @State var network: FaceNetwork?
    @State var files: Int = 0
    @State var allPointFields = [String]()
    var context: Overview?
    @State var layoutKey: String
    
    var body : some View {
        VStack {
            Text("Network Overview")
                .font(.headline)
                .padding(.top, 6)
            HStack {
                Text("Faces: \(network?.faces.count ?? 0)").padding(.trailing, 32)
                Text("Attributes: \(network?.attributes.count ?? 0)").padding(.trailing, 32)
                Text("Clusters: \(network?.clusters.count ?? 0)")
            }.padding(.top, 6).onAppear(perform: countJPEGFiles)
            Text("Path: \(network?.savedPath.path(percentEncoded: false) ?? "Preview/My/Workspace")")
            //Text("Created: \(network?.media?.created.description ?? "1999/12/31")")
            
            Text("Media Properties")
                .padding(.vertical, 6)
                .font(.headline)
            Text("Media file: \(network?.media?.path ?? "Preview/My/Video")")
            Text("Saved frame images: \(files)")
            HStack {
                let inter = round(Float(network?.media?.interval ?? 0) * 100) / 100
                Text("Sampling interval: \(inter) sec").padding(.trailing, 32)
                let per = round(Float(network?.media?.downsample ?? 0) * 10) / 10
                Text("Frame downsampling: \(per)%")
            }
            
            HStack {
                Text("Network display positioning attribute:")
                    .font(.headline)
                Picker(selection: $layoutKey, label: Text("")) {
                    ForEach(allPointFields, id: \.self) {p in
                        //let att = allPointFields[i]
                        //Text(att).tag(att)
                        Text(p)
                    }
                }
                .onChange(of: layoutKey) {
                    context?.network.layoutKey = layoutKey
                }.frame(width: 160).padding(.vertical, 6)
            }
        }
        .onChange(of: context?.forceResetTable, {
            countJPEGFiles()
        }).frame(minWidth: 128, maxWidth: .infinity)
    }
    
    func countJPEGFiles() {
        allPointFields.removeAll()
        
        guard let nt = network else {
            files = 0
            allPointFields = ["Perview", "Menu", "Items"]
            return
        }
        
        for attribute in nt.attributes {
            if(attribute.type == .Point) {
                allPointFields.append(attribute.name)
            }
        }
        
        let fileManager = FileManager.default
        do {
            let directoryURL = nt.savedPath.appending(component: "frames/")
            let contents = try fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
            let jpegFiles = contents.filter { $0.pathExtension.lowercased() == "jpg" || $0.pathExtension.lowercased() == "jpeg" }
            files = jpegFiles.count
        } catch {
            print("Error while enumerating files: \(error.localizedDescription)")
            files = 0
        }
    }
}

#Preview {
    NetworkOverview(layoutKey: "Preview")
}
