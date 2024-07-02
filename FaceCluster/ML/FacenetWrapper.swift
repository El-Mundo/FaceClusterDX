//
//  FacenetWrapper.swift
//  FaceCluster
//
//  Created by El-Mundo on 22/06/2024.
//

import Foundation
import Vision
import AppKit

class FacenetWrapper {
    let model: VNCoreMLModel
    var tasks: [FacenetTask]
    
    init() {
        guard let facenet512 = try? Facenet512(),
                let _model = try? VNCoreMLModel(for: facenet512.model) else {
            fatalError(String(localized: "Failed to load Facenet model"))
        }
        self.model = _model
        self.tasks = []
    }
    
    func detectFacesAsync(in images: [(CGImage?, Face)]) {
        for image in images {
            guard let alignedImage = image.0 else {
                continue
            }
            let handler = VNImageRequestHandler(cgImage: alignedImage, options: [:])
            let task = FacenetTask(_model: model, face: image.1)
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([task.request!])
                } catch {
                    print("Failed to perform face detection: \(error)")
                    return
                }
            }
            tasks.append(task)
        }
    }
    
    func detectFacesSync(in network: FaceNetwork, batchSize: Int) {
        let fa = FaceAlignment()
        let faces = network.faces
        if(faces.count < 1) {
            return
        }
        
        print("Starting Facenet")
        
        var batchedImages = [(CGImage?, Face)]()
        var b = 0
        
        let sortedFaces = faces.sorted(by: {
            $0.detectedAttributes.frameIdentifier < $1.detectedAttributes.frameIdentifier
        })
        var frameIdentifier = sortedFaces[0].detectedAttributes.frameIdentifier
        var frameImage = sortedFaces[0].getFrameAsImage()
        
        for face in sortedFaces {
            let id = face.detectedAttributes.frameIdentifier
            if(id != frameIdentifier) {
                frameImage = face.getFrameAsImage()
                frameIdentifier = id
            }
            
            if(batchedImages.count >= batchSize) {
                detectFacesAsync(in: batchedImages)
                print("Processing batch #\(b)")
                b = b + 1
                while(!self.isCompleted()) {
                    sleep(1)
                }
                batchedImages.removeAll()
            }
            
            if(face.disabled || frameImage == nil) {
                continue
            }
            batchedImages.append((fa.align(frameImage!, face: face.detectedAttributes, size: CGSize(width: 160, height: 160)), face))
        }
        
        if(batchedImages.count > 0) {
            detectFacesAsync(in: batchedImages)
            print("Processing batch #\(b)")
            while(!self.isCompleted()) {
                sleep(1)
            }
            batchedImages.removeAll()
        }
    }
    
    func isCompleted() -> Bool {
        var com = true
        for task in tasks {
            if(!task.completed) {
                com = false
                break
            }
        }
        return com
    }
    
    class FacenetTask {
        var request: VNCoreMLRequest?
        var output: [Double]?
        var confidence: Float?
        var completed = false
        var obj: Face
        
        init(_model: VNCoreMLModel, face: Face) {
            self.output = nil
            self.request = nil
            self.obj = face
            
            let _request = VNCoreMLRequest(model: _model) { request, error in
                guard let results = request.results as? [VNCoreMLFeatureValueObservation] else {
                    print("Failed to get results")
                    self.completed = true
                    return
                }
                
                if(results.count != 1) {
                    print("Results format corrupted")
                    self.completed = true
                    return
                }
                let conf = results[0].confidence.magnitude
                guard let multiArray = results[0].featureValue.multiArrayValue else {
                    print("Failed to access results of Facenet")
                    self.completed = true
                    return
                }
                let shape = multiArray.shape
                //print(shape.count)
                if(shape.count != 2) {
                    print("Results format corrupted")
                    self.completed = true
                    return
                }
                let chn = shape[1].intValue
                if(chn != 512) {
                    print("Results format corrupted")
                    self.completed = true
                    return
                }
                
                var vector512 = [Double]()
                for i in 0..<512 {
                    let val = multiArray[[0, i] as [NSNumber]].floatValue
                    vector512.append(Double(val))
                }
                self.output = vector512
                self.confidence = conf
                self.completed = true
            }
            
            _request.imageCropAndScaleOption = .scaleFill
            self.request = _request
        }
    }
}
