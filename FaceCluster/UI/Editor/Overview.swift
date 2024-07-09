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
    @State var selectedAttribute: String?
    //@State var selectedFaces: [TableFace] = []
    
    public static var forceSelectFaces: [UUID] = []
    @State private var pushForcedSelection: Bool = false
    @State var forceResetTable: Bool = false
    @State var alertMessage: String = ""
    @State var alertTitle: String = ""
    @State var waitingMessage: String = "Eating Spaghetti with chopsticks..."
    
    @State var addEmptyAttribute: Bool = false
    @State var showProgress = false
    @State var showCircleProgress: Bool = false
    @State var showGeneralAlert: Bool = false
    
    @State var tempTextField: String = ""
    @State var tempIntegerField: Int?
    
    let lightGrey = Color(red: 0.87, green: 0.87, blue: 0.87)
    
    var body : some View {
        HStack {
            NetworkOverview(network: network, context: self, layoutKey: network.layoutKey)
            VStack {
                Button("Export Full Face Images") {
                    for face in network.faces {
                        guard let img = face.getFullSizeImage() else {
                            continue
                        }
                        let name = face.path!.lastPathComponent
                        let _ = ImageUtils.saveImageAsJPG(img, at: network.savedPath.appending(path: "faces/\(name)-HD.jpg"))
                    }
                }.padding(.bottom, 6)
                    .controlSize(.large)
                
                Menu() {
                    Button("Empty Template") {
                        
                    }
                    
                    Button("Filled Template") {
                        
                    }
                    
                    Button("Full Table") {
                        
                    }
                } label: {
                    Label("Export CSV", systemImage: "tablecells.badge.ellipsis")
                }.controlSize(.large).frame(width: 160)
                
                
                
                Text("Faces:").frame(height: 16).padding(.top, 12)
                VStack {
                    Button("Conditional Select") {
                        
                    }
                    
                    Button() {
                        
                    } label: {
                        Label("Edit Selected", systemImage: "pencil")
                    }
                }.controlSize(.large)
                
                
                
                Text("Attributes:").frame(height: 16).padding(.top, 12)
                HStack {
                    Menu() {
                        Button("Facenet512") {
                            facenet()
                        }
                        .alert("", isPresented: $showProgress) {
                            HStack(spacing: 16) {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.blue)
                                Text("Processing...")
                                    .font(.headline)
                            }
                        } message: {
                            Button(role: .cancel) {
                                // Cancel Action
                            } label: {
                                Text("Cancel")
                            }
                        }
                        .controlSize(.large)
                        
                        Button("Custom CoreML") {
                            
                        }
                        
                        Button("T-SNE") {
                            
                        }
                        
                        Button("Import CSV") {
                            
                        }
                        
                        
                        Button("Create Empty") {
                            clearTempInput()
                            addEmptyAttribute = true
                        }
                        
                    } label: {
                        Label("Create", systemImage: "plus.circle")
                    }
                    .menuButtonStyle(BorderlessPullDownMenuButtonStyle())
                    .menuStyle(.borderedButton)
                    .frame(width: 112)
                    .controlSize(.large)
                    
                    Button(action: {
                        
                    }) {
                        Label("Remove", systemImage: "minus.circle")
                    }
                    .frame(width: 96)
                    .controlSize(.large)
                }
            }
            .frame(minWidth: 256, maxWidth:  256, minHeight: 256, maxHeight: .infinity)
            .background(lightGrey)
            .sheet(isPresented: $addEmptyAttribute) {
                CreateEmptyAttributePanel(context: self).frame(width: 360, height: 240)
            }
            .sheet(isPresented: $showCircleProgress) {
                VStack {
                    Text(waitingMessage)
                        .font(.headline)
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.blue))
                }.frame(width: 350, height: 240)
            }
            .alert(isPresented: $showGeneralAlert) {
                Alert(title: Text(alertTitle), message: Text(alertMessage))
            }
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
    
    func clearTempInput() {
        tempTextField = ""
        tempIntegerField = nil
    }
    
    func facenet() {
        let time = Date.now
        let facenet = FacenetWrapper()
        /*let images = network.getAlignedImageArray()
        facenet.detectFacesAsync(in: images)*/
        facenet.detectFacesSync(in: network, batchSize: 512)
        //let vectorKey = network.getUniqueKeyName(name: "Facenet512")
        //let confidenceKey = network.getUniqueKeyName(name: "Facenet512_Conf")
        let vectorKey = "Facenet512"
        let confidenceKey = "Facenet512_Conf"
        network.forceAppendAttribute(key: vectorKey, type: .Vector, dimensions: 512)
        network.forceAppendAttribute(key: confidenceKey, type: .Decimal, dimensions: nil)
        facenet.writeResults(key1: vectorKey, key2: confidenceKey)
        print("Time lapse: \(Date.now.timeIntervalSince(time))")
        forceResetTable = !forceResetTable
        
        var array = [[Double]]()
        for task in facenet.tasks {
            if(task.completed) {
                guard let tOut = task.output else {
                    continue
                }
                array.append(tOut)
            }
        }
        print(array.count, array[0].count)
        
        let tsne = T_SNE(data: array, dimensions: 512, perplexity: 50)
        let tr = tsne.transform(targetDimensions: 2, learningRate: 10, maxIterations: 100)
        //let tr = SwiftTsne().transform(data: array)
        for i in 0..<tr.count {
            network.faces[i].updateDisplayPosition(newPosition: DoublePoint(x: tr[i][0], y: tr[i][1]))
        }
        var string = ""
        for task in facenet.tasks {
            if(task.completed) {
                guard let tOut = task.output else {
                    continue
                }
                for i in 0...511 {
                    string.append("\(tOut[i]), ")
                }
            }
            string.removeLast(2)
            string.append("\n")
        }
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(string, forType: .string)
    }
    
    func showWaitingCircle(message: String="Updating network...") {
        waitingMessage = message
        showCircleProgress = true
    }
    
    func hideWaitingCircle() {
        showCircleProgress = false
    }
    
    func showGeneralMessageOnlyAlert(_ message: String="Failed to update face network.", title: String="Warning") {
        showGeneralAlert = true
        alertMessage = message
        alertTitle = title
    }

}
