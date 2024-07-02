//
//  ConvexHull.swift
//  FaceCluster
//
//  Created by El-Mundo on 25/06/2024.
//

import Foundation

class ConvexHull {
    func polarAngle(_ from: DoublePoint, _ to: DoublePoint) -> Double {
        return atan2(to.y - from.y, to.x - from.x)
    }

    func distance(_ from: DoublePoint, _ to: DoublePoint) -> Double {
        return (from.x - to.x) * (from.x - to.x) + (from.y - to.y) * (from.y - to.y)
    }

    func crossProduct(_ a: DoublePoint, _ b: DoublePoint, _ c: DoublePoint) -> Double {
        return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
    }
    
    /// Update face index in network before calling
    func grahamScan(faces: [Face]) -> [Face] {
        let points: [Face] = faces.sorted {
            let c1: Bool = $0.displayPos.y < $1.displayPos.y
            let c2: Bool = $0.displayPos.y == $1.displayPos.y && $0.displayPos.x < $1.displayPos.x
            return c1 || c2
        }
        let start = points[0]
        let sortedPoints = points[1...].sorted {
            let angle1 = polarAngle(start.displayPos, $0.displayPos)
            let angle2 = polarAngle(start.displayPos, $1.displayPos)
            return angle1 == angle2 ? distance(start.displayPos, $0.displayPos) < distance(start.displayPos, $1.displayPos) : angle1 < angle2
        }

        var hull = [Face]()
        hull.append(start)
        for face in sortedPoints {
            let point = face.displayPos
            while hull.count >= 2 && crossProduct(hull[hull.count - 2].displayPos, hull[hull.count - 1].displayPos, point) <= 0 {
                hull.removeLast()
            }
            hull.append(face)
        }
        return hull
    }
    
    func polygonToTriangles(polygonIndices: [Face], cluster: UInt32) -> [SIMD2<UInt32>] {
        var output = [SIMD2<UInt32>]()
        if(polygonIndices.count < 3) {
            return output
        }
        
        for i in 2..<polygonIndices.count {
            let v1 = SIMD2<UInt32>(UInt32(polygonIndices[0].indexInNet), cluster)
            let v2 = SIMD2<UInt32>(UInt32(polygonIndices[i-1].indexInNet), cluster)
            let v3 = SIMD2<UInt32>(UInt32(polygonIndices[i].indexInNet), cluster)
            output.append(contentsOf: [v1, v2, v3])
        }
        return output
    }
}

