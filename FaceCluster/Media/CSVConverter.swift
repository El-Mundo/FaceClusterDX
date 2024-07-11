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
        return "\"" + noQuote + "\""
    }
    
    func revertCSVString(csvString: String) -> String {
        let withQuote = csvString.replacingOccurrences(of: "\\“", with: "\"")
        let withSlash = withQuote.replacingOccurrences(of: "\\\\", with: "\\")
        return withSlash
    }
    
    private func getNetworkAttributes(network: FaceNetwork) -> String {
        var string = ""
        var string2 = ""
        
        string.append(FA_PreservedFields[5] + ",")
        string.append(FA_PreservedFields[0] + ",")
        string.append(FA_PreservedFields[1] + ",")
        string.append(FA_PreservedFields[3] + ",")
        string.append(FA_PreservedFields[6] + ",")
        string.append(FA_PreservedFields[4] + ",")
        
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
    
    func converteNetworkFull(_ network: FaceNetwork, save: URL) {
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
        } catch {
            print("Error creating file")
        }
    }
    
    func generateEmptyTemplateForNetwork(_ network: FaceNetwork, save: URL) {
        var con = ""
        con.append(FA_PreservedFields[6])
        con.append(",\nPreserved,\n")
        
        for face in network.faces {
            con.append(getCSVString(string: "faces/" + (face.path?.lastPathComponent ?? "")) + ",\n")
        }
        if(con.hasSuffix("\n")) {
            con.remove(at: con.lastIndex(of: "\n")!)
        }
        
        do {
            try con.write(to: save, atomically: true, encoding: .utf8)
        } catch {
            print("Error creating file")
        }
    }
    
    func generateSampleTemplateForNetwork(_ network: FaceNetwork, save: URL) {
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
            con.append(getCSVString(string: "faces/" + (face.path?.lastPathComponent ?? "")) + sample + "\n")
        }
        if(con.hasSuffix("\n")) {
            con.remove(at: con.lastIndex(of: "\n")!)
        }
        
        do {
            try con.write(to: save, atomically: true, encoding: .utf8)
        } catch {
            print("Error creating file")
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
}
