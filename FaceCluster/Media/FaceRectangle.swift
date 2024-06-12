//
//  FaceRectangle.swift
//  FaceCluster
//
//  Created by El-Mundo on 03/06/2024.
//

import Foundation
import Vision

class FaceRectangle {
    
    static let faceDetectionRequest = VNDetectFaceLandmarksRequest { (request, error) in
        guard let results = request.results as? [VNFaceObservation] else {
            detectComplete(faces: [], landmarks: [])
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
        
        let faceLandmarks = results.map { faceObservation -> [[Double]] in
            let landmarks = faceObservation.landmarks
            let conf = Double(faceObservation.confidence)
            
            return nativeLandmarkObjectToArray(landmarks, conf: conf)
        }
        
        detectComplete(faces: faceRectangles, landmarks: faceLandmarks)
    }
    
    
    
    static func detectFacesMTCNN(in cgImage: CGImage) {
        let mtcnn = MTCNN()
        mtcnn.detectFaces(image: cgImage)
    }
    
    

    static func detectFacesNative(in cgImage: CGImage) {
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        DispatchQueue.main.async {
            do {
                try handler.perform([faceDetectionRequest])
            } catch {
                print("Failed to perform face detection: \(error)")
                detectComplete(faces: [], landmarks: [])
            }
        }
    }
    
    
    
    private static func detectComplete(faces: [[Double]], landmarks: [[[Double]]]) {
        MediaManager.instance?.addProcessedImage()
        
        /*if(faces.count < 1) {print("No face"); return}
        let f = faces[0]
        print("Face: \(f[0]), \(f[1]), \(f[2]), \(f[3]), conf \(f[4])")
        if(landmarks.count > 0) {
            print("Landmark confidence: \(landmarks[0][0]), region count: \(landmarks[0].count - 1)")
        }*/
    }
    
    
    
    private static func nativeLandmarkObjectToArray(_ lmk: VNFaceLandmarks2D?, conf: Double) -> [[Double]] {
        if(lmk == nil) {return []}
        let landmarks = lmk!
        
        var landmarksArray: [[Double]] = [[conf]]
        
        func addLandmarkPoints(_ landmarkRegion: VNFaceLandmarkRegion2D?) {
            guard let points = landmarkRegion?.normalizedPoints else {
                landmarksArray.append([])
                return
            }
            var regionArray = [Double]()
            for point in points {
                regionArray.append(point.x)
                regionArray.append(point.y)
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
        
        return landmarksArray
    }
    
    
    
    
}
