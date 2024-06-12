//
//  VideoPreviewToolbar.swift
//  FaceCluster
//
//  Created by El-Mundo on 03/06/2024.
//

import Foundation
import SwiftUI

enum ExtractionUnit: CaseIterable {
    case frame
    case second
}

enum FaceModel: CaseIterable {
    case Native
    case MTCNN
}

func getFrameSequence(vp: VideoPreview, vt: VPToolbarView) {
    vt.extractValue = checkFrameExtractValue(val: vt.extractValue, uni: vt.extractUnit)
    vt.downsampleFactor = checkDownsample(val: vt.downsampleFactor)
    
    Task{
        vp.context?.resetPB()
        vp.context?.state = 2
        try await MediaManager.instance?.generateFrameSeuqnce(extractValue: vt.extractValue, extractUnit: vt.extractUnit, context: vp.context, downsample: vt.downsampleFactor, useMTCNN: vt.faceModel == .MTCNN)
    }
}

func getUnitName(unit: ExtractionUnit) -> String {
    if(unit == .frame) {
        return String(localized: "frame")
    } else if(unit == .second) {
        return String(localized: "second")
    }
    return String(describing: unit)
}

func getUnitName(unit: FaceModel) -> String {
    if(unit == .Native) {
        return String(localized: "Vision")
    } else if(unit == .MTCNN) {
        return String(localized: "MTCNN")
    }
    return String(describing: unit)
}

///Returns the new value if not correctly formatted
func checkFrameExtractValue(val: Double, uni: ExtractionUnit) -> Double {
    var new = val
    if(uni == .frame) {
        //Must be an integer larger than 1
        if(val < 1) {
            new = 1
        } else {
            new = round(val)
        }
    } else {
        if(val < 0.008) {
            //Avoid sampling more than 120 frames per sec
            new = 0.008
        }
    }
    return new
}

func checkDownsample(val: Float) -> Float {
    var v = val
    v = min(v, 1.0)
    v = max(v, 0.001)
    return v
}

struct VPToolbarView: View {
    @State var extractValue: Double = 1.0
    @State var extractUnit: ExtractionUnit = .second
    @State var downsampleFactor: Float = 1.0
    @State var faceModel: FaceModel = .Native
    
    @State private var frameHint = ""
    
    let toolbarMinHeight: CGFloat = 32, toolbarMinWidth: CGFloat = 760
    let padding: CGFloat = 20
    
    let context: VideoPreview?
    
    var body: some View {
        HStack {
            Text("Analyze every:")
            
            TextField("", value: $extractValue, format: .number)
                .frame(width: 48)
                .onSubmit {
                    extractValue = checkFrameExtractValue(val: extractValue, uni: extractUnit)
                }
            
            Picker("", selection: $extractUnit) {
                ForEach(ExtractionUnit.allCases, id: \.self) {type in
                    Text(getUnitName(unit: type))
                }
            }
            .pickerStyle(.menu)
            .frame(width: 86, alignment: .leading)
            .padding(.leading, -12)
            .padding(.trailing, 12)
            .onSubmit {
                extractValue = checkFrameExtractValue(val: extractValue, uni: extractUnit)
            }
            
            Text("Downsample:")
            TextField("", value: $downsampleFactor, format: .percent)
                .frame(width: 48)
                .onSubmit {
                    downsampleFactor = checkDownsample(val: checkDownsample(val: downsampleFactor))
                }
                .padding(.trailing, 12)
                .padding(.leading, -6)
            
            Text("Model:")
            Picker("", selection: $faceModel) {
                ForEach(FaceModel.allCases, id: \.self) {type in
                    Text(getUnitName(unit: type))
                }
            }
            .pickerStyle(.menu)
            .frame(width: 86, alignment: .leading)
            .padding(.leading, -12)
            .padding(.trailing, 12)
            .onSubmit {
                extractValue = checkFrameExtractValue(val: extractValue, uni: extractUnit)
            }
            
            Button(action: {getFrameSequence(vp: context!, vt: self)}, label: {
                Text("Process")
            })
            .controlSize(.large)
            .padding(.horizontal, 5)
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            
            Button(action: {
                context?.context!.state = 0
            }, label: {
                Text("Back ")
            })
            .controlSize(.large)
            .padding(.horizontal, 5)
        }
        .frame(minWidth: toolbarMinWidth, maxWidth: .infinity, minHeight: toolbarMinHeight, maxHeight: toolbarMinHeight, alignment: .bottom)
        .padding(.bottom, padding)
        .background(FileImporter.toolbarColor)
    }
}
