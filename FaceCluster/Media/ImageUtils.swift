//
//  ImageUtils.swift
//  FaceCluster
//
//  Created by El-Mundo on 09/06/2024.
//

import Foundation
import AppKit

class ImageUtils {
    static func resizeCIImage(_ image: CIImage, scale: Double) -> CIImage? {
        let filter = CIFilter(name:"CILanczosScaleTransform")!
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(scale, forKey: kCIInputScaleKey)
        return filter.outputImage
    }
    
    static func buffer(from image: CIImage, attrs: CFDictionary) -> CVPixelBuffer? {
        var pixelBuffer : CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(image.extent.width), Int(image.extent.height), kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)

        guard (status == kCVReturnSuccess) else {
            return nil
        }

        return pixelBuffer
    }
    
    static func resizeCG(image: CGImage, scale: Double) -> CGImage? {
        let ciImage = CIImage(cgImage: image)
        guard let outputImage = ImageUtils.resizeCIImage(ciImage, scale: scale) else {
            return nil
        }

        return GPUManager.instance!.ciImageToCG(image: outputImage, rect: outputImage.extent)
    }
}
