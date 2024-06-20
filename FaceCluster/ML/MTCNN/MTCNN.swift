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
import Vision

class MTCNN {
    static let PNET_CONF_THRESHOLD: Double = 0.6,
               RNET_CONF_THRESHOLD: Double = 0.7,
               ONET_CONF_THRESHOLD: Double = 0.7
    let onet: ONet, pnet: PNet, rnet: RNet
    
    struct PNetTemporaryStruct {
        let boxes: [[Double]]
        let scale: Double
        let position: [(Int, Int)]
    }

    
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
    
    public func detectFaces(image: CGImage) -> [[Double]]? {
        let pyramid = MTCNN_Utils.generatePyramidScales(image: image)
        let ciImg = CIImage(cgImage: image)
        var proposalOutputs = [PNetTemporaryStruct]()
        
        for scale in pyramid {
            let scaledImg = ImageUtils.resizeCIImage(ciImg, scale: scale)
            guard let img = scaledImg else {
                // If scaling failed
                continue
            }
            
            let pnetvn = PNetVN(pnet: pnet)
            //print("Scale \(scale)")
            let proposalBoxes = pnetvn.detectFaces(in: img)
            let box = proposalBoxes.0
            //print(proposalBoxes!.count)
            proposalOutputs.append(PNetTemporaryStruct(boxes: box, scale: scale, position: proposalBoxes.1))
        }
        
        var nms = [[Double]]()
        for proposalOutput in proposalOutputs {
            var nmsRects = [[Double]]()
            for i in 0..<proposalOutput.boxes.count {
                let box = proposalOutput.boxes[i]
                let position: (Int, Int) = proposalOutput.position[i]
                let ox = Double(position.0 * 2 + 1) * proposalOutput.scale
                let oy = Double(position.1 * 2 + 1) * proposalOutput.scale
                let ow = 11 * proposalOutput.scale
                let oh = 11 * proposalOutput.scale
                let x1 = max(0, ox + ow * box[0])
                let y1 = max(0, oy + oh * box[1])
                let x2 = min(Double(image.width - 1), ox + ow * (1 + box[2]))
                let y2 = min(Double(image.height - 1), oy + oh * (1 + box[3]))
                if(x2 > x1 && y2 > y1) {
                    let rectangle = [x1, y1, x2, y2, box[4]]
                    nmsRects.append(rectangle)
                }
            }
            let scaledNMS = MTCNN_Utils.NMS(bboxes: nmsRects, iou: true)
            nms.append(contentsOf: scaledNMS)
        }
        
        nms = MTCNN_Utils.NMS(bboxes: nms, iou: true, minSc: 0.7)
        // Clear parameter buffers
        PNetVN.faceBuffer.removeAll()
        PNetVN.indexBuffer.removeAll()
        if(nms.count < 1) {
            print("No face found in PNet")
            return []
        }
        
        let RNet_BoxSize = CGSize(width: 24, height: 24)
        guard let pixelBuffer = GPUManager.instance?.createPixelBuffer(size: RNet_BoxSize) else {
            print("Failed to create pixel buffer")
            return nil
        }
        
        var rnetOutputs = [[Double]]()
        for faceBox in nms {
            let boxW = faceBox[2] - faceBox[0]
            let boxH = faceBox[3] - faceBox[1]
            let cropBox: CGRect = CGRect(x: faceBox[0], y: faceBox[1], width: boxW, height: boxH)
            let croppedImg = ImageUtils.cropCIImage(ciImg, toRect: cropBox)
            guard let alignedImg = ImageUtils.alignCIImage(croppedImg!) else {
                continue
            }
            GPUManager.instance?.fillPixelBufferWithCIImage(in: alignedImg, out: pixelBuffer, targetSize: RNet_BoxSize)
            guard let rdata = try? rnet.prediction(data: pixelBuffer) else {
                continue
            }
            let conf = rdata.prob1[[0, 0, 1, 0, 0] as [NSNumber]].doubleValue
            if(conf > MTCNN.RNET_CONF_THRESHOLD) {
                let rbX1 = rdata.conv5_2[[0, 0, 0, 0, 0] as [NSNumber]].doubleValue
                let rbY1 = rdata.conv5_2[[0, 0, 1, 0, 0] as [NSNumber]].doubleValue
                let rbX2 = rdata.conv5_2[[0, 0, 2, 0, 0] as [NSNumber]].doubleValue
                let rbY2 = rdata.conv5_2[[0, 0, 3, 0, 0] as [NSNumber]].doubleValue
                
                let ox1 = max(0, faceBox[0] + boxW * rbX1)
                let oy1 = max(0, faceBox[1] + boxH * rbY1)
                let ox2 = min(Double(image.width), faceBox[2] + boxW * rbX2)
                let oy2 = min(Double(image.height), faceBox[3] + boxH * rbY2)
                
                if(ox2 > ox1 && oy2 > oy1) {
                    rnetOutputs.append([ox1, oy1, ox2, oy2, conf])
                }
            }
        }
        rnetOutputs = MTCNN_Utils.NMS(bboxes: rnetOutputs, iou: true)
        if(rnetOutputs.count < 1) {
            print("No face box found in RNet")
            return []
        }
        
        
        let ONet_BoxSize = CGSize(width: 48, height: 48)
        guard let pixelBuffer1 = GPUManager.instance?.createPixelBuffer(size: ONet_BoxSize) else {
            print("Failed to create pixel buffer")
            return nil
        }
        var finalOutputs = [[Double]]()
        
        for box in rnetOutputs {
            let boxW = box[2] - box[0]
            let boxH = box[3] - box[1]
            let cropBox: CGRect = CGRect(x: box[0], y: box[1], width: boxW, height: boxH)
            let croppedImg = ImageUtils.cropCIImage(ciImg, toRect: cropBox)
            guard let alignedImg = ImageUtils.alignCIImage(croppedImg) else {
                continue
            }
            
            GPUManager.instance?.fillPixelBufferWithCIImage(in: alignedImg, out: pixelBuffer1, targetSize: ONet_BoxSize)
            guard let odata = try? onet.prediction(data: pixelBuffer1) else {
                continue
            }
            
            let landmarksData = odata.conv6_3
            let rboxes = odata.conv6_2
            let conf = odata.prob1[[0, 0, 1, 0, 0] as [NSNumber]].doubleValue
            if(conf < MTCNN.ONET_CONF_THRESHOLD) {
                continue
            }
            
            var newBox = [box[0], box[1], box[2], box[3], conf]
            for i in 0...3 {
                let rbv = rboxes[[0, 0, i, 0, 0] as [NSNumber]].doubleValue
                newBox.append(rbv)
            }
            
            for i in 0...9 {
                let v = landmarksData[[0, 0, i, 0, 0] as [NSNumber]].doubleValue
                newBox.append(v)
            }
            
            finalOutputs.append(newBox)
        }

        finalOutputs = MTCNN_Utils.NMS(bboxes: finalOutputs, iou: false)
        var formattedOutput = [[Double]]()
        
        for o in finalOutputs {
            let bW = o[2] - o[0] + 1
            let bH = o[3] - o[1] + 1
            
            let x1 = max(0, o[0] + o[5] * bW)
            let y1 = max(0, o[1] + o[6] * bH)
            let x2 = min(Double(image.width), o[2] + o[7] * bW)
            let y2 = min(Double(image.height), o[3] + o[8] * bH)
            var output = [x1, y1, x2, y2, o[4]]
            
            for i in stride(from: 9, to: 18, by: 2) {
                let lmX = o[i] * bW + o[0] - 1
                let lmY = o[i+1] * bH + o[1] - 1
                output.append(contentsOf: [lmX, lmY])
            }
            formattedOutput.append(output)
        }
        
        return formattedOutput
    }
    
}

class PNetVN {
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
