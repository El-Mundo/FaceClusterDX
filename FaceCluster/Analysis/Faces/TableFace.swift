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
        
        for a in face.attributes {
            attributes.append(TableAttribute(content: a.value.toString(), key: a.key))
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
}