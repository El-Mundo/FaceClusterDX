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
    var disabled: Bool
    
    var network: FaceNetwork? = nil
    var texture: MTLTexture? = nil
    var path: URL?
    
    /// Temporray variable
    var textureId: Int = -8
    var displayPos: DoublePoint = DoublePoint(x: 0, y: 0)
    
    /// Temporary variable for arrange clusters in the network
    var clusterIndex: Int = -1
    
    /// Call update in network before referencing
    var indexInNet: Int = -1
    var clusterName: String?
    
    enum CodingKeys: String, CodingKey {
        case detectedAttributes
        case attributes
        case disabled
    }
    
    init(detectedAttributes: DetectedFace, network: FaceNetwork?) {
        self.detectedAttributes = detectedAttributes
        self.network = network
        self.disabled = false
    }
    
    func reload(network: FaceNetwork, url: URL) {
        self.network = network
        let fm = FileManager.default
        var thumbnailPath = url.deletingPathExtension().appendingPathExtension(".jpg")
        if(!fm.fileExists(atPath: thumbnailPath.path(percentEncoded: false))) {
            thumbnailPath = url.deletingPathExtension().appendingPathExtension(".jpeg")
        }
        
        self.thumbnail = ImageUtils.loadJPG(url: thumbnailPath)
        self.reloadTexture()
        self.path = url
    }
    
    func assignClusterName(name: String) {
        self.clusterName = name
    }
    
    func save(fileURL: URL) throws {
        //let data = try! NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: false)
        let data = try! JSONEncoder().encode(self)
        try data.write(to: fileURL)
        self.path = fileURL
        //print("Data was saved in \(fileURL).")
        
        if(self.thumbnail != nil) {
            let _ = ImageUtils.saveImageAsJPG(self.thumbnail!, at: fileURL.deletingPathExtension().appendingPathExtension(".jpg"))
        }
    }
    
    func updateSaveFileAtOriginalLocation() {
        do {
            try save(fileURL: self.path!)
        } catch {
            print(error)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(detectedAttributes, forKey: .detectedAttributes)
        var ac = c.nestedUnkeyedContainer(forKey: .attributes)
        try c.encode(disabled, forKey: .disabled)
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
    
    func setDisabled(disabled: Bool) {
        self.disabled = disabled
    }
    
    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.detectedAttributes = try c.decode(DetectedFace.self, forKey: .detectedAttributes)
        var ac = try c.nestedUnkeyedContainer(forKey: .attributes)
        self.attributes = [String : any FaceAttribute]()
        self.disabled = try c.decode(Bool.self, forKey: .disabled)
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
        let angle = Double(index) * Double.pi / 12
        let x = (cos(angle) * time + detectedAttributes.box[0] - 0.5) * 0.25
        let y = (sin(angle) * time + detectedAttributes.box[1] - 0.5) * 0.25

        self.attributes.updateValue(FacePoint(DoublePoint(x: x, y: y), for: "Position"), forKey: "Position")
    }
    
    /*func getSavable() -> SavableFace {
        return SavableFace(detectedAttributes: self.detectedAttributes, attributes: self.attributes)
    }*/
    
    func createDescription() -> [String] {
        let frame = detectedAttributes.frameIdentifier
        guard var pathShort = path?.lastPathComponent else {
            return ["Frame: \(frame)", "Saved at:"]
        }
        //pathShort = pathShort.count > 36 ? "...".appending(String(pathShort.suffix(35))) : pathShort
        pathShort = "../faces/" + pathShort
        let roundedX = round(displayPos.x * 100) / 100
        let roundedY = round(displayPos.y * 100) / 100
        return ["Frame: \(frame)", "Saved at: \(pathShort)".replacingOccurrences(of: " ", with: "_"), "Attribute: \(network?.layoutKey ?? "")", "Value: \(roundedX), \(roundedY)", "Cluster: \(clusterName ?? "N/A")"]
    }
    
    func createAttribute<T: FaceAttribute>(for: T.Type, key: String, value: any FaceAttribute) -> Bool {
        if let t = value as? T {
            attributes.updateValue(t, forKey: key)
            return true
        } else {
            return false
        }
    }
    
    func forceUpdateAttribute<T: FaceAttribute>(for: T.Type, key: String, value: any FaceAttribute) {
        attributes.updateValue(value, forKey: key)
    }
    
    func forceUpdateAttribute(key: String, value: any FaceAttribute) {
        attributes.updateValue(value, forKey: key)
    }
    
    func getFullSizeImage() -> CGImage? {
        guard let framePath = network?.savedPath.appending(path: "frames/\(detectedAttributes.frameIdentifier).jpg")else {
            return nil
        }
        
        if let img = ImageUtils.loadJPG(url: framePath) {
            return ImageUtils.cropCGImageNormalised(img, normalisedBox: detectedAttributes.box)
        } else {
            print("Frame image \(detectedAttributes.frameIdentifier).jpg lost, returning thumbnail...")
            return self.thumbnail
        }
    }
    
    func getFrameAsImage() -> CGImage? {
        guard let framePath = network?.savedPath.appending(path: "frames/\(detectedAttributes.frameIdentifier).jpg")else {
            return nil
        }
        
        return ImageUtils.loadJPG(url: framePath)
    }
    
}

extension Face {
    func reloadTexture() {
        guard let t = thumbnail else { return }
        texture = GPUManager.instance?.createTexture(from: t)
    }
    
    func updateDisplayPosition(newPosition: DoublePoint) {
        self.displayPos = newPosition
        network?.requestPositionUpdate(face: self, updatedPosition: newPosition)
    }
    
    func destroySelf() {
        guard let path = self.path else {
            return
        }
        
        let thumb = path.deletingPathExtension().appendingPathExtension(".jpg")
        do {
            if(thumbnail != nil) {
                try FileManager.default.removeItem(at: thumb)
            }
            try FileManager.default.removeItem(at: path)
        } catch {
            print(error)
        }
    }
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
