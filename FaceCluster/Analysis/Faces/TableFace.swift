//
//  TableFace.swift
//  FaceCluster
//
//  Created by El-Mundo on 26/06/2024.
//

import Foundation
import SwiftUI

struct TableAttribute: Identifiable {
    var content: String
    var key: String
    var id = UUID()
}

struct TableFace: Identifiable {
    let id: UUID
    private let obj: Face
    
    var frame: String
    var path: String
    var confidence: String
    var faceBox: String
    var faceRotation: String
    var cluster: String
    var disabled: Bool
    
    var attributes: [TableAttribute]

    init(face: Face, id: UUID?=nil) {
        if(id == nil) {
            self.id = UUID()
        } else {
            self.id = id!
        }
        
        self.frame = face.detectedAttributes.frameIdentifier
        self.path = "faces/" + (face.path?.lastPathComponent ?? "")
        self.confidence = String(face.detectedAttributes.conf)
        let box = face.detectedAttributes.box
        self.faceBox = "[\(box[0]), \(box[1]), \(box[2]), \(box[3])]"
        let lm = face.detectedAttributes.landmarks[face.detectedAttributes.landmarks.count-1]
        let p1 = lm[0]
        let p2 = lm[1]
        self.faceRotation = "[\(p1.x), \(p1.y), \(p2.x)]"
        self.cluster = face.clusterName ?? "N/A"
        self.obj = face
        self.attributes = [TableAttribute]()
        self.disabled = face.disabled
        
        guard let nwAttributes = face.network?.attributes else {
            return
        }
        
        for a in nwAttributes {
            let key = a.name
            let val = face.attributes[key]
            var content: String
            if(val == nil) {
                content = "Missing"
            } else {
                content = val!.toString()
            }
            self.attributes.append(TableAttribute(content: content, key: a.name))
        }
    }
    
    mutating func requestUpdate(for key: String, newValue: String) -> Bool {
        let updated = obj.attributes[key]?.fromString(string: newValue) ?? false
        if(updated) {
            self.attributes = [TableAttribute]()
            for a in obj.attributes {
                attributes.append(TableAttribute(content: a.value.toString(), key: a.key))
            }
            obj.updateSaveFileAtOriginalLocation()
            return true
        } else {
            return false
        }
    }
    
    mutating func deactivate(toggle: Bool) {
        if(toggle) {
            self.disabled = !self.disabled
        } else {
            self.disabled = true
        }
        updateObjectState()
    }
    
    mutating func activate(forceValue: Bool?=nil) {
        guard let f = forceValue else {
            self.disabled = false
            updateObjectState()
            return
        }
        
        self.disabled = f
        updateObjectState()
    }
    
    private func updateObjectState() {
        obj.disabled = self.disabled
        obj.updateSaveFileAtOriginalLocation()
    }
    
    func requestDeletion() {
        obj.network?.deleteFace(face: obj)
    }
    
}
