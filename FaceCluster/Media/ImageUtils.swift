//
//  ImageUtils.swift
//  FaceCluster
//
//  Created by El-Mundo on 09/06/2024.
//

import Foundation
import AppKit
import ImageIO
import UniformTypeIdentifiers

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
    
    static func resizeCGExactly(_ image: CGImage, size: CGSize) -> CGImage? {
        let width: Int = Int(size.width)
        let height: Int = Int(size.height)
        let bytesPerPixel = image.bitsPerPixel / image.bitsPerComponent
        let destBytesPerRow = width * bytesPerPixel
        guard let colorSpace = image.colorSpace else { return nil }
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: image.bitsPerComponent, bytesPerRow: destBytesPerRow, space: colorSpace, bitmapInfo: image.alphaInfo.rawValue) else { return nil }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        return context.makeImage()
    }

    static func cropCIImage(_ inputImage: CIImage, toRect rect: CGRect) -> CIImage? {
        // Create a cropped version of the CIImage
        let croppedImage = inputImage.cropped(to: rect)
        return croppedImage
    }
    
    static func cropCGImage(_ image: CGImage, toRect rect: CGRect) -> CGImage? {
        // Create a cropped version of the CGImage
        let croppedImage = image.cropping(to: rect)
        return croppedImage
    }
    
    static func cropCGImageNormalised(_ image: CGImage, normalisedBox: [Double]) -> CGImage? {
        if(normalisedBox.count != 4) {
            return nil
        }
        let ww = Double(image.width)
        let wh = Double(image.height)
        let x = max(0, min(image.width-1, Int(normalisedBox[0] * ww)))
        let y = max(0, min(image.height-1, Int(normalisedBox[1] * -wh + wh)))
        let w = min(image.width-1-x, Int(normalisedBox[2] * ww))
        let h = min(image.height-1-y, Int(normalisedBox[3] * -wh))
        let rect = CGRect(x: x, y: y, width: w, height: h)
        let croppedImage = image.cropping(to: rect)
        return croppedImage
    }
    
    static func alignCIImage(_ image_: CIImage?) -> CIImage? {
        guard let image = image_ else {
            return nil
        }
        let translate = CGAffineTransform(translationX: -image.extent.origin.x, y: -image.extent.origin.y)
        return image.transformed(by: translate)
    }
    
    /// Returns whether successful
    static func saveImageAsJPG(_ image: CGImage, at directory: URL) -> Bool {
        let imageType = UTType.jpeg.identifier
        // Prepare to write the image to the specified URL
        guard let destination = CGImageDestinationCreateWithURL(directory as CFURL, imageType as CFString, 1, nil) else {
            print("Could not create image destination.")
            return false
        }
        
        let options: NSDictionary = [kCGImageDestinationLossyCompressionQuality: 1.0]  // max quality
        // Add the image to the destination, specifying the options as needed
        CGImageDestinationAddImage(destination, image, options)
        // Finalize the image destination to actually write the image file
        if CGImageDestinationFinalize(destination) {
            return true
        } else {
            return false
        }
    }
    
    static func loadJPG(url: URL) -> CGImage? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            print("Failed to create image source")
            return nil
        }
        let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
        return cgImage
    }
    
    static func getImageSizeFromURL(_ url: URL) -> CGSize? {
        if let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) {
            if let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as Dictionary? {
                let pixelWidth = imageProperties[kCGImagePropertyPixelWidth] as! Int
                let pixelHeight = imageProperties[kCGImagePropertyPixelHeight] as! Int
                return CGSize(width: pixelWidth, height: pixelHeight)
            }
        }
        return nil
    }
    
    public static func convertPNGToJPG(from url: URL, to destinationPath: URL) -> (Bool, URL?) {
        guard let cgImage = loadJPG(url: url) else {
            print("Failed to create CGImage")
            return (false, nil)
        }
        
        var fix = 0
        let fileManager = FileManager.default
        var dest = destinationPath.appendingPathComponent(url.deletingPathExtension().lastPathComponent + ".jpg")
        while (fileManager.fileExists(atPath: dest.path(percentEncoded: false))) {
            fix += 1
            dest = dest.deletingPathExtension().appendingPathExtension("_\(fix).jpg")
        }
        guard let destination = CGImageDestinationCreateWithURL(dest as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            print("Failed to create image destination")
            return (false, nil)
        }
        
        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: 1.0 // Maximum quality
        ]
        
        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
        
        if CGImageDestinationFinalize(destination) {
            print("Successfully converted PNG to JPG and saved at \(destinationPath)")
            return (true, dest)
        } else {
            print("Failed to finalize image destination")
            return (false, nil)
        }
    }
    
}
