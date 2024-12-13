//
//  GPUFont.swift
//  FaceCluster
//
//  Created by El-Mundo on 13/12/2024.
//

import MetalKit
import CoreImage

class FontTextureArray {
    var texture: MTLTexture?
    var commandQueue: MTLCommandQueue

    init(device: MTLDevice, fontSize: CGFloat, textureSize: CGSize, commandQueue: MTLCommandQueue) {
        self.commandQueue = commandQueue
        self.texture = createFontTextureArray(device: device, fontSize: fontSize, textureSize: textureSize)
    }

    private func createFontTextureArray(device: MTLDevice, fontSize: CGFloat, textureSize: CGSize) -> MTLTexture? {
        // Create a descriptor for the 2D array texture
        let arrayTextureDescriptor = MTLTextureDescriptor()
        arrayTextureDescriptor.pixelFormat = .bgra8Unorm
        arrayTextureDescriptor.width = Int(textureSize.width)
        arrayTextureDescriptor.height = Int(textureSize.height)
        arrayTextureDescriptor.textureType = .type2DArray
        arrayTextureDescriptor.arrayLength = 11 // 10 digits + semicolon
        arrayTextureDescriptor.usage = [.shaderRead, .renderTarget]

        guard let arrayTexture = device.makeTexture(descriptor: arrayTextureDescriptor) else { return nil }

        // Characters to render
        let characters = "0123456789:"

        // Render each character into a separate texture and copy it into the array texture
        for (index, char) in characters.enumerated() {
            if let characterTexture = renderCharacterToTexture(device: device,
                                                               character: String(char),
                                                               fontSize: fontSize,
                                                               textureSize: textureSize) {
                copyTextureToArraySlice(source: characterTexture, destination: arrayTexture, slice: index)
            }
        }

        return arrayTexture
    }

    private func renderCharacterToTexture(device: MTLDevice, character: String, fontSize: CGFloat, textureSize: CGSize) -> MTLTexture? {
        // Create a descriptor for the 2D texture
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.pixelFormat = .bgra8Unorm
        textureDescriptor.width = Int(textureSize.width)
        textureDescriptor.height = Int(textureSize.height)
        textureDescriptor.usage = [.shaderRead, .renderTarget]

        guard let texture = device.makeTexture(descriptor: textureDescriptor) else { return nil }

        // Create Core Graphics context
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue

        guard let context = CGContext(data: nil,
                                       width: Int(textureSize.width),
                                       height: Int(textureSize.height),
                                       bitsPerComponent: 8,
                                       bytesPerRow: Int(textureSize.width) * 4,
                                       space: colorSpace,
                                       bitmapInfo: bitmapInfo) else { return nil }

        // Clear background
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0))
        context.fill(CGRect(origin: .zero, size: textureSize))

        // Render the character using Core Text
        let attributedString = NSAttributedString(string: character, attributes: [
            .font: NSFont.systemFont(ofSize: fontSize),
            .foregroundColor: NSColor.white
        ])
        let line = CTLineCreateWithAttributedString(attributedString)
        let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        let offsetX = (textureSize.width - bounds.width) / 2 - bounds.origin.x
        let offsetY = (textureSize.height - bounds.height) / 2 - bounds.origin.y

        context.textPosition = CGPoint(x: offsetX, y: offsetY)
        CTLineDraw(line, context)

        // Create a CGImage and copy it to the Metal texture
        //guard let cgImage = context.makeImage() else { return nil }

        let region = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0), size: MTLSize(width: Int(textureSize.width), height: Int(textureSize.height), depth: 1))
        texture.replace(region: region, mipmapLevel: 0, withBytes: context.data!, bytesPerRow: context.bytesPerRow)

        return texture
    }

    private func copyTextureToArraySlice(source: MTLTexture, destination: MTLTexture, slice: Int) {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let blitCommandEncoder = commandBuffer.makeBlitCommandEncoder() else {
            return
        }
        blitCommandEncoder.copy(from: source,
                                sourceSlice: 0,
                                sourceLevel: 0,
                                sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                                sourceSize: MTLSize(width: source.width, height: source.height, depth: 1),
                                to: destination,
                                destinationSlice: slice,
                                destinationLevel: 0,
                                destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
        blitCommandEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
}

