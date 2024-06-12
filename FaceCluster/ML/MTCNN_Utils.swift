//
//  MTCNN-Utils.swift
//  FaceCluster
//
//  Created by El-Mundo on 08/06/2024.
//

import Foundation
import AppKit

class MTCNN_Utils {
    /// In pixels
    //private static let IMG_SIZE_THRESHOLD = 1080
    /// Suggested by the original MTCNN algorithm's paper by Zhang et al.
    private static let SCALING_FACTOR = 0.709
    
    static func generatePyramidScales(image: CGImage) -> [Double] {
        let ow = image.width
        let oh = image.height
        /*let minSide = min(ow, oh)
        let maxSide = max(ow, oh)
        
        var scale: Double = 1.0
        
        // make the longer side always indentical to the image size threshold
        if(minSide > IMG_SIZE_THRESHOLD) {
            scale = 1000.0 / Double(minSide)
        } else if(maxSide < IMG_SIZE_THRESHOLD) {
            scale = 1000.0 / Double(maxSide)
        }*/
        
        var scales = [Double]()
        var scaleTime = 0
        var ms = Double(min(ow, oh))
        
        while(ms >= 12) {
            //scales.append(scale * pow(SCALING_FACTOR, Double(scaleTime)))
            scales.append(pow(SCALING_FACTOR, Double(scaleTime)))
            ms *= SCALING_FACTOR
            scaleTime += 1
        }
        
        return scales
    }
    
    static func buffer12x12(attrs: CFDictionary) -> CVPixelBuffer? {
        var pixelBuffer : CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, 12, 12, kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)

        guard (status == kCVReturnSuccess) else {
            return nil
        }

        return pixelBuffer
    }
    
    /// The buffer must be 12x12 sized
    static func renderSlidingBox(_ image: CIImage, from x: Int, from y: Int, to dest: CIRenderDestination) {
        let range = CGRect(x: x, y: y, width: 12, height: 12)
        GPUManager.instance!.renderToBuffer(image, rangeInImage: range, originInBuffer: CGPoint(x: 0, y: 0), dest: dest)
    }
    
}
