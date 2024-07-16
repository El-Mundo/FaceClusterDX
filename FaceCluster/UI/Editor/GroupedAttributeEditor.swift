//
//  GroupedAttributeEditor.swift
//  FaceCluster
//
//  Created by El-Mundo on 15/07/2024.
//

import SwiftUI

class GroupedAttributeEditor {
    let network: FaceNetwork
    
    init(network: FaceNetwork) {
        self.network = network
    }
    
    struct GroupedEditorPanel: View {
        @State var attribute: String = "A"
        @State var attributeType: AttributeType = defaultType
        @State var action: CommandType = .assignConstant
        @State var constant: Double = 0
        @State var attributeDimension: Int = 1
        @State var command: String = ""
        @State var parameter: Int = 0
        @State var calculation: CalculateAction = .add
        @State var dimension: Int = -1
        let network: FaceNetwork?
        let faces: [TableFace]
        let editor: GroupedAttributeEditor?
        static let defaultType: AttributeType = .Decimal
        let context: FaceNetworkTable?
        let preservedNumberFields = [0, 1, 3]
        
        var body : some View {
            VStack {
                Text("Edit Multple Faces").font(.headline).padding(.vertical, 12)
                HStack {
                    Text("Attribute:")
                    Picker("", selection: $attribute) {
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
                    .onChange(of: attribute, {
                        if(network != nil) {
                            dimension = -1
                            let n = network!.attributes.first(where: { return $0.name == attribute })
                            attributeType = n?.type ?? GroupedAttributeEditor.GroupedEditorPanel.defaultType
                            
                            if(attributeType == .Vector || attributeType == .IntVector) {
                                attributeDimension = n?.dimensions ?? 1
                            } else {
                                attributeDimension = -1
                            }
                        }
                        parameter = 0
                        if(attributeType != .String && action == .makeString) {
                            action = .assignConstant
                        } else if(attributeType == .String && (action == .calculate || action == .parseType)) {
                            action = .assignConstant
                        }
                        if(attributeType != .Decimal &&  attributeType != .Integer) {
                            if(action == .calculate) {
                                action = .assignConstant
                            }
                        }
                    })
                }
                .frame(width: 256)
                
                HStack {
                    Text("Action:")
                    Picker("", selection: $action) {
                        Text("Assign Constant").tag(CommandType.assignConstant)
                        if(attributeType != .String) {
                            Text("Parse Variable").tag(CommandType.parseType)
                            if(attributeType == .Decimal || attributeType == .Integer) {
                                Text("Calculate").tag(CommandType.calculate)
                            }
                        }/* else {
                            Text("Make String from").tag(CommandType.makeString)
                        }*/
                    }
                    .pickerStyle(.menu)
                    .frame(width: 192)
                }
                .frame(width: 256).padding(.leading, 16)
                
                Text("Writing to type: \(getFaceAttributeTypeName(type: attributeType))").padding(.top, 6)
            }
            .onAppear() {
                if(network != nil) {
                    attribute = network?.attributes.first?.name ?? ""
                }
            }
            .frame(width: 480)
            Divider()
            
            if(action == .assignConstant) {
                let o = attributeType == .Vector || attributeType == .IntVector
                HStack {
                    Text("Assigning:")
                    TextField((dimension > -1) ? (attributeType == .Vector ? getTipForType(.Decimal) : getTipForType(.Integer)) : getTipForType(attributeType), text: $command)
                        .frame(width: 256)
                }.padding(o ? .top : .vertical, 12)
                
                if(o) {
                    HStack {
                        Text("To Dimension:")
                        Picker("", selection: $dimension) {
                            Text("All").tag(-1)
                            ForEach(0..<attributeDimension, id: \.self) { i in
                                Text(String(i)).tag(i)
                            }
                        }
                            .frame(width: 220)
                    }.padding(.bottom, 12)
                }
            } else if(action == .makeString) {
                HStack {
                    Text("Format:")
                    TextField("Use $(NAME) to include variables. Eg \"This face is at $(Position)\".", text: $command, axis: .vertical)
                        .frame(width: 450)
                }.padding(.top, 12)
            } else if(action == .parseType) {
                VStack {
                    let isVec = attributeType == .Vector || attributeType == .IntVector
                    let isP = attributeType == .Point
                    if(isVec) {
                        HStack {
                            Text("Write to dimension:")
                            Picker("", selection: $dimension) {
                                ForEach(0..<attributeDimension, id: \.self) {
                                    i in
                                    Text(String(describing: i)).tag(i)
                                }
                            }
                            .frame(width: 256)
                        }.onAppear() {
                            dimension = 0
                        }
                    } else if(isP) {
                        HStack {
                            Text("Write to:")
                            Picker("", selection: $dimension) {
                                Text("x").tag(0)
                                Text("y").tag(1)
                            }
                        }
                        .onAppear() {
                            dimension = 0
                        }
                        .frame(width: 256)
                    } else {
                        Text("Writing to \(attribute)")
                            .onAppear() {
                                dimension = -1
                            }
                    }
                    
                    HStack {
                        Text("From:")
                        Picker("", selection: $command) {
                            ForEach(preservedNumberFields, id: \.self) {
                                i in
                                Text(FA_PreservedFields[i]).tag(FA_PreservedFields[i])
                            }
                            if(network != nil) {
                                ForEach(network!.attributes, id: \.name) {
                                    a in
                                    if(a.type != .String) {
                                        Text(a.name).tag(a.name)
                                    }
                                }
                            } else {
                                ForEach(["A", "B", "C"], id: \.self) {
                                    a in
                                    Text(a).tag(a)
                                }
                            }
                        }
                    }.frame(width: 240).padding(.leading, 16)
                    
                    if let c = network?.attributes.first(where: { $0.name == command }) {
                        let srcIsVec = c.type == .Vector || c.type == .IntVector
                        let srcIsP = c.type == .Point
                        
                        if(srcIsVec) {
                            let dim = c.dimensions ?? 0
                            HStack {
                                Text("Read from dimension:")
                                Picker("", selection: $parameter) {
                                    ForEach(0..<dim, id: \.self) {
                                        i in
                                        Text(String(describing: i)).tag(i)
                                    }
                                }
                                .frame(width: 256)
                            }
                        } else if(srcIsP) {
                            HStack {
                                Text("Read from:")
                                Picker("", selection: $parameter) {
                                    Text("x").tag(0)
                                    Text("y").tag(1)
                                }
                            }
                            .frame(width: 256)
                        }
                    } else if(FA_PreservedFields[0] == (command)) {
                        HStack {
                            Text("Read from:")
                            Picker("", selection: $parameter) {
                                Text("x").tag(0)
                                Text("y").tag(1)
                                Text("width").tag(2)
                                Text("height").tag(3)
                            }
                            .frame(width: 256)
                        }
                    } else if(FA_PreservedFields[3] == (command)) {
                        HStack {
                            Text("Read from:")
                            Picker("", selection: $parameter) {
                                Text("x").tag(0)
                                Text("y").tag(1)
                                Text("z").tag(2)
                            }
                            .frame(width: 256)
                        }
                    }/* else if(network == nil) {
                        HStack {
                            Text("Read from:")
                            Picker("", selection: $parameter) {
                                Text("x").tag(0)
                                Text("y").tag(1)
                            }
                        }
                        .frame(width: 256)
                    }*/
                    
                }
                .onChange(of: command, {
                    parameter = 0
                })
                .padding(.vertical, 12)
            } else if(self.action == .calculate) {
                HStack {
                    Text("Calculation:")
                    Picker("", selection: $calculation) {
                        ForEach(CalculateAction.allCases, id: \.self) {
                            c in
                            Text(String(describing: c)).tag(c)
                        }
                    }.frame(width: 90)
                }
                
                HStack {
                    Text("With:")
                    Picker("", selection: $command) {
                        Text("Constant").tag("")
                        ForEach(preservedNumberFields, id: \.self) {
                            i in
                            Text(FA_PreservedFields[i]).tag(FA_PreservedFields[i])
                        }
                        if(network != nil) {
                            ForEach(network!.attributes, id: \.name) {
                                a in
                                if(a.type != .String) {
                                    Text(a.name).tag(a.name)
                                }
                            }
                        }
                    }.frame(width: 180)
                    
                    if let c = network?.attributes.first(where: { $0.name == command }) {
                        let srcIsVec = c.type == .Vector || c.type == .IntVector
                        let srcIsP = c.type == .Point
                        
                        if(srcIsVec) {
                            let dim = c.dimensions ?? 0
                            HStack {
                                Text("Value:")
                                Picker("", selection: $dimension) {
                                    ForEach(0..<dim, id: \.self) {
                                        i in
                                        Text(String(describing: i)).tag(i)
                                    }
                                }
                                .frame(width: 128)
                            }
                        } else if(srcIsP) {
                            HStack {
                                Text("Value:")
                                Picker("", selection: $dimension) {
                                    Text("x").tag(0)
                                    Text("y").tag(1)
                                }
                            }
                            .frame(width: 128)
                        }
                    } else if(FA_PreservedFields[0] == (command)) {
                        HStack {
                            Text("Value:")
                            Picker("", selection: $dimension) {
                                Text("x").tag(0)
                                Text("y").tag(1)
                                Text("width").tag(2)
                                Text("height").tag(3)
                            }
                            .frame(width: 128)
                        }
                    } else if(FA_PreservedFields[3] == (command)) {
                        HStack {
                            Text("Value:")
                            Picker("", selection: $dimension) {
                                Text("x").tag(0)
                                Text("y").tag(1)
                                Text("z").tag(2)
                            }
                            .frame(width: 128)
                        }
                    } else if(command.isEmpty) {
                        HStack {
                            Text("Value:")
                            TextField("", value: $constant, format: FloatingPointFormatStyle())
                                .frame(width: 128)
                        }
                    }
                }
                .onChange(of: command, {
                    dimension = 0
                })
            }
            
            Divider()
            HStack {
                Button("Cancel") {
                    context?.showGroupEditor = false
                }
                
                Button("Process") {
                    let cmd = GroupEditingCommand(type: action, command: command, targetAttribute: attribute, dimension: dimension, parameter: parameter, calculation: calculation)
                    editor?.performCommand(faces: faces, command: cmd, totalDimensions: attributeDimension, calcConstant: constant)
                    context?.showGroupEditor = false
                    context?.context.forceResetTable.toggle()
                }.buttonStyle(.borderedProminent).tint(.blue)
            }.controlSize(.large).padding(.vertical, 24)
        }
        
        private func getTipForType(_ type: AttributeType) -> String {
            switch type {
            case .Decimal:
                return "A deicmal, eg 0.01"
            case .IntVector:
                return "An integer vector, eg [0, 1, 2]"
            case .Vector:
                return "A decimal vector, eg [0.0, 0.5, 1.0]"
            case .Integer:
                return "An integer, eg 1"
            case .Point:
                return "A point, eg (0, 0)"
            case .String:
                return "A text string"
            }
        }
    }
    
    enum CalculateAction: CaseIterable {
        case add
        case minus
        case multiply
        case divide
        case log
        case power
    }
    
    enum CommandType {
        case makeString
        case calculate
        case assignConstant
        case parseType
    }
    
    struct GroupEditingCommand {
        let type: CommandType
        let command: String
        let targetAttribute: String
        let dimension: Int
        let parameter: Int
        let calculation: CalculateAction
    }
    
    private func performCalculateCommandOn(_ face: Face, command: GroupEditingCommand, realType: AttributeType, sourceType: AttributeType, constant: Double) -> Bool {
        let left: Double
        
        if(realType == .Integer) {
            guard let target = face.attributes[command.targetAttribute] as? FaceInteger else { return false }
            left = Double(target.value)
        } else {
            guard let target = face.attributes[command.targetAttribute] as? FaceDecimal else { return false }
            left = target.value
        }
        
        let right: Double
        if(command.command.isEmpty) {
            right = constant
        } else if(command.command == FA_PreservedFields[0]) {
            right = face.detectedAttributes.box[command.dimension]
        } else if(command.command == FA_PreservedFields[1]) {
            right = face.detectedAttributes.conf
        } else if(command.command == FA_PreservedFields[3]) {
            let lmk = face.detectedAttributes.landmarks
            let rot = lmk[lmk.count - 1]
            let i = command.dimension >= 2
            right = command.dimension % 2 == 0 ? rot[i ? 1 : 0].x : rot[i ? 1 : 0].y
        } else if(sourceType == .Decimal) {
            guard let att = (face.attributes[command.command] as? FaceDecimal)?.value else { return false }
            right = att
        } else if(sourceType == .Integer) {
            guard let att = (face.attributes[command.command] as? FaceInteger)?.value else { return false }
            right = Double(att)
        } else if(sourceType == .Vector) {
            guard let att = (face.attributes[command.command] as? FaceVector)?.value else { return false }
            right = att[command.dimension]
        } else if(sourceType == .IntVector) {
            guard let att = (face.attributes[command.command] as? FaceIntegerVector)?.value else { return false }
            right = Double(att[command.dimension])
        } else if(sourceType == .Point) {
            guard let att = (face.attributes[command.command] as? FacePoint)?.value else { return false }
            right = command.dimension == 0 ? att.x : att.y
        } else {
            return false
        }
        
        let output: Double
        if(command.calculation == .add) {
            output = left + right
        } else if(command.calculation == .minus) {
            output = left - right
        } else if(command.calculation == .divide) {
            output = left / right
        } else if(command.calculation == .multiply) {
            output = left * right
        } else if(command.calculation == .log) {
            if(right < 1) { return false }
            output = nthRoot(of: left, root: Int(right)) ?? 1
        } else if(command.calculation == .power) {
            if(right < 1) { return false }
            output = pow(left, right)
        } else {
            output = left
        }
        
        if(realType == .Decimal) {
            face.forceUpdateAttribute(key: command.targetAttribute, value: FaceDecimal(output, for: command.targetAttribute))
        } else if(realType == .Integer) {
            face.forceUpdateAttribute(key: command.targetAttribute, value: FaceInteger(Int(output), for: command.targetAttribute))
        }
        
        return true
    }
    
    private func nthRoot(of number: Double, root: Int) -> Double? {
        guard root != 0 else {
            print("Root cannot be zero.")
            return nil
        }
        return pow(number, 1.0 / Double(root))
    }
    
    private func parse(_ face: Face, command: GroupEditingCommand, sourceType: AttributeType, targetType: AttributeType) -> Bool {
        let from = command.command
        let to = command.targetAttribute
        if(sourceType == targetType) {
            guard let source = face.attributes[from] else {
                return false
            }
            var copiedSource = source
            copiedSource.key = to
            face.forceUpdateAttribute(key: to, value: copiedSource)
        } else if(sourceType == .Vector || sourceType == .Point || sourceType == .Decimal) {
            let copiedDouble: Double
            
            if(command.command == FA_PreservedFields[0]) {
                let box = face.detectedAttributes.box
                if(command.parameter < 4) {
                    copiedDouble = box[command.parameter]
                } else {
                    return false
                }
            } else if(command.command == FA_PreservedFields[1]) {
                let conf = face.detectedAttributes.conf
                copiedDouble = conf
            }  else if(command.command == FA_PreservedFields[3]) {
                let lmk = face.detectedAttributes.landmarks
                let rot = lmk[lmk.count-1]
                if(command.parameter % 2 == 0) {
                    copiedDouble = rot[command.parameter > 1 ? 1 : 0].x
                } else {
                    copiedDouble = rot[command.parameter > 1 ? 1 : 0].y
                }
            } else if(sourceType == .Vector) {
                guard let source = (face.attributes[from] as? FaceVector)?.value else {
                    return false
                }
                let sIndex = command.parameter
                if(sIndex > source.count - 1) {
                    return false
                }
                copiedDouble = source[sIndex]
            } else if(sourceType == .Point) {
                guard let source = (face.attributes[from] as? FacePoint)?.value else {
                    return false
                }
                let sIndex = command.parameter
                copiedDouble = sIndex == 0 ? source.x : source.y
            } else {
                guard let source = (face.attributes[from] as? FaceDecimal)?.value else {
                    return false
                }
                copiedDouble = source
            }
            
            if(targetType == .Decimal) {
                face.forceUpdateAttribute(key: to, value: FaceDecimal(copiedDouble, for: to))
            } else if(targetType == .Integer) {
                face.forceUpdateAttribute(key: to, value: FaceInteger(Int(copiedDouble), for: to))
            } else if(targetType == .Point) {
                if var copiedPoint = face.attributes[to] as? FacePoint {
                    if(command.dimension == 0) {
                        copiedPoint.value = DoublePoint(x: copiedDouble, y: copiedPoint.value.y)
                    } else {
                        copiedPoint.value = DoublePoint(x: copiedPoint.value.x, y: copiedDouble)
                    }
                    face.forceUpdateAttribute(key: to, value: copiedPoint)
                } else {
                    face.forceUpdateAttribute(key: to, value: FacePoint(DoublePoint(x: command.dimension == 0 ? copiedDouble : 0, y: command.dimension == 0 ? 0 : copiedDouble), for: to))
                }
            } else if(targetType == .Vector) {
                if var copiedArray = (face.attributes[to] as? FaceVector) {
                    if(command.dimension < copiedArray.value.count) {
                        copiedArray.value[command.dimension] = copiedDouble
                        face.forceUpdateAttribute(key: to, value: copiedArray)
                    }
                }
            } else if(targetType == .IntVector) {
                if var copiedArray = (face.attributes[to] as? FaceIntegerVector) {
                    if(command.dimension < copiedArray.value.count) {
                        copiedArray.value[command.dimension] = Int(copiedDouble)
                        face.forceUpdateAttribute(key: to, value: copiedArray)
                    }
                }
            }
        } else if(sourceType == .IntVector || sourceType == .Integer) {
            let copiedInt: Int
            
            if(sourceType == .IntVector) {
                guard let source = (face.attributes[from] as? FaceIntegerVector)?.value else {
                    return false
                }
                let sIndex = command.parameter
                if(sIndex > source.count - 1) {
                    return false
                }
                copiedInt = source[sIndex]
            } else {
                guard let source = (face.attributes[from] as? FaceInteger)?.value else {
                    return false
                }
                copiedInt = source
            }
            
            if(targetType == .Integer) {
                face.forceUpdateAttribute(key: to, value: FaceInteger(copiedInt, for: to))
            } else if(targetType == .Decimal) {
                face.forceUpdateAttribute(key: to, value: FaceDecimal(Double(copiedInt), for: to))
            } else if(targetType == .Point) {
                if var copiedPoint = face.attributes[to] as? FacePoint {
                    if(command.dimension == 0) {
                        copiedPoint.value = DoublePoint(x: Double(copiedInt), y: copiedPoint.value.y)
                    } else {
                        copiedPoint.value = DoublePoint(x: copiedPoint.value.x, y: Double(copiedInt))
                    }
                    face.forceUpdateAttribute(key: to, value: copiedPoint)
                } else {
                    face.forceUpdateAttribute(key: to, value: FacePoint(DoublePoint(x: command.dimension == 0 ? Double(copiedInt) : 0, y: command.dimension == 0 ? 0 : Double(copiedInt)), for: to))
                }
            } else if(targetType == .IntVector) {
                if var copiedArray = (face.attributes[to] as? FaceIntegerVector) {
                    if(command.dimension < copiedArray.value.count) {
                        copiedArray.value[command.dimension] = copiedInt
                        face.forceUpdateAttribute(key: to, value: copiedArray)
                    }
                }
            } else if(targetType == .Vector) {
                if var copiedArray = (face.attributes[to] as? FaceVector) {
                    if(command.dimension < copiedArray.value.count) {
                        copiedArray.value[command.dimension] = Double(copiedInt)
                        face.forceUpdateAttribute(key: to, value: copiedArray)
                    }
                }
            }
        }
        return true
    }
    
    private func constantCommand(_ face: Face, command: GroupEditingCommand, realType: AttributeType, dimensions: Int, instance: (any FaceAttribute)?) -> Bool {
        
        let type = getFaceAttributeType(type: realType)
        
        if(dimensions < 0) {
            let parsed = face.attributes[command.targetAttribute]?.fromString(string: command.command) ?? false
            
            if(!parsed && instance != nil) {
                face.forceUpdateAttribute(for: type, key: command.targetAttribute, value: instance!)
            }
        } else {
            if(realType == .Vector) {
                guard let value = Double(command.command) else { return false }
                var array: [Double]
                if let src = face.attributes[command.targetAttribute] as? FaceVector {
                    array = src.value
                } else {
                    array = Array<Double>(repeating: 0, count: dimensions)
                }
                
                while(array.count < dimensions) {
                    array.append(0)
                }

                array[command.dimension] = value
                face.forceUpdateAttribute(for: type, key: command.targetAttribute, value: FaceVector(array, for: command.targetAttribute))
            } else if(realType == .IntVector) {
                guard let value = Int(command.command) else { return false }
                var array: [Int]
                if let src = face.attributes[command.targetAttribute] as? FaceIntegerVector {
                    array = src.value
                } else {
                    array = Array<Int>(repeating: 0, count: dimensions)
                }
                
                while(array.count < dimensions) {
                    array.append(0)
                }

                array[command.dimension] = value
                face.forceUpdateAttribute(for: type, key: command.targetAttribute, value: FaceIntegerVector(array, for: command.targetAttribute))
            }
        }
        
        return true
    }
    
    private func makeString(_ face: Face, split: [(String, String, Int)], command: GroupEditingCommand) -> Bool {
        var string = ""
        for s in split {
            let variable = s.0
            let text = s.1
            let dimension = s.2
            let part: String
            if(dimension > -1) {
                if let array = (face.attributes[variable] as? FaceVector)?.value {
                    part = String(array.count > dimension ? array[dimension] : 0)
                } else if let array = (face.attributes[variable] as? FaceIntegerVector)?.value {
                    part = String(array.count > dimension ? array[dimension] : 0)
                } else {
                    part = face.attributes[variable]?.toString() ?? ""
                }
            } else {
                if let p = stringToDecodedPreservedAttribute(face: face, string: variable, int: dimension) {
                    part = p
                } else {
                    part = face.attributes[variable]?.toString() ?? ""
                }
            }
            
            string.append(part + text)
        }
        
        face.forceUpdateAttribute(for: FaceString.self, key: command.targetAttribute, value: FaceString(string, for: command.targetAttribute))
        
        return true
    }
    
    func performCommand(faces: [TableFace], command: GroupEditingCommand, totalDimensions: Int, calcConstant: Double) {
        if(command.type == .assignConstant) {
            guard let realField = network.attributes.first(where: { $0.name == command.targetAttribute }) else { return }
            let realType = realField.type
            let assignType: AttributeType
            let newValue: (any FaceAttribute)?
            if(command.dimension > -1) {
                assignType = realType == .Vector ? .Decimal : .Integer
                newValue = getFaceAttributeFromCommand(type: assignType, command: command)
            } else {
                assignType = realType
                newValue = getFaceAttributeFromCommand(type: realType, command: command)
            }
            
            for f in faces {
                let face = f.getFaceObject()
                let _ = constantCommand(face, command: command, realType: realType, dimensions: totalDimensions, instance: newValue)
                face.updateSaveFileAtOriginalLocation()
            }
        } else if(command.type == .makeString) {
            let ss = splitIntoTupleSegments(input: command.command)
            var process = [(String, String, Int)]()
            for s in ss {
                let variable = s.0
                let text = s.1
                let out: (String, String, Int)
                if(variable.contains(".")) {
                    if let lastPoint = variable.lastIndex(of: ".") {
                        let testVector = variable[..<lastPoint]
                        var index = variable[lastPoint...]
                        index.removeFirst()
                        if let i = Int(index) {
                            out = (String( testVector ), text, i)
                        } else {
                            out = (variable, text, -1)
                        }
                    } else {
                        out = (variable, text, -1)
                    }
                } else {
                    out = (variable, text, -1)
                }
                
                process.append(out)
            }
            
            for f in faces {
                let face = f.getFaceObject()
                let _ = makeString(face, split: process, command: command)
                face.updateSaveFileAtOriginalLocation()
            }
        } else if(command.type == .parseType) {
            let s: AttributeType
            if(!FA_PreservedFields.contains(command.command)) {
                guard let source = network.attributes.first(where: { $0.name == command.command })
                else {
                    return
                }
                s = source.type
            } else {
                switch(command.command) {
                case FA_PreservedFields[0]:
                    s = .Vector
                    break
                case FA_PreservedFields[1]:
                    s = .Decimal
                    break
                case FA_PreservedFields[3]:
                    s = .Vector
                    break
                default:
                    return
                }
            }
            
            guard let target = network.attributes.first(where: { $0.name == command.targetAttribute }) else { return }
            let t = target.type
            
            for f in faces {
                let face = f.getFaceObject()
                let _ = parse(face, command: command, sourceType: s, targetType: t)
                face.updateSaveFileAtOriginalLocation()
            }
        } else {
            let s: AttributeType
            if(command.command == "") {
                s = .Decimal
            } else {
                guard let src = network.attributes.first(where: { $0.name == command.command }) else {
                    return
                }
                s = src.type
            }
            guard let tar = network.attributes.first(where: { $0.name == command.targetAttribute }) else {
                 return
            }
            
            for f in faces {
                let face = f.getFaceObject()
                let _ = performCalculateCommandOn(face, command: command, realType: tar.type, sourceType: s, constant: calcConstant)
                face.updateSaveFileAtOriginalLocation()
            }
        }
    }
    
    private func getFaceAttributeFromCommand(type: AttributeType, command: GroupEditingCommand) -> (any FaceAttribute)? {
        if(type == .Point) {
            var p = FacePoint(DoublePoint(x: 0, y: 0), for: command.targetAttribute)
            let s = p.fromString(string: command.command)
            return s ? p : nil
        } else if(type == .Decimal) {
            var d = FaceDecimal(0, for: command.targetAttribute)
            let s = d.fromString(string: command.command)
            return s ? d : nil
        } else if(type == .IntVector) {
            var p = FaceIntegerVector([], for: command.targetAttribute)
            let s = p.fromString(string: command.command)
            return s ? p : nil
        } else if(type == .Vector) {
            var p = FaceVector([], for: command.targetAttribute)
            let s = p.fromString(string: command.command)
            return s ? p : nil
        } else if(type == .Integer) {
            var p = FaceInteger(0, for: command.targetAttribute)
            let s = p.fromString(string: command.command)
            return s ? p : nil
        } else if(type == .String) {
            var p = FaceString("", for: command.targetAttribute)
            let s = p.fromString(string: command.command)
            return s ? p : nil
        }
        return nil
    }
    
    private func splitIgnoringEscaped(input: String, delimiter: String, escape: String) -> [String] {
        var result = [String]()
        var currentSegment = ""
        var isEscaped = false
        let delimiterLength = delimiter.count

        var iterator = input.makeIterator()
        while let char = iterator.next() {
            if char == "/" {
                if isEscaped {
                    currentSegment.append("/")
                    isEscaped = false
                } else {
                    isEscaped = true
                }
            } else if isEscaped && char == escape.first {
                currentSegment.append(char)
                isEscaped = false
            } else if !isEscaped && char == delimiter.first {
                let nextChars = String(input[input.index(input.startIndex, offsetBy: input.distance(from: input.startIndex, to: currentSegment.endIndex) + 1)..<input.index(input.startIndex, offsetBy: input.distance(from: input.startIndex, to: currentSegment.endIndex) + delimiterLength)])
                if nextChars == delimiter {
                    result.append(currentSegment)
                    currentSegment = ""
                    _ = nextChars.dropFirst()
                } else {
                    currentSegment.append(char)
                }
            } else {
                currentSegment.append(char)
                isEscaped = false
            }
        }

        // Append the last segment
        result.append(currentSegment)
        return result
    }

    private func splitIntoTupleSegments(input: String) -> [(String, String)] {
        // Split the input into segments by '$(' while ignoring '\$('
        let segments = splitIgnoringEscaped(input: input, delimiter: "$(", escape: "(")
        var result = [(String, String)]()

        for segment in segments {
            var isEscaped = false
            var splitFound = false
            var firstPart = ""
            var secondPart = ""
            
            for char in segment {
                if char == "/" {
                    if isEscaped {
                        if(splitFound) {
                            secondPart.append("/")
                        } else {
                            firstPart.append("/")
                        }
                        isEscaped = false
                    } else {
                        isEscaped = true
                    }
                } else if isEscaped && char == ")" {
                    if(splitFound) {
                        secondPart.append(")")
                    } else {
                        firstPart.append(")")
                    }
                    isEscaped = false
                } else if char == ")" && !isEscaped && !splitFound {
                    splitFound = true
                } else {
                    if(splitFound) {
                        secondPart.append(char)
                    } else {
                        firstPart.append(char)
                    }
                    isEscaped = false
                }
            }
            result.append((firstPart, secondPart))
        }

        return result
    }
    
    /// Returns nil if not preserved
    private func stringToDecodedPreservedAttribute(face: Face, string: String, int: Int) -> String? {
        if(!FA_PreservedFields.contains(string)) {
            return nil
        }
        
        switch(string) {
        case FA_PreservedFields[0]:
            return int < 4 ? String(face.detectedAttributes.box[int]) : ""
        case FA_PreservedFields[1]:
            return String(face.detectedAttributes.conf)
        case FA_PreservedFields[3]:
            let lmk = face.detectedAttributes.landmarks
            let rot = lmk[lmk.count - 1]
            if(int < 3) {
                if(int % 2 == 0) {
                    return String(rot[int / 2].x)
                } else {
                    return String(rot[int / 2].y)
                }
            } else {
                return ""
            }
        case FA_PreservedFields[4]:
            return face.clusterName
        case FA_PreservedFields[5]:
            return face.detectedAttributes.frameIdentifier
        case FA_PreservedFields[6]:
            return "faces/" + (face.path?.lastPathComponent ?? "")
        case FA_PreservedFields[7]:
            return face.disabled ? "TRUE" : "FALSE"
        default:
            return nil
        }
    }
}

#Preview {
    GroupedAttributeEditor.GroupedEditorPanel(network: nil, faces: [], editor: nil, context: nil)
}
