//
//  FaceSelector.swift
//  FaceCluster
//
//  Created by El-Mundo on 13/07/2024.
//

import SwiftUI

protocol FSFilter { }

class FaceSelector {
    enum FSEmptyFilter: FSFilter {
        case empty
    }
    
    enum FSNumberFilter: FSFilter {
        case greater
        case less
        case equals
        case notEqual
        case greaterOrEquals
        case lessOrEquals
    }

    enum FSStringFilter: FSFilter {
        case equals
        case contains
        case containedBy
        case isEmpty
        case length
    }

    enum FSDataType {
        case double
        case integer
        case point
        case string
        case ignored
    }
    
    enum SpecialAttribute {
        case FaceBox
        case DetectionConfidence
        case FaceRotation
        case ClusterName
        case FrameIdentifier
        case Deactivated
        
        case VectorRealDimensions
        case WrongFormat
        case Missing
        case StringLength
        case VectorAverage
    }
    
    enum SpecialCheck: CaseIterable {
        case Value
        case Data_Integrity
        case Data_Format
    }
    
    struct FaceSelection {
        let dataType: FSDataType
        let filter: FSFilter
        let attribute: String
        let dimension: Int?
        let specialAttribute: SpecialAttribute?
        let value: Any
    }
    
    struct FaceSelectorPanel: View {
        let tableFaces: [TableFace]
        let network: FaceNetwork?
        let context: FaceNetworkTable?
        let preservedFields = [0, 1, 3, 4, 5, 7]
        let selector: FaceSelector?
        
        @State var attribute: String = "Face Box"
        @State var checkType: SpecialCheck = .Value
        @State var deselect: Bool = false
        @State var clear: Bool = false
        @State var dimension: Int = 0
        @State var numberFilter: FSNumberFilter = .equals
        @State var stringFilter: FSStringFilter = .equals
        @State var doubleValue: Double = 0
        @State var intValue: Int = 0
        @State var stringValue: String = ""
        
        var body: some View {
            VStack {
                Text("Select Faces According to Condition:").font(.headline).padding(.vertical, 12)
                HStack {
                    Text("Attribute:")
                    Picker("", selection: $attribute) {
                        ForEach(preservedFields, id: \.self) { i in
                            Text(FA_PreservedFields[i]).tag(FA_PreservedFields[i])
                        }
                        if(network != nil) {
                            ForEach(network!.attributes, id: \.name) { a in
                                Text(a.name).tag(a.name)
                            }
                        } else {
                            ForEach(["A", "B", "C"], id: \.self) { a in
                                Text(a).tag(a)
                            }
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 256)
                }
                HStack {
                    Text("Checking:")
                    Picker("", selection: $checkType) {
                        ForEach(SpecialCheck.allCases, id: \.self) { t in
                            Text(String(describing: t).replacingOccurrences(of: "_", with: " ")).tag(t)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 256)
                }.padding(.bottom, 24)
                
                Divider()
                
                if(checkType == .Value) {
                    if(attribute == FA_PreservedFields[0]) {
                        HStack {
                            Text("Value:")
                            Picker("", selection: $dimension) {
                                Text("x").tag(0 as Int)
                                Text("y").tag(1 as Int)
                                Text("width").tag(2 as Int)
                                Text("height").tag(3 as Int)
                            }.frame(width: 160)
                        }
                        NumberFilterSubpanel(context: self)
                        FloatingNumberCompareTargetSubpanel(context: self)
                    } else if(attribute == FA_PreservedFields[1]) {
                        NumberFilterSubpanel(context: self)
                        FloatingNumberCompareTargetSubpanel(context: self)
                    } else if(attribute == FA_PreservedFields[3]) {
                        HStack {
                            Text("Value:")
                            Picker("", selection: $dimension) {
                                Text("x").tag(0 as Int)
                                Text("y").tag(1 as Int)
                                Text("z").tag(2 as Int)
                            }.frame(width: 160)
                        }
                        NumberFilterSubpanel(context: self)
                        FloatingNumberCompareTargetSubpanel(context: self)
                    } else if(attribute == FA_PreservedFields[4]) {
                        StringFilterSubpanel(context: self, allowLength: false)
                        if(stringFilter != .isEmpty) { StringCompareTargetSubpanel(context: self) }
                    } else if(attribute == FA_PreservedFields[5]) {
                        StringFilterSubpanel(context: self, allowLength: false)
                        if(stringFilter != .isEmpty) { StringCompareTargetSubpanel(context: self) }
                    } else if(attribute == FA_PreservedFields[7]) {
                        HStack {
                            Text("Is:")
                            Picker("", selection: $intValue) {
                                Text("true").tag(0 as Int)
                                Text("false").tag(1 as Int)
                            }.frame(width: 160)
                        }
                    } else {
                        let realColumn = (network?.attributes.first(where: { return $0.name == attribute }))
                        let realType = realColumn?.type ?? .Vector
                        
                        if(realType == .Decimal) {
                            NumberFilterSubpanel(context: self)
                            FloatingNumberCompareTargetSubpanel(context: self)
                        } else if(realType == .Integer) {
                            NumberFilterSubpanel(context: self)
                            IntegerCompareTargetSubpanel(context: self)
                        } else if(realType == .String) {
                            StringFilterSubpanel(context: self, allowLength: true)
                            if(stringFilter == .length) {
                                NumberFilterSubpanel(context: self)
                                FloatingNumberCompareTargetSubpanel(context: self)
                            } else if(stringFilter != .isEmpty) { StringCompareTargetSubpanel(context: self) }
                        } else if(realType == .Point) {
                            HStack {
                                Text("Value:")
                                Picker("", selection: $intValue) {
                                    Text("x").tag(0 as Int)
                                    Text("y").tag(1 as Int)
                                }.frame(width: 160)
                            }
                            NumberFilterSubpanel(context: self)
                            FloatingNumberCompareTargetSubpanel(context: self)
                        } else if(realType == .Vector) {
                            VectorValuesSubpanel(context: self, dimension: realColumn?.dimensions ?? 1)
                            NumberFilterSubpanel(context: self)
                            if(dimension == -1) {
                                IntegerCompareTargetSubpanel(context: self)
                            } else {
                                FloatingNumberCompareTargetSubpanel(context: self)
                            }
                        } else if(realType == .IntVector) {
                            VectorValuesSubpanel(context: self, dimension: realColumn?.dimensions ?? 1)
                            NumberFilterSubpanel(context: self)
                            if(dimension == -1) {
                                IntegerCompareTargetSubpanel(context: self)
                            } else {
                                FloatingNumberCompareTargetSubpanel(context: self)
                            }
                        }
                    }
                    
                    Divider().onChange(of: attribute, {
                        dimension = 0
                        stringFilter = .equals
                        numberFilter = .equals
                        intValue = 0
                        doubleValue = 0
                    })
                }
                
            }.frame(width: 480)
            
            HStack {
                Toggle(isOn: $deselect, label: {
                    Text("Deselect")
                })
                .padding(.trailing, 32)
                
                Toggle(isOn: $clear, label: {
                    Text("Clear Existing Selection")
                })
            }
            
            HStack {
                Button("Cancel") {
                    context?.showCondition = false
                }.padding(.trailing, 32)
                
                Button("Process") {
                    let c: FaceSelection
                    if(checkType == .Data_Integrity) {
                        c = FaceSelection(dataType: .ignored, filter: FSEmptyFilter.empty, attribute: attribute, dimension: nil, specialAttribute: SpecialAttribute.Missing, value: -1)
                    } else if(checkType == .Data_Format) {
                        if(FA_PreservedFields.contains(attribute)) { return }
                        guard let realType = network?.attributes.first(where: { return $0.name == attribute })?.type else { return }
                        let type = selector!.faceAttributeToFSDataType(type: realType)
                        
                        c = FaceSelection(dataType: type, filter: FSEmptyFilter.empty, attribute: attribute, dimension: nil, specialAttribute: SpecialAttribute.WrongFormat, value: realType)
                    } else {
                        if(attribute == FA_PreservedFields[0]) {
                            c = FaceSelection(dataType: .double, filter: numberFilter, attribute: attribute, dimension: dimension, specialAttribute: .FaceBox, value: doubleValue)
                        } else if(attribute == FA_PreservedFields[1]) {
                            c = FaceSelection(dataType: .double, filter: numberFilter, attribute: attribute, dimension: nil, specialAttribute: .DetectionConfidence, value: doubleValue)
                        } else if(attribute == FA_PreservedFields[3]) {
                            c = FaceSelection(dataType: .double, filter: numberFilter, attribute: attribute, dimension: dimension, specialAttribute: .FaceRotation, value: doubleValue)
                        } else if(attribute == FA_PreservedFields[4]) {
                            c = FaceSelection(dataType: .string, filter: stringFilter, attribute: attribute, dimension: nil, specialAttribute: .ClusterName, value: stringValue)
                        } else if(attribute == FA_PreservedFields[5]) {
                            c = FaceSelection(dataType: .string, filter: stringFilter, attribute: attribute, dimension: nil, specialAttribute: .FrameIdentifier, value: stringValue)
                        } else if(attribute == FA_PreservedFields[7]) {
                            c = FaceSelection(dataType: .integer, filter: FSEmptyFilter.empty, attribute: attribute, dimension: nil, specialAttribute: .Deactivated, value: intValue)
                        } else {
                            let realType = (network?.attributes.first(where: { return $0.name == attribute }))?.type
                            
                            if(realType == .Decimal) {
                                c = FaceSelection(dataType: .double, filter: numberFilter, attribute: attribute, dimension: nil, specialAttribute: nil, value: doubleValue)
                            } else if(realType == .Integer) {
                                c = FaceSelection(dataType: .integer, filter: numberFilter, attribute: attribute, dimension: nil, specialAttribute: nil, value: intValue)
                            } else if(realType == .Point) {
                                c = FaceSelection(dataType: .point, filter: numberFilter, attribute: attribute, dimension: dimension, specialAttribute: nil, value: doubleValue)
                            } else if(realType == .String) {
                                if(stringFilter != .length) {
                                    c = FaceSelection(dataType: .string, filter: stringFilter, attribute: attribute, dimension: nil, specialAttribute: nil, value: stringValue)
                                } else {
                                    c = FaceSelection(dataType: .integer, filter: numberFilter, attribute: attribute, dimension: nil, specialAttribute: .StringLength, value: intValue)
                                }
                            } else if(realType == .Vector) {
                                if(dimension == -1) {
                                    c = FaceSelection(dataType: .integer, filter: numberFilter, attribute: attribute, dimension: nil, specialAttribute: .VectorRealDimensions, value: intValue)
                                } else if(dimension == -2) {
                                    c = FaceSelection(dataType: .double, filter: numberFilter, attribute: attribute, dimension: nil, specialAttribute: .VectorAverage, value: doubleValue)
                                } else {
                                    c = FaceSelection(dataType: .double, filter: numberFilter, attribute: attribute, dimension: dimension, specialAttribute: nil, value: doubleValue)
                                }
                            } else if(realType == .IntVector) {
                                if(dimension == -1) {
                                    c = FaceSelection(dataType: .integer, filter: numberFilter, attribute: attribute, dimension: nil, specialAttribute: .VectorRealDimensions, value: intValue)
                                } else if(dimension == -2) {
                                    c = FaceSelection(dataType: .integer, filter: numberFilter, attribute: attribute, dimension: nil, specialAttribute: .VectorAverage, value: intValue)
                                } else {
                                    c = FaceSelection(dataType: .integer, filter: numberFilter, attribute: attribute, dimension: dimension, specialAttribute: nil, value: intValue)
                                }
                            } else {
                                return
                            }
                        }
                    }
                    let results = selector?.filterFaces(tFaces: tableFaces, condition: c) ?? []
                    context?.appendSelection(faces: results, clearPrevious: clear, deselecting: deselect)
                    context?.showCondition = false
                }.tint(Color.blue).buttonStyle(.borderedProminent)
            }.controlSize(.large).padding(.vertical, 24)
        }
        
        private struct NumberFilterSubpanel : View {
            let context: FaceSelectorPanel
            
            var body : some View {
                HStack {
                    Text("Condition:")
                    Picker("", selection: context.$numberFilter) {
                        Text("=").tag(FSNumberFilter.equals)
                        Text("≠").tag(FSNumberFilter.notEqual)
                        Text(">").tag(FSNumberFilter.greater)
                        Text("<").tag(FSNumberFilter.less)
                        Text(">=").tag(FSNumberFilter.greaterOrEquals)
                        Text("<=").tag(FSNumberFilter.lessOrEquals)
                    }.frame(width: 160)
                }.padding(.leading, -24)
            }
        }
        
        private struct FloatingNumberCompareTargetSubpanel: View {
            let context: FaceSelectorPanel
            
            var body : some View {
                HStack {
                    Text("Compare to:").padding(.trailing, 8)
                    TextField("A deicmal number", value: context.$doubleValue, format: FloatingPointFormatStyle<Double>()).frame(width: 146)
                }.padding(.leading, -40)
            }
        }
        
        private struct IntegerCompareTargetSubpanel: View {
            let context: FaceSelectorPanel
            
            var body : some View {
                HStack {
                    Text("Compare to:").padding(.trailing, 8)
                    TextField("An integer", value: context.$intValue, format: IntegerFormatStyle()).frame(width: 146)
                }.padding(.leading, -40)
            }
        }
        
        private struct StringFilterSubpanel : View {
            let context: FaceSelectorPanel
            let allowLength: Bool
            
            var body : some View {
                HStack {
                    Text(context.stringFilter != .length ? "Condition:" : "      Value:")
                    Picker("", selection: context.$stringFilter) {
                        Text("equal to").tag(FSStringFilter.equals)
                        Text("is empty").tag(FSStringFilter.isEmpty)
                        Text("contains").tag(FSStringFilter.contains)
                        Text("is contained by").tag(FSStringFilter.containedBy)
                        if(allowLength) {
                            Text("length").tag(FSStringFilter.length)
                        }
                    }.frame(width: 160)
                }.padding(.leading, -24)
            }
        }
        
        private struct StringCompareTargetSubpanel: View {
            let context: FaceSelectorPanel
            
            var body : some View {
                HStack {
                    Text("Compare to:").padding(.trailing, 8)
                    TextField("A string (text)", text: context.$stringValue).frame(width: 146)
                }.padding(.leading, -40)
            }
        }
        
        private struct VectorValuesSubpanel: View {
            let context: FaceSelectorPanel
            let dimension: Int
            
            var body : some View {
                HStack {
                    Text("Value:")
                    Picker("", selection: context.$dimension, content: {
                        Text("real dimension count").tag(-1 as Int)
                        Text("average").tag(-2 as Int)
                        ForEach(0..<dimension, id: \.self) { i in
                            Text(String(describing: i)).tag(i)
                        }
                    }).frame(width: 160)
                }
            }
        }
    }
    
    private func filterFaces(tFaces: [TableFace], condition: FaceSelection) -> [TableFace.ID] {
        var selection = [TableFace.ID]()
        for face in tFaces {
            if(condition.specialAttribute == .Deactivated) {
                guard let value = condition.value as? Int else { return [] }
                if(face.disabled == (value == 0)) {
                    selection.append(face.id)
                }
            } else if(condition.specialAttribute == .DetectionConfidence) {
                guard let filter = condition.filter as? FSNumberFilter, let target = condition.value as? Double else { return [] }
                let confidence = face.getFaceObject().detectedAttributes.conf
                if(compare(filter: filter, value: confidence, target: target)) { selection.append(face.id) }
            } else if(condition.specialAttribute == .FaceBox) {
                guard let filter = condition.filter as? FSNumberFilter, let target = condition.value as? Double, let index = condition.dimension else { return [] }
                let value = (face.getFaceObject().detectedAttributes.box)[index]
                if(compare(filter: filter, value: value, target: target)) { selection.append(face.id) }
            } else if(condition.specialAttribute == .FaceRotation) {
                guard let filter = condition.filter as? FSNumberFilter, let target = condition.value as? Double, let index = condition.dimension else { return [] }
                let lm = face.getFaceObject().detectedAttributes.landmarks
                let rot = lm[lm.count - 1]
                let p = rot[index > 1 ? 0 : 1]
                let value = index % 2 == 0 ? p.x : p.y
                if(compare(filter: filter, value: value, target: target)) { selection.append(face.id) }
            } else if(condition.specialAttribute == .Missing) {
                if(!face.getFaceObject().attributes.keys.contains(condition.attribute)) { selection.append(face.id) }
            } else if(condition.specialAttribute == .WrongFormat) {
                guard let target = condition.value as? AttributeType else { return [] }
                guard let value = face.getFaceObject().attributes[condition.attribute] else { continue }
                if(!compareType(value: value, target: target)) { selection.append(face.id) }
            } else if(condition.specialAttribute == .StringLength) {
                guard let filter = condition.filter as? FSNumberFilter, let target = condition.value as? Int else { return [] }
                guard let value = (face.getFaceObject().attributes[condition.attribute] as? FaceString)?.value.count else { continue }
                if(compare(filter: filter, value: value, target: target)) { selection.append(face.id) }
            } else if(condition.specialAttribute == .VectorRealDimensions) {
                guard let filter = condition.filter as? FSNumberFilter, let target = condition.value as? Int else { return [] }
                let value: Int
                guard let source = face.getFaceObject().attributes[condition.attribute] else { continue }
                if(condition.dataType == .integer) {
                    guard let intArray = source as? FaceIntegerVector else { continue }
                    value = intArray.value.count
                } else if(condition.dataType == .double) {
                    guard let doubleArray = source as? FaceVector else { continue }
                    value = doubleArray.value.count
                } else { continue }
                if(compare(filter: filter, value: value, target: target)) { selection.append(face.id) }
            } else if(condition.specialAttribute == .VectorAverage) {
                guard let filter = condition.filter as? FSNumberFilter, let target = condition.value as? Double else { return [] }
                var value: Double = 0.0
                guard let source = (face.getFaceObject().attributes[condition.attribute]) else { continue }
                if(condition.dataType == .integer) {
                    guard let intArray = (source as? FaceIntegerVector)?.value else { continue }
                    var total: Int = 0
                    for int in intArray {
                        total += int
                    }
                    value = Double(total) / Double(intArray.count)
                } else if(condition.dataType == .double) {
                    guard let doubleArray = (source as? FaceVector)?.value else { continue }
                    for double in doubleArray {
                        value += double
                    }
                    value = value / Double(doubleArray.count)
                } else { continue }
                if(compare(filter: filter, value: value, target: target)) { selection.append(face.id) }
            } else if(condition.dataType == .double) {
                guard let filter = condition.filter as? FSNumberFilter, let target = condition.value as? Double else { return [] }
                if(condition.dimension == nil) {
                    guard let value = (face.getFaceObject().attributes[condition.attribute] as? FaceDecimal)?.value else { continue }
                    if(compare(filter: filter, value: value, target: target)) {
                        selection.append(face.id)
                    }
                } else {
                    guard let array = (face.getFaceObject().attributes[condition.attribute] as? FaceVector)?.value,
                          let index = condition.dimension else { continue }
                    let value: Double
                    if(array.count <= index) { value = 0; continue; }
                    else { value = array[index] }
                    
                    if(compare(filter: filter, value: value, target: target)) {
                        selection.append(face.id)
                    }
                }
            } else if(condition.dataType == .integer) {
                guard let filter = condition.filter as? FSNumberFilter, let target = condition.value as? Int else { return [] }
                if(condition.dimension == nil) {
                    guard let value = (face.getFaceObject().attributes[condition.attribute] as? FaceInteger)?.value else { continue }
                    if(compare(filter: filter, value: value, target: target)) {
                        selection.append(face.id)
                    }
                } else {
                    guard let array = (face.getFaceObject().attributes[condition.attribute] as? FaceIntegerVector)?.value,
                          let index = condition.dimension else { continue }
                    let value: Int
                    if(array.count <= index) { value = 0; continue; }
                    else { value = array[index] }
                    
                    if(compare(filter: filter, value: value, target: target)) {
                        selection.append(face.id)
                    }
                }
            } else if(condition.dataType == .string) {
                guard let filter = condition.filter as? FSStringFilter, let target = condition.value as? String else { return [] }
                let value: String
                
                if(condition.specialAttribute == .ClusterName) {
                    value = face.cluster
                } else if(condition.specialAttribute == .FrameIdentifier) {
                    value = face.frame
                } else {
                    guard let string = (face.getFaceObject().attributes[condition.attribute] as? FaceString)?.value else { continue }
                    value = string
                }
                
                if(filter == .equals) {
                    if(value == target) { selection.append(face.id) }
                } else if(filter == .containedBy) {
                    if(target.contains(value)) { selection.append(face.id) }
                } else if(filter == .contains) {
                    if(value.contains(target)) { selection.append(face.id) }
                } else if(filter == .isEmpty) {
                    if(value.isEmpty) { selection.append(face.id) }
                }
            } else if(condition.dataType == .point) {
                guard let filter = condition.filter as? FSNumberFilter, let target = condition.value as? Double, let index = condition.dimension else { return [] }
                guard let point = (face.getFaceObject().attributes[condition.attribute] as? FacePoint)?.value else { continue }
                let value: Double
                if(index == 1) { value = point.y }
                else { value = point.x }
                if(compare(filter: filter, value: value, target: target)) {
                    selection.append(face.id)
                }
            }
        }
        
        return selection
    }
    
    private func compare<T: Comparable>(filter: FSNumberFilter, value: T, target: T) -> Bool {
        if(filter == .equals) {
            return value == target
        } else if(filter == .greater) {
            return value > target
        } else if(filter == .less) {
            return value < target
        } else if(filter == .greaterOrEquals) {
            return value >= target
        } else if(filter == .lessOrEquals) {
            return value <= target
        } else if(filter == .notEqual) {
            return value != target
        }
        return false
    }
    
    private func compareType(value: any FaceAttribute, target: AttributeType) -> Bool {
        if(target == .Decimal) {
            return value is FaceDecimal
        } else if(target == .Integer) {
            return value is FaceInteger
        } else if(target == .IntVector) {
            return value is FaceIntegerVector
        } else if(target == .Vector) {
            return value is FaceVector
        } else if(target == .String) {
            return value is FaceString
        } else if(target == .Point) {
            return value is FacePoint
        }
        return false
    }
    
    private func faceAttributeToFSDataType(type: AttributeType) -> FSDataType {
        switch type {
        case .Decimal:
            return .double
        case .Vector:
            return .double
        case .Integer:
            return .integer
        case .IntVector:
            return .integer
        case .String:
            return .string
        case .Point:
            return .point
        }
    }

}

#Preview {
    FaceSelector.FaceSelectorPanel(tableFaces: [], network: nil, context: nil, selector: nil)
}
