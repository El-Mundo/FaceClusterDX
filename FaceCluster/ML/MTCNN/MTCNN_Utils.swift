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
    private static let IMG_SIZE_THRESHOLD = 1200
    /// Suggested by the original MTCNN algorithm's paper by Zhang et al.
    private static let SCALING_FACTOR = 0.709
    
    static func generatePyramidScales(image: CGImage) -> [Double] {
        let ow = image.width
        let oh = image.height
        //let minSide = min(ow, oh)
        let maxSide = max(ow, oh)
        
        var scale: Double = 1.0
        
        // If the long side is larger than threshold, start with a smaller scale to downsample the image
        if(maxSide > IMG_SIZE_THRESHOLD) {
            scale = Double(IMG_SIZE_THRESHOLD) / Double(maxSide)
        }
        
        var scales = [Double]()
        var scaleTime = 0
        var ms = Double(min(ow, oh)) * scale
        
        while(ms >= 12) {
            //scales.append(scale * pow(SCALING_FACTOR, Double(scaleTime)))
            scales.append(scale * pow(SCALING_FACTOR, Double(scaleTime)))
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
    
    static func IOM(r1: [Double], r2: [Double]) -> Double {
        let x11 = r1[0]
        let y11 = r1[1]
        let x12 = r1[2]
        let y12 = r1[3]
        let x21 = r2[0]
        let y21 = r2[1]
        let x22 = r2[2]
        let y22 = r2[3]
        let x_overlap = max(0, min(x12, x22) - max(x11, x21))
        let y_overlap = max(0, min(y12, y22) - max(y11, y21))
        let intersection = x_overlap * y_overlap
        let union = (x12 - x11) * (y12 - y11) + (x22 - x21) * (y22 - y21) - intersection
        if(union == 0) {
            return 0
        } else {
            return Double(intersection) / union
        }
    }
    
    static func IOU(r1: [Double], r2: [Double]) -> Double {
        let x11 = r1[0]
        let y11 = r1[1]
        let x12 = r1[2]
        let y12 = r1[3]
        let x21 = r2[0]
        let y21 = r2[1]
        let x22 = r2[2]
        let y22 = r2[3]
        let x_overlap = max(0, min(x12, x22) - max(x11, x21))
        let y_overlap = max(0, min(y12, y22) - max(y11, y21))
        let intersection = x_overlap * y_overlap
        let union = (x12 - x11) * (y12 - y11) + (x22 - x21) * (y22 - y21) - intersection
        if(union == 0) {
            return 0
        } else {
            return Double(intersection) / union
        }
    }
    
    static func NMS(bboxes: [[Double]], iou: Bool, minSc: Double=0.7) -> [[Double]] {
        var sorted = bboxes.sorted {
            $0[4] > $1[4]
        }
        var size = sorted.count
        var c = 0
        
        while c < size {
            var left = size - c - 1
            var comp = c + 1
            while left > 0 {
                var score = 0.0
                if(iou) {
                    score = IOU(r1: bboxes[c], r2: bboxes[c + 1])
                } else {
                    score = IOM(r1: bboxes[c], r2: bboxes[c + 1])
                }
                if(score > minSc) {
                    sorted.remove(at: comp)
                    size -= 1
                } else {
                    comp += 1
                }
                left -= 1
            }
            c += 1
        }
        
        return sorted
    }
    
}
