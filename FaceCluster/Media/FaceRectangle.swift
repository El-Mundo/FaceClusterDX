//
//  FaceRectangle.swift
//  FaceCluster
//
//  Created by El-Mundo on 03/06/2024.
//

import Foundation
import Vision

struct DoublePoint: Codable {
    let x: Double
    let y: Double
}

struct DetectedFace: Codable {
    let frameIdentifier: String
    let box: [Double]
    let conf: Double
    let landmarks: [[DoublePoint]]
}

private class CustomFaceDetectRequest: VNDetectFaceLandmarksRequest {
    var identifier: String = ""
}

class FaceRectangle {

    static func detectFacesNative(in cgImage: CGImage, identifier: String) {
        let faceDetectionRequest = CustomFaceDetectRequest { (request, error) in
            let id = (request as! CustomFaceDetectRequest).identifier
            guard let results = request.results as? [VNFaceObservation] else {
                detectComplete(faces: [], identifier: id)
                return
            }

            let faceRectangles = results.map { faceObservation -> DetectedFace in
                let boundingBox = faceObservation.boundingBox
                let conf = Double(faceObservation.confidence)
                
                let box: [Double] = [
                    boundingBox.origin.x,
                    boundingBox.origin.y,
                    boundingBox.size.width,
                    boundingBox.size.height
                ]
                
                let landmarks = faceObservation.landmarks
                let quality = Double(faceObservation.faceCaptureQuality ?? 0)
                let yaw = Double(truncating: faceObservation.yaw ?? 0)
                let pitch = Double(truncating: faceObservation.pitch ?? 0)
                let roll = Double(truncating: faceObservation.roll ?? 0)
                let lms = nativeLandmarkObjectToArray(landmarks, extra: [pitch, yaw, roll, quality], conf: conf)
                
                return DetectedFace(frameIdentifier: id, box: box, conf: conf, landmarks: lms)
            }
            
            detectComplete(faces: faceRectangles, identifier: id, image: cgImage)
        }
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        faceDetectionRequest.identifier = identifier
        
        DispatchQueue.main.async {
            do {
                try handler.perform([faceDetectionRequest])
            } catch {
                print("Failed to perform face detection: \(error)")
                detectComplete(faces: [], identifier: identifier)
            }
        }
    }
    
    
    
    /// Deprecated
    static func detectFacesMTCNN(in cgImage: CGImage, identifier: String) {
        let mtcnn = MTCNN()
        print(Date.now)
        guard let results = mtcnn.detectFaces(image: cgImage) else {
            detectComplete(faces: [], identifier: identifier)
            return
        }
        for face in results {
            print(face[0...4])
        }
    }
    
    
    
    private static func detectComplete(faces: [DetectedFace], identifier: String, image: CGImage?=nil) {
        MediaManager.instance?.addProcessedImage(faces: faces, identifier:  identifier, image: image)
        
        /*if(faces.count < 1) {print("No face"); return}
        let f = faces[0]
        print("Face: \(f[0]), \(f[1]), \(f[2]), \(f[3]), conf \(f[4])")
        if(landmarks.count > 0) {
            print("Landmark confidence: \(landmarks[0][0]), region count: \(landmarks[0].count - 1)")
        }*/
    }
    
    
    
    private static func nativeLandmarkObjectToArray(_ lmk: VNFaceLandmarks2D?, extra: [Double], conf: Double) -> [[DoublePoint]] {
        if(lmk == nil) {return []}
        let landmarks = lmk!
        
        var landmarksArray: [[DoublePoint]] = []
        
        func addLandmarkPoints(_ landmarkRegion: VNFaceLandmarkRegion2D?) {
            guard let points = landmarkRegion?.normalizedPoints else {
                return
            }
            var regionArray = [DoublePoint]()
            for point in points {
                regionArray.append(DoublePoint(x: point.x, y: point.y))
            }
            landmarksArray.append(regionArray)
        }
        
        addLandmarkPoints(landmarks.faceContour)
        addLandmarkPoints(landmarks.leftEye)
        addLandmarkPoints(landmarks.rightEye)
        addLandmarkPoints(landmarks.leftEyebrow)
        addLandmarkPoints(landmarks.rightEyebrow)
        addLandmarkPoints(landmarks.nose)
        addLandmarkPoints(landmarks.noseCrest)
        addLandmarkPoints(landmarks.medianLine)
        addLandmarkPoints(landmarks.outerLips)
        addLandmarkPoints(landmarks.innerLips)
        
        landmarksArray.append([DoublePoint(x: extra[0], y: extra[1]),
                               DoublePoint(x: extra[2], y: extra[3])])
        
        return landmarksArray
    }
    
}
