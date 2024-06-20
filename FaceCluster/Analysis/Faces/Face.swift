//
//  Face.swift
//  FaceCluster
//
//  Created by El-Mundo on 17/06/2024.
//

import Foundation
import AppKit

class Face: Codable {
    let detectedAttributes: DetectedFace
    var thumbnail: CGImage? = nil
    var attributes = [String : any FaceAttribute]()
    
    var network: FaceNetwork? = nil
    var texture: MTLTexture? = nil
    var textureId: Int = -8
    var displayPos: DoublePoint = DoublePoint(x: 0, y: 0)
    
    enum CodingKeys: String, CodingKey {
        case detectedAttributes
        case attributes
    }
    
    init(detectedAttributes: DetectedFace, network: FaceNetwork?) {
        self.detectedAttributes = detectedAttributes
        self.network = network
    }
    
    func save(fileURL: URL) throws {
        //let data = try! NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: false)
        let data = try! JSONEncoder().encode(self)
        try data.write(to: fileURL)
        //print("Data was saved in \(fileURL).")
        
        if(self.thumbnail != nil) {
            let _ = ImageUtils.saveImageAsJPG(self.thumbnail!, at: fileURL.deletingPathExtension().appendingPathExtension(".jpg"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(detectedAttributes, forKey: .detectedAttributes)
        var ac = c.nestedUnkeyedContainer(forKey: .attributes)
        for a in attributes.values {
            if let point = a as? FacePoint {
                try ac.encode(point)
            } else if let vector = a as? FaceVector {
                try ac.encode(vector)
            } else if let intVec = a as? FaceIntegerVector {
                try ac.encode(intVec)
            } else if let dec = a as? FaceDecimal {
                try ac.encode(dec)
            } else if let integer = a as? FaceInteger {
                try ac.encode(integer)
            } else if let st = a as? FaceString {
                try ac.encode(st)
            }
        }
    }
    
    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.detectedAttributes = try c.decode(DetectedFace.self, forKey: .detectedAttributes)
        var ac = try c.nestedUnkeyedContainer(forKey: .attributes)
        self.attributes = [String : any FaceAttribute]()
        while(!ac.isAtEnd) {
            if let point = try? ac.decode(FacePoint.self) {
                self.attributes.updateValue(point, forKey: point.key)
            } else if let vector = try? ac.decode(FaceVector.self) {
                self.attributes.updateValue(vector, forKey: vector.key)
            } else if let intVec = try? ac.decode(FaceIntegerVector.self) {
                self.attributes.updateValue(intVec, forKey: intVec.key)
            } else if let dec = try? ac.decode(FaceDecimal.self) {
                self.attributes.updateValue(dec, forKey: dec.key)
            } else if let integer = try? ac.decode(FaceInteger.self) {
                self.attributes.updateValue(integer, forKey: integer.key)
            } else if let st = try? ac.decode(FaceString.self) {
                self.attributes.updateValue(st, forKey: st.key)
            }
        }
    }
    
    func generateDefaultPosition(index: Int) {
        let time = (network?.media?.interval ?? 1) * Double(index)
        //let angle = Double.random(in: -Double.pi...Double.pi)
        let angle = Double(index) * Double.pi / 6
        let x = (cos(angle) * time + detectedAttributes.box[0] - 0.5) * 0.5
        let y = (sin(angle) * time + detectedAttributes.box[1] - 0.5) * 0.5

        self.attributes.updateValue(FacePoint(DoublePoint(x: x, y: y), for: "Position"), forKey: "Position")
    }
    
    /*func getSavable() -> SavableFace {
        return SavableFace(detectedAttributes: self.detectedAttributes, attributes: self.attributes)
    }*/
    
}

/*class SavableFace: NSSecureCoding {
    static var supportsSecureCoding: Bool { return true }
    
    let detectedAttributes: DetectedFace? = nil
    var attributes: [any FaceAttribute] = []
    
    func encode(with coder: NSCoder) {
        
    }
    required init?(coder: NSCoder) {
        
    }

}*/
