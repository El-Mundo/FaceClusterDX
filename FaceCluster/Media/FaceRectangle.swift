//
//  FaceRectangle.swift
//  FaceCluster
//
//  Created by El-Mundo on 03/06/2024.
//

import Foundation
import Vision

class FaceRectangle {
    
    static let faceDetectionRequest = VNDetectFaceRectanglesRequest { (request, error) in
        guard let results = request.results as? [VNFaceObservation] else {
            detectComplete(faces: [])
            return
        }

        let faceRectangles = results.map { faceObservation -> [Double] in
            let boundingBox = faceObservation.boundingBox
            let conf = Double(faceObservation.confidence)
            
            return [
                boundingBox.origin.x,
                boundingBox.origin.y,
                boundingBox.size.width,
                boundingBox.size.height,
                conf
            ]
        }
        
        detectComplete(faces: faceRectangles)
    }

    static func detectFacesNative(in cgImage: CGImage) {
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        DispatchQueue.main.async {
            do {
                try handler.perform([faceDetectionRequest])
            } catch {
                print("Failed to perform face detection: \(error)")
                detectComplete(faces: [])
            }
        }
    }
    
    private static func detectComplete(faces: [[Double]]) {
        MediaManager.instance?.addProcessedImage()
        
        if(faces.count < 1) {print("No face"); return}
        let f = faces[0]
        print("Face: \(f[0]), \(f[1]), \(f[2]), \(f[3]), conf \(f[4])")
    }
    
}
