//
//  Overview.swift
//  FaceCluster
//
//  Created by El-Mundo on 28/06/2024.
//

import SwiftUI

struct Overview: View {
    @State var network: FaceNetwork
    var context: Editor
    @State var tableWidth: CGFloat = 0
    @State var selectedFaces: [TableFace] = []
    
    public static var forceSelectFaces: [UUID] = []
    @State private var pushForcedSelection: Bool = false
    
    let lightGrey = Color(red: 0.87, green: 0.87, blue: 0.87)
    
    var body : some View {
        HStack {
            NetworkOverview(network: network, layoutKey: network.layoutKey)
            VStack {
                Button("Export Full Face Images") {
                    for face in network.faces {
                        guard let img = face.getFullSizeImage() else {
                            continue
                        }
                        let name = face.path!.lastPathComponent
                        let _ = ImageUtils.saveImageAsJPG(img, at: network.savedPath.appending(path: "Faces/\(name)-HD.jpg"))
                    }
                }.padding(.bottom, 6)
                .controlSize(.large)
                
                Button("Facenet") {
                    let time = Date.now
                    let facenet = FacenetWrapper()
                    /*let images = network.getAlignedImageArray()
                    facenet.detectFacesAsync(in: images)*/
                    facenet.detectFacesSync(in: network, batchSize: 512)
                    print("Time lapse: \(Date.now.timeIntervalSince(time))")
                }
                .controlSize(.large)
            }
            .frame(minWidth: 256, maxWidth:  256, minHeight: 256, maxHeight: .infinity)
            .background(lightGrey)
        }
        FaceNetworkTable(network: network, context: self)
            .overlay {
                    GeometryReader { geo in
                        let rect = geo.frame(in: .global)
                        Color.clear.onAppear() {
                            tableWidth = rect.width
                        }.onChange(of: rect.width) {
                            tableWidth = rect.width
                        }
                }
            }
            .onChange(of: pushForcedSelection, {
                
            })
    }
}
