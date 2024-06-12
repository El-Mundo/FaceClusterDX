//
//  MTCNN.swift
//  FaceCluster
//
//  Created by El-Mundo on 08/06/2024.
//

import Foundation
import CoreML
import AppKit
import Metal

class MTCNN {
    let onet: ONet, pnet: PNet, rnet: RNet
    
    init() {
        guard let onet_obj = try? ONet(configuration: MLModelConfiguration()) else {
            fatalError(String(localized: "Failed to initialise ONet model for MTCNN pipeline"))
        }
        guard let pnet_obj = try? PNet(configuration: MLModelConfiguration()) else {
            fatalError(String(localized: "Failed to initialise PNet model for MTCNN pipeline"))
        }
        guard let rnet_obj = try? RNet(configuration: MLModelConfiguration()) else {
            fatalError(String(localized: "Failed to initialise RNet model for MTCNN pipeline"))
        }
        
        onet = onet_obj
        pnet = pnet_obj
        rnet = rnet_obj
    }
    
    public func detectFaces(image: CGImage, pThreshold: Double=0.6, rThreshold: Double=0.7, oThreshold: Double=0.7) {
        let pyramid = MTCNN_Utils.generatePyramidScales(image: image)

        let ciImg = CIImage(cgImage: image)
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        guard let buffer = MTCNN_Utils.buffer12x12(attrs: attrs) else {
            fatalError("Failed to allocate pixel buffer")
        }
        let dest = CIRenderDestination(pixelBuffer: buffer)
        
        let strideVal = 6
        
        for scale in pyramid {
            let scaledImg = ImageUtils.resizeCIImage(ciImg, scale: scale)
            guard let img = scaledImg else {
                // If scaling failed
                continue
            }

            let w = Int(img.extent.width)
            let h = Int(img.extent.height)
            
            let pnet_ = try! pnet_cm72()
            
            for x in stride(from: 0, to: w - 11, by: strideVal) {
                for y in stride(from: 0, to: h - 11, by: strideVal) {
                    do {
                        var time = Date.now
                        //MTCNN_Utils.renderSlidingBox(img, from: x, from: y, to: dest)
                        GPUManager.instance!.renderToBuffer(img, to: buffer)
                        print("Render")
                        print(Date.now.timeIntervalSince(time))
                        
                        time = Date.now
                        let d = try pnet.prediction(data: buffer)
                        print("MTCNN")
                        print(Date.now.timeIntervalSince(time))
                        time = Date.now
                        let d2 = try pnet_.prediction(input: buffer)
                        print("MTCNN 2")
                        print(Date.now.timeIntervalSince(time))
                        var conf: Double = 0
                        if(d.prob1.count > 1) {
                            d.prob1.withUnsafeBufferPointer(ofType: Double.self, {ptr in
                                conf = ptr[1]
                            })
                        }
                        if(conf > 0.6) {
                            print("Face detected")
                        }
                    } catch {
                        print("Error processing frame with scale \(scale) at (\(x), \(y)): \(error)")
                    }
                }
            }
        }
    }
    
}
