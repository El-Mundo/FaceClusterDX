//
//  CSVConverter.swift
//  FaceCluster
//
//  Created by El-Mundo on 11/07/2024.
//

import Foundation

class CSVConverter {
    func getCSVString(string: String) -> String {
        let noSlash = string.replacingOccurrences(of: "\\", with: "\\\\")
        let noQuote = noSlash.replacingOccurrences(of: "\"", with: "\\“")
        let noComma = noQuote.replacingOccurrences(of: ",", with: "\\，")
        return "\"" + noComma + "\""
    }
    
    func revertCSVString(csvString: String) -> String {
        var string = csvString
        if(csvString.hasPrefix("\"") && csvString.hasSuffix("\"") && string.count > 1) {
            string.removeFirst()
            string.removeLast()
        } else {
            string = csvString
        }
        let withQuote = string.replacingOccurrences(of: "\\“", with: "\"")
        let withComma = withQuote.replacingOccurrences(of: "\\，", with: ",")
        let withSlash = withComma.replacingOccurrences(of: "\\\\", with: "\\")
        return withSlash
    }
    
    private func getNetworkAttributes(network: FaceNetwork) -> String {
        var string = ""
        var string2 = ""
        
        string.append(getCSVString(string: FA_PreservedFields[5]) + ",")
        string.append(getCSVString(string: FA_PreservedFields[0]) + ",")
        string.append(getCSVString(string: FA_PreservedFields[1]) + ",")
        string.append(getCSVString(string: FA_PreservedFields[3]) + ",")
        string.append(getCSVString(string: FA_PreservedFields[6]) + ",")
        string.append(getCSVString(string: FA_PreservedFields[4]) + ",")
        
        string2.append("Preserved,Preserved,Preserved,Preserved,Preserved,Preserved")
        
        for attribute in network.attributes {
            string.append(getCSVString(string: attribute.name) + ",")
            string2.append("," + getFaceAttributeTypeName(type: attribute.type))
        }
        if(string.hasSuffix(",")) {
            string.remove(at: string.lastIndex(of: ",")!)
        }
        
        return string + "\n" + string2
    }
    
    private func getCSVString(tFace: TableFace) -> String {
        var text = "\(getCSVString(string: tFace.frame)),\(getCSVString(string: tFace.faceBox)),\(getCSVString(string: tFace.confidence)),\(getCSVString(string: tFace.faceRotation)),\(getCSVString(string: tFace.path)),\(getCSVString(string: tFace.cluster))"
        for attribute in tFace.attributes {
            text.append("," + getCSVString(string: attribute.content))
        }
        return text
    }
    
    func converteNetworkFull(_ network: FaceNetwork, save: URL) -> (Bool, String) {
        var con = ""
        con.append(getNetworkAttributes(network: network))
        con.append("\n")
        
        for face in network.faces {
            con.append(getCSVString(tFace: TableFace(face: face)) + "\n")
        }
        if(con.hasSuffix("\n")) {
            con.remove(at: con.lastIndex(of: "\n")!)
        }
        
        do {
            try con.write(to: save, atomically: true, encoding: .utf8)
            return (true, "")
        } catch {
            print("Error creating file")
            return (false, error.localizedDescription)
        }
    }
    
    func generateEmptyTemplateForNetwork(_ network: FaceNetwork, save: URL) -> (Bool, String) {
        var con = ""
        con.append(FA_PreservedFields[6])
        con.append(",\nPreserved,\n")
        
        for face in network.faces {
            con.append(getCSVString(string: getTableShortFacePath(face: face)) + ",\n")
        }
        if(con.hasSuffix("\n")) {
            con.remove(at: con.lastIndex(of: "\n")!)
        }
        
        do {
            try con.write(to: save, atomically: true, encoding: .utf8)
            return (true, "")
        } catch {
            print("Error creating file")
            return (false, error.localizedDescription)
        }
    }
    
    func getTableShortFacePath(face: Face) -> String {
        return "faces/" + (face.path?.lastPathComponent ?? "")
    }
    
    func generateSampleTemplateForNetwork(_ network: FaceNetwork, save: URL) -> (Bool, String) {
        var con = ""
        var field = ""
        var sample = ""
        con.append(FA_PreservedFields[6])
        field.append("Preserved")
        for fa in AttributeType.allCases {
            let name = getFaceAttributeTypeName(type: fa)
            con.append(",Sample " + name)
            field.append("," + name)
            sample.append("," + getCSVString(string: getDefault(at: fa).toString()))
        }
        con.append("\n")
        con.append(field)
        con.append("\n")
        
        for face in network.faces {
            con.append(getCSVString(string: getTableShortFacePath(face: face)) + sample + "\n")
        }
        if(con.hasSuffix("\n")) {
            con.remove(at: con.lastIndex(of: "\n")!)
        }
        
        do {
            try con.write(to: save, atomically: true, encoding: .utf8)
            return (true, "")
        } catch {
            print("Error creating file")
            return (false, error.localizedDescription)
        }
    }
    
    private func getDefault(at: AttributeType) -> any FaceAttribute {
        if(at == .Point) {
            return FacePoint(DoublePoint(x:0,y:0), for: "")
        } else if(at == .Decimal) {
            return FaceDecimal(0.0, for: "")
        } else if(at == .IntVector) {
            return FaceIntegerVector([0, 0], for: "")
        } else if(at == .Vector) {
            return FaceVector([0.0, 0.0], for: "")
        } else if(at == .Integer) {
            return FaceInteger(0, for: "")
        } else {
            return FaceString("Text", for: "")
        }
    }
    
    struct CSVLog {
        var preservedFields = [String]()
        var skippedCells = [(Int, Int)]()
        var skippedLines = [Int]()
    }
    var importLog: CSVLog?
    
    func importCSV(_ network: FaceNetwork, url: URL) -> (Bool, String) {
        importLog = CSVLog()
        guard let csv = try? String(contentsOf: url) else {
            return (false, String(localized: "Failed to read file as text."))
        }
        
        struct CSVCell {
            let value: any FaceAttribute
            let loc: Int
        }
        
        struct CSVLine {
            let cells: [CSVCell]
            let identifier: String
            let loc: Int
        }
        
        class CSVCol {
            let name: String
            let type: AttributeType
            var dim: Int
            
            init(name: String, type: AttributeType, dim: Int) {
                self.name = name
                self.type = type
                self.dim = dim
            }
        }
        
        let identifier = FA_PreservedFields[6]
        var idLoc = -1
        
        let lines = csv.split(whereSeparator: \.isNewline)
        var importedAttributes: [Int: CSVCol] = [:]
        var importedValues: [CSVLine] = []
        let err = String(localized: "Cannot import a table without the first two lines recodring attributes")
        
        if(lines.count < 2) {
            return (false, err)
        }
        
        let field = lines[0].split(separator: ",")
        let type = lines[1].split(separator: ",")
        
        if(type.count < field.count) {
            return (false, err)
        }
        
        for i in 0..<field.count {
            let newType = String(type[i])
            let newField = revertCSVString(csvString: String(field[i]))
            
            if(newType.lowercased() == "preserved") {
                if(newField == identifier) {
                    idLoc = i
                } else {
                    importLog!.preservedFields.append(newField)
                }
                continue
            }
            
            if(newField.trimmingCharacters(in: [" "]).isEmpty) {
                return (false, String(localized: "Failed to import due to empty column name at column \(i)."))
            }
            
            if(network.attributes.contains(where: {$0.name == newField})) {
                return (false, String(localized: "Cannot import the attribute name \"\(newField)\" because it conflicts with an existing attribute in the network."))
            }
            
            if(FA_PreservedFields.contains(newField)) {
                return (false, String(localized: "Cannot import an attribute with a preserved name and a non-preserved type for \"\(newType)\"."))
            }
            
            guard let t = getFaceAttributeTypeFromName(name: newType) else {
                return (false, String(localized: "Unidentifiable attribute type \"\(newType)\""))
            }
            
            importedAttributes.updateValue(CSVCol(name: String(field[i]), type: t, dim: -1), forKey: i)
        }
        
        if(idLoc < 0) {
            return (false, String(localized: "An imported table must have the identifier attribute \"\(identifier)\" as preserved type."))
        }
        
        for y in 2..<lines.count {
            let line = lines[y].split(separator: ",")
            var identifier: String?
            var cells = [CSVCell]()
            for x in 0..<line.count {
                if(x == idLoc) {
                    identifier = revertCSVString(csvString: String(line[x]))
                } else {
                    let a = line[x]
                    let rev = revertCSVString(csvString: String(a))
                    guard let type = importedAttributes[x] else {
                        continue
                    }
                    let val = decodeStringAsAttribute(as: type.type, rev, for: type.name)
                    if(val.0) {
                        cells.append(CSVCell(value: val.1, loc: x))
                        
                        if(type.type == .IntVector || type.type == .Vector) {
                            let curDim = rev.split(separator: ",").count
                            if(curDim > type.dim) {
                                type.dim = curDim
                            }
                        }
                    } else {
                        importLog!.skippedCells.append((y+1, x+1))
                    }
                }
            }
            
            guard let id = identifier else {
                importLog!.skippedLines.append(y+1)
                continue
            }
            importedValues.append(CSVLine(cells: cells, identifier: id, loc: y))
        }
        
        for attribute in importedAttributes.values {
            network.forceAppendAttribute(key: attribute.name, type: attribute.type, dimensions: attribute.dim)
        }
        for value in importedValues {
            guard let faceObj = network.faces.first(where: { getTableShortFacePath(face: $0) == value.identifier }) else {
                importLog?.skippedLines.append(value.loc+1)
                continue
            }
            
            for cell in value.cells {
                let key = importedAttributes[cell.loc]!
                let type = getFaceAttributeType(type: key.type)
                faceObj.forceUpdateAttribute(for: type, key: key.name, value: cell.value)
                faceObj.updateSaveFileAtOriginalLocation()
            }
        }
        
        return (true, String(localized: "Successfully imported \(importedAttributes.count) attribute(s) into the network, with \(importLog?.preservedFields.count ?? 0) attribute(s), \(importLog?.skippedLines.count ?? 0) line(s), and \(importLog?.skippedCells.count ?? 0) cell(s) skipped."))
    }
}
