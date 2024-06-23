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
    
    init(faces: [Face] = [Face](), savedPath: URL, media: MediaAttributes?=nil) {
        self.faces = faces
        self.savedPath = savedPath
        self.media = media
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
                print("Failed to save data in binary format: \(error)")
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
                print(error)
                return false
            }
        } else {
            print("Cannot update face because it is not part")
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
        
        if(!(GPUManager.instance?.useCPU ?? false)) {
            var buffer0: MTLBuffer?
            if(faceMapBuffer == nil) {
                guard let buffer = GPUManager.instance!.metalDevice?.makeBuffer(length: MemoryLayout<SIMD2<Float>>.stride * n, options:[MTLResourceOptions.storageModeShared]) else { return }
                buffer0 = buffer
                let points: UnsafeMutablePointer<SIMD2<Float>> = UnsafeMutableRawPointer(buffer0!.contents()).bindMemory(to:SIMD2<Float>.self, capacity: n)
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
                fatalError("Failed to create command buffer or encoder")
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
        
        print("Time lapse", Date.now.timeIntervalSince(time))
    }
    
    private func arrangeClusters() {
        clusters.removeAll()
        
        for face in faces {
            if(face.clusterIndex >= 0) {
                let key = "#\(face.clusterIndex)"
                let c = clusters[key] ?? FaceCluster(faces: [], name: key)
                c.faces.append(face)
                clusters.updateValue(c, forKey: key)
            }
        }
    }
    
    func writeDisplayPointsToBuffer(ptr: UnsafeMutablePointer<SIMD2<Float>>, n: Int) {
        for i in 0..<n {
            let face = faces[i]
            let dp = face.displayPos
            let fp = SIMD2<Float>(Float(dp.x), Float(dp.y))
            ptr[i] = fp
        }
    }
        
}
