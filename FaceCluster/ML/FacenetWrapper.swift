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
    let request: VNCoreMLRequest, model: VNCoreMLModel
    static var faceBuffer = [[Double]]()
    static var indexBuffer = [(Int, Int)]()
    
    init(pnet: PNet) {
        guard let _model = try? VNCoreMLModel(for: pnet.model) else {
            fatalError(String(localized: "Failed to load PNet model"))
        }
        
        let _request = VNCoreMLRequest(model: _model) { request, error in
            guard let results = request.results as? [VNCoreMLFeatureValueObservation] else {
                print("Failed to get results")
                return
            }
            
            if(results.count != 2) {
                print("Results format corrupted")
                return
            }
            guard let bboxes = results[0].featureValue.multiArrayValue else {
                print("Failed to access boxes of PNet")
                return
            }
            guard let confs = results[1].featureValue.multiArrayValue else {
                print("Failed to access confidence of PNet")
                return
            }
            let shape = confs.shape
            if(shape.count != 5) {
                print("Results format corrupted")
                return
            }
            let chn = shape[2].intValue
            if(chn != 2) {
                print("Results format corrupted")
                return
            }
            let w = shape[3].intValue
            let h = shape[4].intValue
            
            for x in 0..<w {
                for y in 0..<h {
                    let conf = confs[[0, 0, 1, x, y] as [NSNumber]].doubleValue
                    if(conf < MTCNN.PNET_CONF_THRESHOLD) {
                        continue
                    }
                    
                    let boxX = bboxes[[0, 0, 0, x, y] as [NSNumber]].doubleValue
                    let boxY = bboxes[[0, 0, 1, x, y] as [NSNumber]].doubleValue
                    let boxW = bboxes[[0, 0, 2, x, y] as [NSNumber]].doubleValue
                    let boxH = bboxes[[0, 0, 3, x, y] as [NSNumber]].doubleValue
                    
                    PNetVN.faceBuffer.append([boxX, boxY, boxW, boxH, conf])
                    PNetVN.indexBuffer.append((x, y))
                }
            }
        }
        
        _request.imageCropAndScaleOption = .scaleFill
        self.request = _request
        self.model = _model
    }
    
    func detectFaces(in image: CIImage) -> ([[Double]], [(Int, Int)]) {
        let handler = VNImageRequestHandler(ciImage: image, options: [:])
        PNetVN.faceBuffer.removeAll()
        PNetVN.indexBuffer.removeAll()

        do {
            try handler.perform([request])
        } catch {
            print("Failed to perform face detection: \(error)")
            return ([], [])
        }
        
        return (PNetVN.faceBuffer, PNetVN.indexBuffer)
    }
}
