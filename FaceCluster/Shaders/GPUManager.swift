//
//  GPUManager.swift
//  FaceCluster
//
//  Created by El-Mundo on 09/06/2024.
//

import Foundation
import Metal
import AppKit

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
    
}
