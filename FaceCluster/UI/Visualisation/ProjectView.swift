//
//  ProjectView.swift
//  FaceCluster
//
//  Created by El-Mundo on 12/12/2024.
//

import SwiftUI

struct ProjectView: View {
    @State private var selectedNetwork: String?
    @State private var selectedCluster: FaceClusterPreview?
    @State private var alertContent: String = ""
    @State private var showAlert = false
    @State private var newName: String = ""
    @State private var newPos: DoublePoint = DoublePoint(x: 0, y: 0)
    @State private var newDisabled: Bool = false
    
    @State private var showFileImporter = false
    @State private var totalFaces = 0
    
    @State var project: FaceClusterProject?
    @State var network: FaceNetwork? = nil
    @State var clusterPreviews: [FaceClusterPreview] = []
    @State var facePreviews: [HashableFace] = []
    @State var activeNetwork: String?
    @State var selectedFace: HashableFace? = nil
    
    let columns = [
        GridItem(.adaptive(minimum: 64))
    ]
    
    var body: some View {
        HStack {
            VStack {
                Text("Networks").frame(height: 24)
                if(project != nil) {
                    NavigationStack {
                        List(project!.paths, id: \.self, selection: $selectedNetwork) { path in
                            Text(path)
                        }
                    }
                    .onChange(of: selectedNetwork, {
                        updateNetworkSelection()
                    })
                    .onAppear() {
                        activeNetwork = project?.activePath
                    }
                } else {
                    NavigationStack {
                        List(["A", "B", "C"], id: \.self, selection: $selectedNetwork) { path in
                            Text(path)
                        }
                    }
                }
            }
            
            VStack {
                Button(action: {
                    if(project != nil) {
                        showFileImporter = true
                    }
                }, label: {
                    Image(systemName: "plus.app")
                        .padding(.vertical, 5)
                        .frame(width: 24)
                })
                
                Button(action: {
                    if(project != nil && selectedNetwork != nil) {
                        if(project!.activePath == selectedNetwork) {
                            alertContent = "The active network could not be removed."
                            showAlert = true
                        } else {
                            project!.paths.removeAll(where: { s in
                                return s == selectedNetwork
                            })
                            selectedNetwork = nil
                        }
                    }
                }, label: {
                    Image(systemName: "minus.square")
                        .padding(.vertical, 5)
                        .frame(width: 24)
                })
                
                Button(action: {
                    if(project != nil && selectedNetwork != nil) {
                        project?.updateActiveNetwork(activeUrl: AppDelegate.workspace.appending(component: selectedNetwork!))
                        updateNetworkSelection()
                    }
                }, label: {
                    Image(systemName: "pencil")
                        .padding(.vertical, 5)
                        .frame(width: 24)
                })
            }.padding(.trailing, 24)
            
            VStack {
                Text("Clusters").frame(height: 24)
                if(network != nil && project != nil) {
                    NavigationStack {
                        List(clusterPreviews, id: \.self, selection: $selectedCluster) { c in
                            HStack {
                                if(c.image != nil) {
                                    Image(nsImage: c.image!)
                                }
                                Text(c.cluster.name)
                            }
                        }
                    }
                    .onChange(of: selectedCluster, updateClusterSelection)
                } else {
                    NavigationStack {
                        List([""], id: \.self, selection: $selectedCluster) { path in
                            Text(path)
                        }
                    }
                }
            }.padding(.trailing, 12)
            
            VStack {
                if(selectedCluster != nil) {
                    HStack {
                        ZStack {
                            if(selectedCluster?.image != nil) {
                                Image(nsImage: selectedCluster!.image!)
                            } else {
                                Rectangle()
                            }
                        }
                        .frame(width: 64, height: 64)
                        
                        TextField("Cluster", text: $newName)
                            .frame(width: 128, alignment: .leading)
                            .padding(.trailing, 12)
                            .onSubmit {
                                if(!newName.isEmpty && selectedCluster != nil) {
                                    guard let net = network else {
                                        return
                                    }
                                    let result = net.renameCluster(cluster: selectedCluster!.cluster, newName: newName)
                                    if(!result) {
                                        alertContent = "Failed to rename cluster because the cluster \"" + newName + "\" already exists."
                                        showAlert = true
                                    } else {
                                        updateNetworkSelection()
                                        selectedNetwork = nil
                                    }
                                }
                            }
                    }
                    .frame(alignment: .leading).padding(.top, 12)
                    
                    HStack {
                        Text("Faces: " + String(totalFaces))
                    }
                    
                    Divider().padding(.top, 12)
                    VStack {
                        Text("Face Attributes")
                        Text("Position: ".appending(String(newPos.x) + ", " + String(newPos.y)))
                        Text("Disabled: ".appending(String(newDisabled)))
                    }
                    
                    NavigationStack {
                        List(facePreviews, id: \.self, selection: $selectedFace) { c in
                            HStack {
                                if(c.nsImage != nil) {
                                    Image(nsImage: c.nsImage!)
                                }
                                Text(c.key)
                            }
                            .onChange(of: selectedFace, {
                                newDisabled = selectedFace?.face.disabled ?? false
                                newPos = selectedFace?.face.displayPos ?? DoublePoint(x: 0, y: 0)
                            })
                        }
                    }
                } else if(project == nil) {
                    HStack {
                        Rectangle()
                            .frame(width: 64, height: 64)
                        TextField("Cluster", text: $newName)
                            .frame(width: 224, alignment: .leading)
                            .padding(.trailing, 12)
                    }.frame(alignment: .leading).padding(.top, 12)
                    
                    HStack {
                        Text("Faces: ")
                    }
                    
                    Divider().padding(.top, 12)
                    VStack {
                        Text("Face Attributes")
                        Text("Name:")
                        Text("Position:")
                        Toggle(isOn: $newDisabled, label: {
                            Text("Disabled")
                        })
                    }
                    
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 5) {
                            ForEach([0, 1, 2, 3, 4, 5, 6, 7, 8, 9], id: \.self) { item in
                                Rectangle().frame(width: 64, height: 64)
                            }
                        }
                    }
                }
            }
            .frame(alignment: .top)
            .onChange(of: selectedCluster, {
                
            })
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.directory], onCompletion: { result in
            switch result {
            case .success(let url):
                // Check if selected folder is a network
                if(!FileManager.default.fileExists(atPath: url.appendingPathComponent("data.json").path(percentEncoded: false))) {
                    return
                }
                guard let _ = try? FaceNetwork(url: url) else {
                    return
                }
                guard let p = project else {
                    return
                }
                
                if(p.paths.contains(url.lastPathComponent)) {
                    alertContent = "Failed to add network because there is already a network stored as " + url.lastPathComponent + "."
                    showAlert = true
                } else {
                    p.paths.append(url.lastPathComponent)
                }
            case .failure(let error):
                print(error)
            }
        })
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Alert"), message: Text(alertContent))
        }
        
        Text("Active Network: " + (activeNetwork ?? ""))
    }
    
    private func updateNetworkSelection() {
        selectedCluster = nil
        clusterPreviews = []
        guard let sel = selectedNetwork else { return }
        
        let net: FaceNetwork?
        if(sel != project?.activePath) {
            net = try? FaceNetwork(url: AppDelegate.workspace.appending(component: sel))
        } else {
            net = MediaManager.instance!.getEditFaceNetwork()
        }
        network = net
        
        guard let n = net else {
            return
        }
        for cl in n.clusters.values {
            //print(cl.faces.count)
            clusterPreviews.append(FaceClusterPreview(cluster: cl))
        }
    }
    
    private func updateClusterSelection() {
        selectedFace = nil
        guard let selectedCluster = selectedCluster else {
            return
        }
        facePreviews = selectedCluster.faces
        totalFaces = facePreviews.count
        
        newName = selectedCluster.cluster.name
    }
}

struct HashableFace: Hashable {
    var face: Face
    var key: String
    var nsImage: NSImage?
    
    static func == (lhs: HashableFace, rhs: HashableFace) -> Bool
    {
        return lhs.key == rhs.key
    }
    
    func hash(into hasher: inout Hasher) {
        return hasher.combine(key)
    }
}

struct FaceClusterPreview : Hashable {
    var identifier = UUID()
    static func == (lhs: FaceClusterPreview, rhs: FaceClusterPreview) -> Bool {
        return lhs.cluster.name == rhs.cluster.name
    }
    func hash(into hasher: inout Hasher) {
        return hasher.combine(identifier)
    }
    
    var image: NSImage?
    var cluster: FaceCluster
    var faces: [HashableFace]
    
    init(cluster: FaceCluster) {
        self.cluster = cluster
        self.faces = [HashableFace]()
        for face in cluster.faces {
            faces.append(HashableFace(face: face, key: face.path!.lastPathComponent, nsImage: face.thumbnail == nil ? nil : NSImage(cgImage: face.thumbnail!, size: .zero)))
        }
        
        guard let f = cluster.faces.first?.thumbnail else {
            self.image = nil
            return
        }
        self.image = NSImage(cgImage: f, size: .zero)
    }
}

#Preview {
    ProjectView(project: nil)
}
