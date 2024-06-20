//
//  GPUManager.swift
//  FaceCluster
//
//  Created by El-Mundo on 09/06/2024.
//

import Foundation
import Metal
import AppKit
import MetalKit

class GPUManager {
    public static var instance: GPUManager?
    
    let metalDevice: MTLDevice?
    var useCPU = false
    
    private let ciContext: CIContext
    
    init() {
        metalDevice = MTLCreateSystemDefaultDevice()
        if(metalDevice == nil) {
            print("Failed to initialise Metal environment, using CPU mode")
            useCPU = true
        }
        
        if(!useCPU && metalDevice != nil) {
            ciContext = CIContext(mtlDevice: metalDevice!)
        } else {
            ciContext = CIContext()
        }
        
        GPUManager.instance = self
    }
    
    func getMTLDevice() -> MTLDevice? {
        return metalDevice
    }
    
    func renderToBuffer(_ image: CIImage, to buffer: CVPixelBuffer?) {
        if(buffer != nil) {
            ciContext.render(image, to: buffer!)
        } else {
            print("Unable to render image to buffer due to failing to locate pixel buffer.")
        }
    }
    
    func renderToBuffer(_ image: CIImage, rangeInImage: CGRect, originInBuffer: CGPoint, dest: CIRenderDestination) {
        do {
            let task = try ciContext.startTask(toRender: image, from: rangeInImage, to: dest, at: originInBuffer)
            let _ = try task.waitUntilCompleted()
        } catch {
            print("Unable to render image to buffer: \(error)")
        }
    }
    
    func ciImageToCG(image: CIImage, rect: CGRect) -> CGImage? {
        return ciContext.createCGImage(image, from: rect)
    }
    
    func fillPixelBufferWithCIImage(in image: CIImage, out buffer: CVPixelBuffer, targetSize: CGSize) {
        let scaleX = targetSize.width / image.extent.size.width
        let scaleY = targetSize.height / image.extent.size.height
        let scale = min(scaleX, scaleY)

        let resizedImage = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        
        ciContext.render(resizedImage, to: buffer, bounds: CGRect(origin: CGPoint.zero, size: targetSize), colorSpace: CGColorSpaceCreateDeviceRGB())
    }
    
    func createPixelBuffer(size: CGSize) -> CVPixelBuffer? {
        let attributes: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue!,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue!,
            kCVPixelBufferWidthKey: size.width,
            kCVPixelBufferHeightKey: size.height,
            kCVPixelBufferPixelFormatTypeKey: Int(kCVPixelFormatType_32ARGB)
        ]
        var pixelBuffer : CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width), Int(size.height), kCVPixelFormatType_32ARGB, attributes as CFDictionary, &pixelBuffer)

        guard (status == kCVReturnSuccess) else {
            return nil
        }

        return pixelBuffer
    }
    
    func createTexture(from image: CGImage) -> MTLTexture? {
        if(self.useCPU || metalDevice == nil) {
            return nil
        }
        let textureLoader = MTKTextureLoader(device: self.metalDevice!)
        let options: [MTKTextureLoader.Option: Any] = [
            .SRGB: false,
            .origin: MTKTextureLoader.Origin.topLeft
        ]
        return try? textureLoader.newTexture(cgImage: image, options: options)
    }
    
}
