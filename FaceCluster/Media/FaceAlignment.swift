//
//  FaceAlignment.swift
//  FaceCluster
//
//  Created by El-Mundo on 30/06/2024.
//

import Foundation
import AppKit
import Accelerate

class FaceAlignment {
    let eyeOffset: CGFloat = 0.35
    
    public func align(_ image: CGImage, face: DetectedFace, size: CGSize?) -> CGImage? {
        let ciimage = CIImage(cgImage: image)
        let w = ciimage.extent.width, h = ciimage.extent.height
        let faceBox = face.box
        let temporaryHeight = faceBox[3] * h
        let faceRect = CGRect(x: faceBox[0] * w, y: faceBox[1] * -h + h - temporaryHeight, width: faceBox[2] * w, height: faceBox[3] * h)
        let invertFaceRect = CGRect(x: faceBox[0] * w, y: faceBox[1] * h, width: faceBox[2] * w, height: faceBox[3] * h)
        let landmarks = face.landmarks
        
        if(landmarks.count < 10) {
            return nil
        }
        
        let leftEye = landmarks[1]
        let rightEye = landmarks[2]
        //let nose = landmarks[5]
        
        var transform = CGAffineTransform.identity
        
        let leftEyeOuter = CGPoint(x: leftEye[0].x, y: 1 - leftEye[0].y)
        let leftEyeInner = CGPoint(x: leftEye[3].x, y: 1 - leftEye[3].y)
        let rightEyeOuter = CGPoint(x: rightEye[0].x, y: 1 - rightEye[0].y)
        let rightEyeInner = CGPoint(x: rightEye[3].x, y: 1 - rightEye[3].y)
        //let noseCentre = CGPoint(x: nose[0].x, y: 1 - nose[0].y)
        let x1 = (leftEyeOuter.x + leftEyeInner.x) / 2 * faceRect.width
        let y1 = (leftEyeOuter.y + leftEyeInner.y) / 2 * faceRect.height
        let x2 = (rightEyeOuter.x + rightEyeInner.x) / 2 * faceRect.width
        let y2 = (rightEyeOuter.y + rightEyeInner.y) / 2 * faceRect.height
        //let x3 = (noseCentre.x + noseCentre.x) / 2 * faceRect.width
        //let y3 = (noseCentre.y + noseCentre.y) / 2 * faceRect.height
        
        let deltaX = x2 - x1
        let deltaY = y2 - y1
        let angle = atan2(deltaY, deltaX)
        //let eyeDistance = ((deltaX * deltaX) + (deltaY * deltaY)).squareRoot()
        //let eyeDistanceNorm = (0.5 - eyeOffset) * 2
        //let newBoxSize = eyeDistance / eyeDistanceNorm
        
        //let eyesCentre = CGPoint(x: (x1 + x2) / 2, y: (y1 + y2) / 2)
        //let cdX = faceRect.width * 0.5 - eyesCentre.x
        //let cdY = faceRect.height * 0.5 - eyesCentre.y
        //let eyesCentreToBoxCentre = ((cdX * cdX) + (cdY * cdY)).squareRoot()
        
        //let tra = (-faceRect.midX, -(h-faceRect.midY))
        //let tra = (-faceRect.minX-eyesCentre.x, -(h-faceRect.minY-eyesCentre.y))
        //transform = transform.translatedBy(x: tra.0, y: tra.1)
        transform = transform.rotated(by: angle)
        //transform = transform.translatedBy(x: 0, y: eyesCentreToBoxCentre)
        //transform = transform.translatedBy(x: -tra.0, y: -tra.1)

        /*// Calculate translation to center the nose
        let noseOffsetX = x3 - 0.5
        let noseOffsetY = y3 - 0.5
        transform = transform.translatedBy(x: -noseOffsetX * faceRect.width, y: -noseOffsetY * faceRect.height)*/
        
        let alignedImage = ciimage.transformed(by: transform)
        //let cropRect = CGRect(origin: CGPoint(x: -faceRect.width * 0.5, y: -faceRect.height * 0.5), size: CGSize(width: faceRect.width, height: faceRect.height))
        let cropRect = invertFaceRect.applying(transform)
        //print(cropRect)
        
        guard let cgImage = GPUManager.instance!.ciImageToCG(image: alignedImage, rect: cropRect) else {
            return nil
        }
        //guard let cgImage = GPUManager.instance!.ciImageToCG(image: alignedImage, rect: CGRect(origin: CGPoint(x: -newBoxSize * 0.5, y: -newBoxSize * 0.5), size: CGSize(width: newBoxSize, height: newBoxSize))) else {
        //    return nil
        //}
        guard let imgSize = size else {
            return cgImage
        }
        return ImageUtils.resizeCGExactly(cgImage, size: imgSize)
    }
}
