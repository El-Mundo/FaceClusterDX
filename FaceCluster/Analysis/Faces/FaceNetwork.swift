//
//  FaceNetwork.swift
//  FaceCluster
//
//  Created by El-Mundo on 17/06/2024.
//

import Foundation
import AppKit

class FaceNetwork {
    var faces = [Face]()
    var savedPath: URL
    var media: MediaAttributes?
    
    var layoutKey = "Position"
    var textures: [MTLTexture] = []
    var clusters = [String: FaceCluster]()
    
    var attributes: [SavableAttribute]
    
    init(faces: [Face] = [Face](), savedPath: URL, media: MediaAttributes?=nil, attributes: [SavableAttribute]) {
        self.faces = faces
        self.savedPath = savedPath
        self.media = media
        self.attributes = attributes
    }
    
    public func saveMetadata() {
        let target = savedPath.appending(path: "meta.json")
        do {
            let data = try JSONEncoder().encode(media)
            try data.write(to: target)
        } catch {
            print("Metadata ", error)
        }
    }
    
    /// When deleting a face box, make sure to re-index saved images
    public func saveAll() {
        let directory = savedPath.appending(path: "faces/")
        var total = 0
        var fileURL: URL
        let fm = FileManager.default
        
        for face in faces {
            var loc = 0
            do {
                let frame = face.detectedAttributes.frameIdentifier
                fileURL = directory.appending(path: "f\(frame)-\(loc).json")
                while fm.fileExists(atPath: fileURL.path(percentEncoded: false)) {
                    loc += 1
                    fileURL = directory.appending(path: "f\(frame)-\(loc).json")
                }
                try face.save(fileURL: fileURL)
                total += 1
            } catch {
                let info = String("Failed to save data in json format: ").appending(String(describing: error))
                print(info)
            }
        }
        
        print("\(total) files saved.")
    }
    
    func requestPositionUpdate(face: Face, updatedPosition: DoublePoint) {
        let a = face.attributes
        let facePoint = FacePoint(updatedPosition, for: layoutKey)
        if(!a.keys.contains(layoutKey)) {
            let _ = face.createAttribute(for: FacePoint.self, key: layoutKey, value: facePoint)
        } else {
            face.forceUpdateAttribute(for: FacePoint.self, key: layoutKey, value: facePoint)
        }
        //let s = saveSingle(face: face)
    }
    
    func requestUpdateFiles(updatedFace: Face) -> Bool {
        if(faces.contains(where: {$0 === updatedFace})) {
            do {
                guard let path = updatedFace.path else { return false }
                try updatedFace.save(fileURL: path)
                return true
            } catch {
                let msg = String(localized: "Failed to save face update for ").appending(updatedFace.path?.lastPathComponent ?? "").appending("\n\(error)")
                print(error)
                networkEditorInstance?.console += msg + "\n"
                return false
            }
        } else {
            let info = String(localized: "Cannot update face because it is not part of the active network.")
            print(info)
            networkEditorInstance?.console += info + "\n"
            return false
        }
    }
    
    /// For first save
    public func saveSingle(face: Face, thumbnail: CGImage?=nil) -> Bool {
        if(thumbnail != nil) {
            face.thumbnail = thumbnail
            face.texture = GPUManager.instance?.createTexture(from: thumbnail!)
        }
        
        let directory = savedPath.appending(path: "faces/")
        var index = 0
        let frame = face.detectedAttributes.frameIdentifier
        var fileURL = directory.appending(path: "f\(frame)-0.json")
        let fm = FileManager.default
        
        do {
            while fm.fileExists(atPath: fileURL.path(percentEncoded: false)) {
                index += 1
                fileURL = directory.appending(path: "f\(frame)-\(index).json")
            }
            try face.save(fileURL: fileURL)
            return true
        } catch {
            return false
        }
    }
    
    func generateClusters(faceMapBuffer: MTLBuffer?, distanceBuffer: MTLBuffer?, _ maxDistance: Float) {
        let n = faces.count
        if(n < 2) {
            return
        } else if(n == 2) {
            let f1 = faces[0].displayPos
            let f2 = faces[1].displayPos
            let dis = distance(SIMD2<Double>(f1.x, f1.y), SIMD2<Double>(f2.x, f2.y))
            
            if(Float(dis) < maxDistance) {
                faces[0].clusterIndex = 0
                faces[1].clusterIndex = 0
                self.arrangeClusters()
            }
            return
        }
        
        let half = (n % 2 == 0) ? (n / 2) : ((n + 1) / 2)
        let threadCount = half * n
        let time = Date.now
        var pairs = [PairedDistance]()
        
        networkEditorInstance?.console += String(localized: "Calculating face distances...\n")
        networkEditorInstance?.context?.freezeNetworkView = true
        
        if(!(GPUManager.instance?.useCPU ?? false)) {
            var buffer0: MTLBuffer?
            if(faceMapBuffer == nil) {
                guard let buffer = GPUManager.instance!.metalDevice?.makeBuffer(length: MemoryLayout<FaceMap>.stride * n, options:[MTLResourceOptions.storageModeShared]) else { return }
                buffer0 = buffer
                let points: UnsafeMutablePointer<FaceMap> = UnsafeMutableRawPointer(buffer0!.contents()).bindMemory(to:FaceMap.self, capacity: n)
                writeDisplayPointsToBuffer(ptr: points, n: n)
            } else {
                //print("Reading buffer from render pipeline")
                buffer0 = faceMapBuffer
            }
            
            var buffer1: MTLBuffer
            if(distanceBuffer == nil) {
                guard let buffer = GPUManager.instance!.metalDevice?.makeBuffer(length: MemoryLayout<PairedDistance>.stride * threadCount, options:[MTLResourceOptions.storageModeShared]) else { return }
                buffer1 = buffer
            } else {
                buffer1 = distanceBuffer!
            }
            let threshold: Float = maxDistance
            let count: UInt = UInt(n)
            
            guard let commandQueue = GPUManager.instance?.metalCommandQueue,
                  let cps = GPUManager.instance?.computeClusterPipeline,
                  let commandBuffer = commandQueue.makeCommandBuffer(),
                  let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
                fatalError(String(localized: "Failed to create command buffer or encoder"))
            }
            
            computeEncoder.setComputePipelineState(cps)
            computeEncoder.setBuffer(buffer0, offset: 0, index: 0)
            computeEncoder.setBuffer(buffer1, offset: 0, index: 1)
            computeEncoder.setBytes([threshold], length: MemoryLayout<Float>.size, index: 2)
            computeEncoder.setBytes([count], length: MemoryLayout<UInt>.size, index: 3)
            let gridSize = MTLSize(width: n, height: half, depth: 1)
            let threadgroupSize = MTLSize(width: 1, height: 1, depth: 1)
            computeEncoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadgroupSize)
            
            computeEncoder.endEncoding()
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            
            let distPairs: UnsafeMutablePointer<PairedDistance> = UnsafeMutableRawPointer(buffer1.contents()).bindMemory(to:PairedDistance.self, capacity:threadCount)
            for i in 0..<threadCount {
                //print("\(i):", distPairs[i])
                pairs.append(distPairs[i])
            }
        } else {
            for y in 0..<faces.count {
                for x in y+1..<faces.count {
                    if(faces[x].disabled || faces[y].disabled) {
                        pairs.append(PairedDistance(paired: false, index: SIMD2<UInt32>(UInt32(x), UInt32(y))))
                        continue
                    }
                    let f1 = faces[x].displayPos
                    let f2 = faces[y].displayPos
                    let dis = distance(SIMD2<Double>(f1.x, f1.y), SIMD2<Double>(f2.x, f2.y))
                    pairs.append(PairedDistance(paired: Float(dis) < maxDistance, index: SIMD2<UInt32>(UInt32(x), UInt32(y))))
                }
            }
        }
        
        pairs = pairs.sorted {
            $0.index.x < $1.index.x
        }
        
        for pair in pairs {
            if(pair.paired) {
                let x = Int(pair.index.x)
                let y = Int(pair.index.y)
                var xi = faces[x].clusterIndex
                var yi = faces[y].clusterIndex
                xi = xi > -1 ? xi : x
                yi = yi > -1 ? yi : y
                let index = min(xi, yi)
                faces[x].clusterIndex = index
                faces[y].clusterIndex = index
            }
        }
        
        self.arrangeClusters()
        
        let t = Date.now.timeIntervalSince(time)
        print("Time lapse", t)
        networkEditorInstance?.context?.freezeNetworkView = false
        networkEditorInstance?.console += String(localized: "Clustered faces, time lapse:").appending(String(describing: t)) + "\n\n"
    }
    
    private func arrangeClusters() {
        clusters.removeAll()
        
        for face in faces {
            if(face.clusterIndex >= 0) {
                let key = "#\(face.clusterIndex)"
                let c = clusters[key] ?? FaceCluster(faces: [], name: key)
                face.clusterName = key
                c.faces.append(face)
                clusters.updateValue(c, forKey: key)
            } else {
                face.clusterName = nil
            }
            
            face.clusterIndex = -1
        }
        
        saveClusters()
    }
    
    private func saveClusters() {
        FaceClusterSavable.container = self
        var ss = [FaceClusterSavable]()
        for cluster in clusters.values {
            let s = FaceClusterSavable(cluster: cluster)
            ss.append(s)
        }
        do {
            let data = try JSONEncoder().encode(ss)
            try data.write(to: savedPath.appending(path: "clusters.json"))
        } catch {
            networkEditorInstance?.console += String(localized: "Failed to save clusters.\n").appending("\(error)") + "\n\n"
            print(error)
        }
    }
    
    func forceAppendAttribute(key: String, type: AttributeType, dimensions: Int?) {
        if(attributes.contains(where: {$0.name == key})) {
            attributes.removeAll(where: {$0.name == key})
        }
        if(type == .Vector || type == .IntVector) {
            attributes.append(SavableAttribute(name: key, type: type, dimensions: dimensions))
        } else {
            attributes.append(SavableAttribute(name: key, type: type, dimensions: nil))
        }
    }
    
    func getUniqueKeyName(name: String) -> String {
        if(attributes.contains(where: {$0.name == name})) {
            var na = name + "_0"
            var n = 0
            while(attributes.contains(where: {$0.name == na})) {
                n += 1
                na = name + "_" + String(n)
            }
            return na
        } else {
            return name
        }
    }
    
    func writeDisplayPointsToBuffer(ptr: UnsafeMutablePointer<FaceMap>, n: Int) {
        for i in 0..<n {
            let face = faces[i]
            let dp = face.displayPos
            let fp = SIMD2<Float>(Float(dp.x), Float(dp.y))
            let faceMap = FaceMap(pos: fp, disabled: face.disabled)
            ptr[i] = faceMap
        }
    }
    
    func attributeVectorsToDoubleArray(name: String) -> ([[Double]]?, [Int], Int, String) {
        guard let att = attributes.first(where: { name == $0.name }) else {
            return (nil, [], -2, String(localized: "Invalid input attribute"))
        }
        if(att.type != .Vector) {
            return (nil, [], -3, String(localized: "Input attribute must a vector"))
        }
        var d = [[Double]]()
        var i = [Int]()
        var corruptedData = 0
        
        for j in 0..<faces.count {
            let face = faces[j]
            guard let a = face.attributes[att.name] as? FaceVector else {
                corruptedData += 1
                continue
            }
            d.append(a.value)
            i.append(j)
        }
        
        return (d, i, corruptedData, "")
    }
       
    func getVectorDimension(name: String) -> Int {
        guard let att = attributes.first(where: { name == $0.name }),
              let dim = att.dimensions else {
            return -1
        }
        if(att.type != .Vector && att.type != .IntVector) {
            return -1
        }
        
        return dim
    }
}

extension FaceNetwork {
    func generateConvexHull(usePolygon: Bool) -> [SIMD2<UInt32>] {
        self.updateFaceIndices()
        var vertices = [SIMD2<UInt32>]()
        var cIndex: UInt32 = 0
        for cluster in clusters.values {
            if(cluster.faces.count >= (usePolygon ? 3 : 2)) {
                if(usePolygon) {
                    vertices.append(contentsOf: cluster.generateConvexHull(indexInNet: cIndex))
                }else {
                    vertices.append(contentsOf: cluster.generateLines(indexInNet: cIndex))
                }
                cIndex += 1
            }
        }
        return vertices
    }
    
    func updateFaceIndices() {
        var i = 0
        for face in faces {
            face.indexInNet = i
            i += 1
        }
    }
    
    func getAlignedImageArray() -> [(CGImage?, Face)] {
        var images = [(CGImage?, Face)]()
        let fa = FaceAlignment()
        if(faces.count < 1) {
            return []
        }
        
        let sortedFaces = faces.sorted(by: {
            $0.detectedAttributes.frameIdentifier < $1.detectedAttributes.frameIdentifier
        })
        var frameIdentifier = sortedFaces[0].detectedAttributes.frameIdentifier
        var frameImage = sortedFaces[0].getFrameAsImage()
        
        for face in sortedFaces {
            let id = face.detectedAttributes.frameIdentifier
            if(id != frameIdentifier) {
                frameImage = face.getFrameAsImage()
                frameIdentifier = id
            }
            
            if(face.disabled || frameImage == nil) {
                continue
            }
            images.append((fa.align(frameImage!, face: face.detectedAttributes, size: CGSize(width: 160, height: 160)), face))
        }
        
        return images
    }
}

extension FaceNetwork {
    func deleteFace(face: Face) {
        guard let ix = faces.firstIndex(where: { return $0.path == face.path }) else {
            return
        }
        faces.remove(at: ix)
        face.destroySelf()
    }
    
    func deleteFrame(frameIdentifier: String, deleteImage: Bool=true) {
        let face = faces.filter({ return $0.detectedAttributes.frameIdentifier == frameIdentifier })
        for f in face {
            deleteFace(face: f)
        }
        if(deleteImage) {
            let path1 = savedPath.appending(path: "Frames/\(frameIdentifier).jpg")
            let path2 = savedPath.appending(path: "Frames/\(frameIdentifier).jpeg")
            if(FileManager.default.fileExists(atPath: path1.path(percentEncoded: false))) {
                try? FileManager.default.removeItem(at: path1)
            } else if(FileManager.default.fileExists(atPath: path2.path(percentEncoded: false))) {
                try? FileManager.default.removeItem(at: path2)
            }
        }
    }
}
