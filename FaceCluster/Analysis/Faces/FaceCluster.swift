//
//  FaceCluster.swift
//  FaceCluster
//
//  Created by El-Mundo on 23/06/2024.
//

import Foundation
import UniformTypeIdentifiers

class FaceCluster {
    var faces: [Face]
    var name: String
    
    init(faces: [Face], name: String) {
        self.faces = faces
        self.name = name
    }
    
    func generateConvexHull(indexInNet: UInt32) -> [SIMD2<UInt32>] {
        let con = ConvexHull()
        let hull = con.grahamScan(faces: faces)
        return con.polygonToTriangles(polygonIndices: hull, cluster: indexInNet)
    }
    
    func generateLines(indexInNet: UInt32) -> [SIMD2<UInt32>] {
        if(faces.count < 2) {
            return []
        }
        var vertices = [SIMD2<UInt32>]()
        /*let sorted = faces.sorted {
            $0.displayPos.x < $1.displayPos.x
        }*/
        for i in 0..<faces.count {
            for j in (i+1)..<faces.count {
                let v1 = SIMD2<UInt32>(UInt32(faces[i].indexInNet), indexInNet)
                let v2 = SIMD2<UInt32>(UInt32(faces[j].indexInNet), indexInNet)
                vertices.append(contentsOf: [v1, v2, v1, v2, v1, v2, v1, v2])
            }
        }
        return vertices
    }
    
}

struct FaceClusterSavable: Codable {
    let clt: FaceCluster
    static var container: FaceNetwork?
    
    enum CodingKeys: String, CodingKey {
        case faces
        case name
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(clt.name, forKey: .name)
        var paths = [String]()
        for face in clt.faces {
            paths.append(face.path!.deletingPathExtension().lastPathComponent)
        }
        try c.encode(paths, forKey: .faces)
    }
    
    init(cluster: FaceCluster) {
        self.clt = cluster
    }
    
    init(from decoder: Decoder) throws {
        guard let f = FaceClusterSavable.container else {
            fatalError(String(localized: "Load a network before reading clusters"))
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let name = try c.decode(String.self, forKey: .name)
        let out = FaceCluster(faces: [], name: name)
        let facePaths = try c.decode([String].self, forKey: .faces)
        let faces = f.faces
        for face in faces {
            for pth in facePaths {
                if(face.path!.deletingLastPathComponent().lastPathComponent.elementsEqual(pth)) {
                    out.faces.append(face)
                    break
                }
            }
        }
        self.clt = out
    }

}
