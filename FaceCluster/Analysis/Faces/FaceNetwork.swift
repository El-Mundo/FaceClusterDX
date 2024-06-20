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
        
}
