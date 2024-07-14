//
//  FaceView.swift
//  FaceCluster
//
//  Created by El-Mundo on 29/06/2024.
//

import Foundation
import SwiftUI

struct FrameView: View {
    var network: FaceNetwork?
    @State var showFileImport: Bool = false
    @State var files: [URL] = []
    @State var frames: [FramePreview] = []
    let imageWidth: CGFloat = 128, columns: Int = 3, spacing: CGFloat = 12
    let pageSize = 60
    @State var hoveredGrid: FramePreview?
    @State var showDeleteAlert: Bool = false
    @State var waitingFlag: Bool = false
    @State var showWaiting: Bool = false
    @State var progressVal: CGFloat = 0
    @State var waitingMSG: String = ""
    @State var pageIndicator = "Page"
    @State var selectedFrame: FramePreview?
    @State var detailViewWidth: CGFloat = 320
    @State var detailViewHeight: CGFloat = 240
    
    var body : some View {
        HStack {
            VStack {
                HStack {
                    Text(pageIndicator).font(.title3).padding(.top, 12)
                    Button("Import JPG/PNG"){
                        showFileImport = true
                    }.fileImporter(isPresented: $showFileImport, allowedContentTypes: [.jpeg, .png], allowsMultipleSelection: true, onCompletion: { r in
                        importFrameImage(r: r)
                    }).padding(.top, 12).padding(.leading, 24).controlSize(.large).buttonStyle(.borderedProminent).tint(.blue)
                    
                    Button() {
                        if(selectedFrame != nil) {
                            showDeleteAlert = true
                        }
                    } label: {
                        Image(systemName: "trash.slash.fill")
                    }.padding(.top, 12).padding(.leading, 24).controlSize(.large).buttonStyle(.borderedProminent).tint(.red)
                }
                
                let col = Array(repeating: GridItem(.fixed(imageWidth), spacing: spacing), count: columns)
                let gridW = imageWidth * CGFloat(columns) + spacing * 6
                ScrollView {
                    LazyVGrid(columns: col, content: {
                        if(network == nil) {
                            ForEach(0..<30) {_ in
                                Rectangle().fill(.green).frame(width: imageWidth, height: imageWidth)
                            }
                        } else {
                            ForEach(frames) {frame in
                                let enlarge = hoveredGrid == frame ? spacing : 0
                                let width = imageWidth + enlarge
                                let height = frame.imageSize.height / frame.imageSize.width * imageWidth + enlarge
                                
                                ZStack {
                                    AsyncImage(url: frame.url) { image in
                                        image.resizable()
                                    } placeholder: {
                                        //Color.black
                                        Text(frame.shortName)//.tint(.white)
                                    }
                                    .frame(width: width, height: height)
                                    
                                    ForEach(frame.framedFaces) {face in
                                        let box = face.face.box
                                        let bw = box[2] * width
                                        let bh = box[3] * height
                                        Rectangle()
                                            .fill(Color.clear)
                                            .stroke(.red, lineWidth: 2)
                                            .frame(width: bw, height: bh)
                                            .position(x: box[0] * width + bw*0.5, y: box[1] * -height + height - bh*0.5)
                                    }
                                }
                                .onTapGesture {
                                    selectedFrame = frame
                                }.onHover(perform: {hover in
                                    if(hover) {
                                        hoveredGrid = frame
                                    } else if(hoveredGrid == frame) {
                                        hoveredGrid = nil
                                    }
                                })
                                .frame(width: width - enlarge, height: height - enlarge)
                            }
                        }
                    }).frame(minWidth: gridW, maxWidth: gridW, minHeight: 320, maxHeight: .infinity).padding([.vertical, .horizontal], 12)
                }.onAppear(perform: getAllJpegNamesInWorkspace)
            }
            FrameDetailedView(frameView: selectedFrame, context: self)
                .frame(minWidth: 320, maxWidth: .infinity, minHeight: 256, maxHeight: .infinity)
                .background(.white)
                .overlay {
                        GeometryReader { geo in
                            let rect = geo.frame(in: .global)
                            Color.clear.onAppear() {
                                detailViewWidth = rect.width
                                detailViewHeight = rect.height
                            }.onChange(of: rect.width) {
                                detailViewWidth = rect.width
                            }.onChange(of: rect.height) {
                                detailViewHeight = rect.height
                            }
                    }
                }
        }
        .onChange(of: waitingFlag, { showWaiting = true })
        .sheet(isPresented: $showWaiting, content: {
            VStack {
                Text(waitingMSG)
                ProgressView(value: progressVal)
            }.frame(width: 200, height: 160)
        })
        .alert(isPresented: $showDeleteAlert) {
            Alert(title: Text(String(localized: "Delete Frame")), message: Text(String(localized: "Confirm to delete \(selectedFrame == nil ? "this frame" : "frame \"\(selectedFrame!.shortName)\"")? This will make all faces attached to this frame removed from the network.")), primaryButton: .destructive(Text("Confirm"), action: deleteSelectedFrame), secondaryButton: .cancel())
        }
    }
    
    private func deleteSelectedFrame() {
        guard let net = network,
            let sf = selectedFrame else {
            return
        }
        net.deleteFrame(frameIdentifier: sf.shortName)
        getAllJpegNamesInWorkspace()
    }
    
    private func getAllJpegNamesInWorkspace() {
        if(network == nil) {
            return
        }
        
        let fileManager = FileManager.default
        do {
            let directoryURL = network!.savedPath.appending(component: "frames/")
            let contents = try fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
            files = contents.filter { $0.pathExtension.lowercased() == "jpg" ||  $0.pathExtension.lowercased() == "jpeg"}.sorted(by: {
                $0.lastPathComponent < $1.lastPathComponent
            })
            loadPage(0)
        } catch {
            print("Error while enumerating files: \(error.localizedDescription)")
            files = []
        }
    }
    
    private func loadPage(_ num: Int) {
        frames.removeAll()
        let start = pageSize * num
        var end = pageSize * (num + 1)
        
        for i in start..<end {
            if(i < files.count) {
                let url = files[i]
                let fi = url.deletingPathExtension().lastPathComponent
                let faces = network!.faces.filter({ $0.detectedAttributes.frameIdentifier == fi })
                frames.append(FramePreview(url: url, shortName: fi, faces: faces))
            } else {
                end = i
                break
            }
        }
        
        pageIndicator = "Showing frames \(start+1)-\(end) (\(files.count) in total)"
    }
    
    private func reloadFramePreview(frame: FramePreview?) {
        guard let sf = frame else { return }
        guard let index = frames.firstIndex(of: sf) else { return }
        let url = sf.url
        let name = sf.shortName
        let faces = network?.faces.filter({ $0.detectedAttributes.frameIdentifier == name }) ?? []
        frames[index] = FramePreview(url: url, shortName: name, faces: faces)
        selectedFrame = frames[index]
    }
    
    private func redetectFacesForSelectedFrame(frame: FramePreview?) {
        guard let sf = frame, let net = network else { return }
        let url = sf.url
        net.deleteFrame(frameIdentifier: sf.shortName, deleteImage: false)
        MediaManager.instance?.importImageSequence(info: $waitingMSG, progress: $progressVal, urls: [ url ], network: net)
        guard let index = frames.firstIndex(of: sf) else { return }
        let name = sf.shortName
        let faces = network?.faces.filter({ $0.detectedAttributes.frameIdentifier == name }) ?? []
        frames[index] = FramePreview(url: url, shortName: name, faces: faces)
        selectedFrame = frames[index]
    }
    
    private func extractSubstring(from input: String) -> String? {
        guard input.count > 1 else {
            print("Input string is too short.")
            return nil
        }
        let start = input.index(input.startIndex, offsetBy: 1)
        guard let end = input.lastIndex(of: "-") else {
            print("Dash not found in the string.")
            return nil
        }
        guard start < end else {
            print("No valid range for substring.")
            return nil
        }
        return String(input[start..<end])
    }
    
    private func importFrameImage(r: Result<[URL], Error>) {
        switch r {
        case .success:
            guard let urls = try? r.get() else {
                break
            }
            guard let net = network else {
                break
            }
            let dir = net.savedPath.appendingPathComponent("Frames/")
            waitingMSG = String(localized: "Importing frame images...")
            waitingFlag.toggle()
            Task {
                var availableUrls: [URL] = []
                for url in urls {
                    let h = url.lastPathComponent.lowercased()
                    if(h.hasSuffix(".jpg") || h.hasPrefix(".jpeg")) {
                        let (s, u) = AppDelegate.secureCopyItem(at: url, to: dir, forceExtension: "jpg")
                        if(s && u != nil) {
                            availableUrls.append(u!)
                        }
                    } else if(h.hasSuffix(".png")) {
                        let (s, u) = ImageUtils.convertPNGToJPG(from: url, to: dir)
                        if(s && u != nil) {
                            availableUrls.append(u!)
                        }
                    }
                }
                MediaManager.instance?.importImageSequence(info: $waitingMSG, progress: $progressVal, urls: availableUrls, network: net)
                showWaiting = false
                getAllJpegNamesInWorkspace()
            }
            break
        case .failure:
            break
        }
    }
    
    struct FramedFace: Identifiable {
        let face: DetectedFace
        let obj: Face
        let id = UUID()
    }
    
    struct FramePreview: Identifiable, Equatable {
        let url: URL
        let shortName: String
        let framedFaces: [FramedFace]
        let imageSize: CGSize
        let id = UUID()
        
        init(url: URL, shortName: String, faces: [Face]) {
            self.url = url
            self.shortName = shortName
            self.imageSize = ImageUtils.getImageSizeFromURL(url) ?? CGSize.zero
            var ff = [FramedFace]()
            for face in faces {
                ff.append(FramedFace(face: face.detectedAttributes, obj: face))
            }
            framedFaces = ff
        }
        
        static func == (lhs: FrameView.FramePreview, rhs: FrameView.FramePreview) -> Bool {
            return lhs.id == rhs.id
        }
        
    }
    
    struct PointIdentifiable: Identifiable {
        let p: DoublePoint
        let split: Bool
        let index: Int
        let id = UUID()
    }
    
    struct FrameDetailedView : View {
        @State var frameView: FramePreview?
        @State private var selectedFace: TableFace.ID?
        @State private var tableFaces: [TableFace] = []
        @State private var hoverFace: TableFace.ID?
        @State var alignmentMode: Int = 0
        @State var alignedFaceImg: CGImage?
        //@State var showLandmarkDebugInfo = true
        
        @State var landmarks: [PointIdentifiable] = []
        
        let tableMinHeight: CGFloat = 240
        let lightRed = Color(red: 1.0, green: 0.6, blue: 0.5)
        
        var context: FrameView
        @State private var sortingOrder = [KeyPathComparator(\TableFace.id)]
        
        var body : some View {
            VStack {
                Text("Frame " + (frameView?.shortName ?? ""))
                
                let width = context.detailViewWidth
                let height = context.detailViewHeight
                let imageSize = frameView?.imageSize ?? CGSize(width: 1, height: 1)
                let ratio = imageSize.height / imageSize.width
                let preferredHeight = width * ratio
                let maxHeight = height - tableMinHeight
                let useHeight = preferredHeight > maxHeight
                let finalWidth = max(0, useHeight ? maxHeight / ratio : width)
                let finalHeight = max(0, useHeight ? maxHeight : preferredHeight)
                
                ZStack {
                    AsyncImage(url: frameView?.url) { image in
                        image.image?.resizable()
                    }
                    
                    ForEach(frameView?.framedFaces ?? []) { face in
                        let box = face.face.box
                        let bw = box[2] * finalWidth
                        let bh = box[3] * finalHeight
                        
                        Rectangle()
                            .fill(Color.clear)
                            .stroke(face.id == selectedFace ? .purple : (face.id == hoverFace ? lightRed : .red), lineWidth: 6)
                            .onHover(perform: { hovered in
                                if(hovered) {
                                    hoverFace = face.id
                                } else if(hoverFace == face.id) {
                                    hoverFace = nil
                                }
                            }).onTapGesture(perform: {
                                if(selectedFace != face.id) {
                                    selectedFace = face.id
                                } else {
                                    selectedFace = nil
                                }
                            })
                            .frame(width: bw, height: bh)
                            .position(x: box[0] * finalWidth + bw*0.5, y: box[1] * -finalHeight + finalHeight - bh*0.5)
                    }
                    
                    if(selectedFace != nil) {
                        let idSel = (frameView?.framedFaces ?? []).filter { $0.id == selectedFace }
                        if let face = idSel.first {
                            let det = face.face
                            let box = det.box
                            let obj = face.obj
                            let bw = box[2] * finalWidth
                            let bh = box[3] * finalHeight
                            Text((obj.path?.deletingPathExtension().lastPathComponent ?? "") + (obj.clusterName == nil ? "" : "(\(obj.clusterName!))")).frame(height: 24).background(.purple).foregroundStyle(.white).position(x: box[0] * finalWidth + bw*0.5, y: box[1] * -finalHeight + finalHeight - bh - 12)
                            
                            if(landmarks.count > 0) {
                                if(alignmentMode == 3) {
                                    ForEach(landmarks) { lmk in
                                        let x = CGFloat(box[0] * finalWidth + lmk.p.x * bw)
                                        let y = CGFloat(box[1] * -finalHeight + finalHeight - lmk.p.y * bh)
                                        Text(lmk.index >= 0 ? String(describing: lmk.index) : "").position(x: x, y: y).foregroundStyle(lmk.split ? .red : .white)
                                    }
                                } else if(alignmentMode == 1) {
                                    Path { p in
                                        landmarks.forEach() { lmk in
                                            let x = CGFloat(box[0] * finalWidth + lmk.p.x * bw)
                                            let y = CGFloat(box[1] * -finalHeight + finalHeight - lmk.p.y * bh)
                                            if(lmk.split) {
                                                p.move(to: CGPoint(x: x, y: y))
                                            } else {
                                                p.addLine(to: CGPoint(x: x, y: y))
                                            }
                                        }
                                    }
                                    .stroke(.white, lineWidth: 1)
                                } else if(alignmentMode == 2) {
                                    let x = CGFloat(box[0] * finalWidth + bw * 0.5)
                                    let y = CGFloat(box[1] * -finalHeight + finalHeight - bh * 0.5)
                                    if(alignedFaceImg != nil) {
                                        let nsImage = NSImage.init(cgImage: alignedFaceImg!, size: .zero)
                                        Image(nsImage: nsImage).resizable().frame(width: bw, height: bh).position(x: x, y: y)
                                    } else {
                                        Rectangle().fill(.black).frame(width: bw, height: bh).position(x: x, y: y).onAppear() {
                                            let fa = FaceAlignment()
                                            if let img = face.obj.getFrameAsImage() {
                                                alignedFaceImg = fa.align(img, face: face.face, size: CGSize(width: 160, height: 160))
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(width: finalWidth, height: finalHeight)
                .onChange(of: frameView) {
                    tableFaces.removeAll()
                    for face in frameView?.framedFaces ?? [] {
                        tableFaces.append(TableFace(face: face.obj, id: face.id))
                    }
                    selectedFace = nil
                    hoverFace = nil
                }
                .onChange(of: selectedFace) {
                    landmarks.removeAll()
                    if(selectedFace != nil) {
                        let idSel = (frameView?.framedFaces ?? []).filter { $0.id == selectedFace }
                        if let face = idSel.first {
                            var i = 0, j = 0
                            let landmks = face.face.landmarks
                            
                            for p in landmks {
                                i += 1
                                if(p.count < 1 || i == landmks.count) {
                                    continue
                                }
                                var split = true
                                for pp in p {
                                    landmarks.append(PointIdentifiable(p: pp, split: split, index: j))
                                    j += 1
                                    split = false
                                }
                                if(i > 1) {
                                    landmarks.append(PointIdentifiable(p: p.first!, split: false, index: -1))
                                }
                            }
                            let fa = FaceAlignment()
                            if let img = face.obj.getFrameAsImage() {
                                alignedFaceImg = fa.align(img, face: face.face, size: CGSize(width: 160, height: 160))
                            }
                        }
                    }
                }
                
                HStack {
                    Text("Aligning Display")
                    Picker("", selection: $alignmentMode) {
                        Text("None").tag(0 as Int)
                        Text("Landmark Lines").tag(1 as Int)
                        Text("Landmark Indices").tag(3 as Int)
                        Text("Aligned Image").tag(2 as Int)
                    }.frame(width: 120)
                    
                    Button() {
                        context.redetectFacesForSelectedFrame(frame: frameView)
                    } label: {
                        Label("Redetect", systemImage: "faceid")
                    }
                    .padding(.leading, 48)
                    
                    Button("Delete Face") {
                        guard let fin = tableFaces.firstIndex(where: { return $0.id == selectedFace }) else { return }
                        let f = tableFaces[fin]
                        f.requestDeletion()
                        if(selectedFace == hoverFace) {
                            hoverFace = nil
                        }
                        selectedFace = nil
                        tableFaces.remove(at: fin)
                        context.reloadFramePreview(frame: frameView)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .padding(.leading, 12)
                }
                
                Table(tableFaces, selection: $selectedFace, sortOrder: $sortingOrder) {
                    //TableColumn(FA_PreservedFields[5], value: \.frame)
                    TableColumn(FA_PreservedFields[0], value: \.faceBox)
                    TableColumn(FA_PreservedFields[1], value: \.confidence)
                    TableColumn(FA_PreservedFields[3], value: \.faceRotation)
                    TableColumn(FA_PreservedFields[6], value: \.path)
                    TableColumn(FA_PreservedFields[4], value: \.cluster)
                }.onChange(of: context.selectedFrame, {
                    frameView = context.selectedFrame
                })
            }
        }
    }
}

#Preview {
    FrameView()
    //Text("Hello")
}
