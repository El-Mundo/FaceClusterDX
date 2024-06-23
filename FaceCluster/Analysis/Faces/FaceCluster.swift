//
//  FaceCluster.swift
//  FaceCluster
//
//  Created by El-Mundo on 23/06/2024.
//

import Foundation

class FaceCluster {
    var faces: [Face]
    var name: String
    
    init(faces: [Face], name: String) {
        self.faces = faces
        self.name = name
    }
}
