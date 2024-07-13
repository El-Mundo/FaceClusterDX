//
//  CustomCoreML.swift
//  FaceCluster
//
//  Created by El-Mundo on 12/07/2024.
//

import Foundation
import CoreML
import Vision
import SwiftUI

class LocalCoreML {
    let url: URL
    var faceBoxSize: CGSize?
    let indicator: Binding<String>
    var initTask: Task<Sendable, Error>?
    var vnModel: VNCoreMLModel? = nil
    var mlModel: MLModel? = nil
    var tasks: [CustomCoreMLTask] = []
    var progress: CGFloat = 0.0
    var compilable = true
    
    init( url: URL, faceSize: CGSize?, indicator: Binding<String> ) {
        self.url = url
        self.indicator = indicator
        self.faceBoxSize = faceSize
        initTask = Task {
            do {
                try await self.compile()
            } catch {
                compileFailed(error: error)
            }
            return
        }
    }
    
    func cancel() {
        if(vnModel == nil) {
            initTask?.cancel()
        }
        vnModel = nil
        mlModel = nil
    }
    
    func compileFailed(error: Error) {
        indicator.wrappedValue = String(localized: "Error: ") + error.localizedDescription
        compilable = false
    }
    
    func compile() async throws {
        let compiled = try await MLModel.compileModel(at: url)
        let model = try MLModel(contentsOf: compiled)
        self.mlModel = model
        self.vnModel = try VNCoreMLModel(for: mlModel!)
        indicator.wrappedValue = String(localized: "Successfully compiled")
    }
    
    func predict(in image: CGImage?, face: Face) {
        guard let model = vnModel,
              let alignedImg = image else {
            return
        }
        
        let task = CustomCoreMLTask(_model: model, face: face)
        let handler = VNImageRequestHandler(cgImage: alignedImg, options: [:])
        
        do {
            tasks.append(task)
            try handler.perform([task.request!])
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func getCompleted() -> Int {
        var c = 0
        for task in tasks {
            if(task.completed) {
                c += 1
            }
        }
        return c
    }
    
    func updateProgress(cursor: Int, total: Int) {
        progress = min(1.0, CGFloat(cursor) / CGFloat(total))
    }
    
    func batchPredict(in faces: [Face], size: Int, align: Bool, progressBar: Binding<CGFloat>) {
        let fa = FaceAlignment()
        var i = 0
        while(i < faces.count) {
            for n in i..<(i+size) {
                if(n >= faces.count) { break }
                let face = faces[n]
                guard let img = face.getFullSizeImage() else { continue }
                predict(in: align ? fa.align(img, face: face.detectedAttributes, size: faceBoxSize) : (faceBoxSize == nil ? img : ImageUtils.resizeCGExactly(img, size: faceBoxSize!)), face: face)
            }
            i = i + size
            while(getCompleted() < tasks.count) {
                updateProgress(cursor: i, total: faces.count)
                progressBar.wrappedValue = progress
            }
        }
        updateProgress(cursor: i, total: faces.count)
        progressBar.wrappedValue = progress
    }
    
    func writeResults(progressBar: Binding<CGFloat>, root: String, net: FaceNetwork) -> String {
        progress = 0
        progressBar.wrappedValue = progress
        var p = 0
        var s = 0
        var shapes = [String: (Int, String, String)]()
        var unsupportedFields: [String] = []
        
        for task in tasks {
            if(task.completed) {
                guard let output = task.output else {
                    continue
                }
                var ss = 0
                
                for o in output {
                    let tOut = o.0
                    let confidence = o.1
                    let fieldName = o.2
                    
                    if(unsupportedFields.contains(where: { $0 == fieldName })) {
                        continue
                    } else {
                        guard let shape = shapes[fieldName] else {
                            if(tOut.dataType != .double && tOut.dataType != .float16 && tOut.dataType != .float32) {
                                unsupportedFields.append(fieldName)
                                continue
                            }
                            let curShape = tOut.shape
                            var lastNonSingleDimension: Int = -1
                            if(curShape.count < 1) {
                                unsupportedFields.append(fieldName)
                                continue
                            }
                            
                            for d in stride(from: curShape.count - 1, to: 0, by: -1) {
                                if(Int(truncating: curShape[d]) > 1) {
                                    lastNonSingleDimension = d
                                }
                            }
                            
                            var vectorDimension: Int
                            if(lastNonSingleDimension != -1) {
                                vectorDimension = Int(truncating: curShape[lastNonSingleDimension])
                            } else {
                                vectorDimension = 1
                            }
                            
                            let writtenName = net.getUniqueKeyName(name: "\(root)_\(fieldName)")
                            let writtenCName = net.getUniqueKeyName(name: "\(root)_\(fieldName)_Conf")
                            shapes.updateValue((vectorDimension, writtenName, writtenCName), forKey: fieldName)
                            net.forceAppendAttribute(key: writtenName, type: .Vector, dimensions: vectorDimension)
                            net.forceAppendAttribute(key: writtenCName, type: .Decimal, dimensions: 1)
                            
                            let de = task.decodeMLMultiArray(tOut, use1D: true, outputDimension: vectorDimension)
                            let vector = FaceVector(de.first!, for: writtenName)
                            let con = FaceDecimal(Double(confidence), for: writtenCName)
                            task.obj.forceUpdateAttribute(for: FaceVector.self, key: writtenName, value: vector)
                            task.obj.forceUpdateAttribute(for: FaceDecimal.self, key: writtenCName, value: con)
                            task.obj.updateSaveFileAtOriginalLocation()
                            ss += 1
                            
                            continue
                        }
                        
                        let de = task.decodeMLMultiArray(tOut, use1D: true, outputDimension: shape.0)
                        let vector = FaceVector(de.first!, for: shape.1)
                        let con = FaceDecimal(Double(confidence), for: shape.2)
                        task.obj.forceUpdateAttribute(for: FaceVector.self, key: shape.1, value: vector)
                        task.obj.forceUpdateAttribute(for: FaceDecimal.self, key: shape.2, value: con)
                        task.obj.updateSaveFileAtOriginalLocation()
                        ss += 1
                    }
                }
                if(ss == shapes.count) {
                    s += 1
                }
            }
            p += 1
            progress = CGFloat(p) / CGFloat(tasks.count)
            progressBar.wrappedValue = progress
        }
        
        var skipped = ""
        for unsupportedField in unsupportedFields {
            skipped.append(unsupportedField + ", ")
        }
        if(skipped.hasSuffix(", ")) {
            skipped.removeLast()
            skipped.removeLast()
        }
        let failed = p - s
        
        return String(localized: "Results for \(s) faces successfully saved") + (failed > 0 ? String(localized: ", with \(failed) fails.") : String(localized: ".")) + (skipped.isEmpty ? "" : "\n\nFields skipped due to unsupported data type:\n") + skipped
    }

}

class CustomCoreMLTask {
    var request: VNCoreMLRequest?
    var output: [(MLMultiArray, Float, String)]?
    var completed = false
    var obj: Face
    
    init(_model: VNCoreMLModel, face: Face) {
        self.output = nil
        self.request = nil
        self.obj = face
        
        let _request = VNCoreMLRequest(model: _model) { request, error in
            guard let results = request.results as? [VNCoreMLFeatureValueObservation] else {
                print("Failed to get results")
                self.completed = true
                return
            }
            
            var arrays: [(MLMultiArray, Float, String)] = []
            
            for r in results {
                let conf = r.confidence.magnitude
                let name = r.featureName
                guard let multiArray = r.featureValue.multiArrayValue else {
                    print("Failed to access results of Facenet")
                    continue
                }
                arrays.append((multiArray, conf, name))
            }
            
            self.output = arrays
            self.completed = true
        }
        
        _request.imageCropAndScaleOption = .scaleFill
        self.request = _request
    }
    
    class func splitArray<T>(_ array: [T], size: Int) -> [[T]] {
        var result: [[T]] = []
        var index = 0
        while index < array.count {
            let end = index + size
            let chunk = Array(array[index..<min(end, array.count)])
            result.append(chunk)
            index += size
        }
        return result
    }
    
    class func flattenMLMultiDimensionalArray(_ array: MLMultiArray) -> [Double] {
        // Check the data type of the MLMultiArray
        guard array.dataType == .double || array.dataType == .float16 || array.dataType == .float32 else {
            fatalError("Only MLMultiArray with float or double data type is supported")
        }
        
        // Get the number of elements
        let count = array.count
        
        // Create a flat array to hold the elements
        var flatArray = [Double](repeating: 0.0, count: count)
        
        // Copy elements from MLMultiArray to the flat array
        if(array.dataType == .double) {
            for i in 0..<count {
                flatArray[i] = array[i].doubleValue
            }
        } else if(array.dataType == .float32 || array.dataType == .float16) {
            for i in 0..<count {
                flatArray[i] = Double(array[i].floatValue)
            }
        }
        
        return flatArray
    }

    func decodeMLMultiArray(_ array: MLMultiArray, use1D: Bool, outputDimension: Int?) -> [[Double]] {
        var r = [[Double]]()
        
        if(use1D) {
            r = [CustomCoreMLTask.flattenMLMultiDimensionalArray(array)]
        } else {
            let f = CustomCoreMLTask.flattenMLMultiDimensionalArray(array)
            r = CustomCoreMLTask.splitArray(f, size: outputDimension!)
        }
        
        return r
    }
}
