//
//  FaceAttribute.swift
//  FaceCluster
//
//  Created by El-Mundo on 18/06/2024.
//

import Foundation

let FA_PreservedFields: [String] = [
    "Face Box", "Confidence", "Landmarks", "Face Rotation",
    "Cluster", "Frame", "Path", "Deactivated"
]

struct SavableAttribute: Codable {
    var name: String
    let type: AttributeType
    /// For vector
    let dimensions: Int?
}

protocol FaceAttribute: Codable {
    associatedtype type
    var value: type {get set}
    var key: String {get set}
    
    mutating func fromString(string: String) -> Bool
    func toString() -> String
}

enum AttributeType: Codable, CaseIterable {
    case Point
    case Integer
    case Decimal
    case Vector
    case IntVector
    case String
}

struct FacePoint: FaceAttribute {
    typealias type = DoublePoint
    var key: String
    var value: DoublePoint
    
    init(_ value: DoublePoint, for key: String) {
        self.value = value
        self.key = key
    }
    
    mutating func fromString(string: String) -> Bool {
        let content = string.replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "").replacingOccurrences(of: " ", with: "")
        let axis = content.split(separator: ",")
        if(axis.count < 2) {
            return false
        } else {
            guard let x = Double(axis[0]), let y = Double(axis[1]) else {
                return false
            }
            self.value = DoublePoint(x: x, y: y)
            return true
        }
    }
    
    func toString() -> String {
        return "(\(value.x), \(value.y))"
    }
}

struct FaceVector: FaceAttribute {
    typealias type = [Double]
    var value: [Double]
    var key: String
    //var names: [String]
    
    init(_ value: [Double], for key: String/*, names: [String]?*/) {
        self.value = value
        self.key = key
        /*if let n = names {
            self.names = n
        } else {
            self.names = [String]()
            for i in 0..<value.count {
                self.names.append("#\(i)")
            }
        }*/
    }
    
    
    mutating func fromString(string: String) -> Bool {
        let content = string.replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "").replacingOccurrences(of: " ", with: "")
        let values = content.split(separator: ",")
        var newValues = [Double]()
        for value in values {
            guard let v = Double(value) else {
                return false
            }
            newValues.append(v)
        }
        self.value = newValues
        return true
    }
    
    func toString() -> String {
        var string = "["
        for v in value {
            string.append("\(v), ")
        }
        if(string.hasSuffix(", ")) {
            string.removeLast()
            string.removeLast()
        }
        string.append("]")
        return string
    }
}

struct FaceIntegerVector: FaceAttribute {
    typealias type = [Int]
    var value: [Int]
    var key: String
    //var names: [String]
    
    init(_ value: [Int], for key: String/*, names: [String]*/) {
        self.value = value
        self.key = key
        //self.names = names
    }
    
    mutating func fromString(string: String) -> Bool {
        let content = string.replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "").replacingOccurrences(of: " ", with: "")
        let values = content.split(separator: ",")
        var newValues = [Int]()
        for value in values {
            guard let v = Int(value) else {
                return false
            }
            newValues.append(v)
        }
        self.value = newValues
        return true
    }
    
    func toString() -> String {
        var string = "["
        for v in value {
            string.append("\(v), ")
        }
        if(string.hasSuffix(", ")) {
            string.removeLast()
            string.removeLast()
        }
        string.append("]")
        return string
    }
}

struct FaceInteger: FaceAttribute {
    typealias type = Int
    var value: Int
    var key: String
    
    init(_ value: Int, for key: String) {
        self.value = value
        self.key = key
    }
    
    mutating func fromString(string: String) -> Bool {
        guard let value = Int(string) else {
            return false
        }
        self.value = value
        return true
    }
    
    func toString() -> String {
        return "\(value)"
    }
}

struct FaceDecimal: FaceAttribute {
    typealias type = Double
    var value: Double
    var key: String
    
    init(_ value: Double, for key: String) {
        self.value = value
        self.key = key
    }
    
    mutating func fromString(string: String) -> Bool {
        guard let value = Double(string) else {
            return false
        }
        self.value = value
        return true
    }
    
    func toString() -> String {
        return "\(value)"
    }
}

struct FaceString: FaceAttribute {
    typealias type = String
    var value: String
    var key: String
    
    init(_ value: String, for key: String) {
        self.value = value
        self.key = key
    }
    
    mutating func fromString(string: String) -> Bool {
        self.value = string
        return true
    }
    
    func toString() -> String {
        return self.value
    }
}

func getFaceAttributeTypeName(type: AttributeType) -> String {
    if(type == .Point) {
        return "Point"
    } else if(type == .Decimal) {
        return "Decimal"
    } else if(type == .IntVector) {
        return "Integer Vector"
    } else if(type == .Vector) {
        return "Vector"
    } else if(type == .Integer) {
        return "Integer"
    } else if(type == .String) {
        return "String"
    }
    return ""
}

func getFaceAttributeTypeFromName(name: String) -> AttributeType? {
    let n = name.lowercased()
    if(n == "point") {
        return .Point
    } else if(n == "decimal") {
        return .Decimal
    } else if(n == "integer vector") {
        return .IntVector
    } else if(n == "vector") {
        return .Vector
    } else if(n == "integer") {
        return .Integer
    } else if(n == "string") {
        return .String
    } else {
        return nil
    }
}

func getFaceAttributeType(type: AttributeType) -> any FaceAttribute.Type {
    if(type == .Point) {
        return FacePoint.self
    } else if(type == .Decimal) {
        return FaceDecimal.self
    } else if(type == .IntVector) {
        return FaceIntegerVector.self
    } else if(type == .Vector) {
        return FaceVector.self
    } else if(type == .Integer) {
        return FaceInteger.self
    } else {
        return FaceString.self
    }
}

func decodeStringAsAttribute(as type: AttributeType, _ content: String, for key: String) -> (Bool, any FaceAttribute) {
    if(type == .Point) {
        var p = FacePoint(DoublePoint(x: 0, y: 0), for: key)
        let r = p.fromString(string: content)
        return (r, p)
    } else if(type == .Decimal) {
        var p = FaceDecimal(0.0, for: key)
        let r = p.fromString(string: content)
        return (r, p)
    } else if(type == .IntVector) {
        var p = FaceIntegerVector([], for: key)
        let r = p.fromString(string: content)
        return (r, p)
    } else if(type == .Vector) {
        var p = FaceVector([], for: key)
        let r = p.fromString(string: content)
        return (r, p)
    } else if(type == .Integer) {
        var p = FaceInteger(0, for: key)
        let r = p.fromString(string: content)
        return (r, p)
    } else {
        var p = FaceString("", for: key)
        let r = p.fromString(string: content)
        return (r, p)
    }
}

class SavableFaceAttribute: NSObject, NSSecureCoding {
    static var supportsSecureCoding: Bool { return true }
    var value: Any
    var type: AttributeType
    var key: String
    
    let vKey = "value", kKey = "key", tKey = "type"
    
    init(a: any FaceAttribute, type: AttributeType) {
        self.value = a.value
        self.type = type
        self.key = a.key
    }
    
    func encode(with coder: NSCoder) {
        if(type == .Point) {
            let p = value as! DoublePoint
            let array = NSPoint(x: p.x, y: p.y)
            coder.encode(array, forKey: vKey)
        } else if(type == .Decimal) {
            coder.encode(value as? Double, forKey: vKey)
        } else if(type == .IntVector) {
            coder.encode(value as? NSArray, forKey: vKey)
        } else if(type == .Vector) {
            coder.encode(value as? NSArray, forKey: vKey)
        } else if(type == .Integer) {
            coder.encode(value as? Int, forKey: vKey)
        } else if(type == .String) {
            coder.encode(value as? NSString, forKey: vKey)
        }
        coder.encode(self.typeToCode() as NSInteger, forKey: tKey)
        coder.encode(key as NSString, forKey: kKey)
    }
    
    required init?(coder: NSCoder) {
        let t = coder.decodeInteger(forKey: tKey)
        self.key = coder.decodeObject(of: NSString.self, forKey: kKey)! as String
        self.type = SavableFaceAttribute.codeToType(i: t)
        if(type == .Point) {
            let value = coder.decodePoint(forKey: vKey)
            self.value = DoublePoint(x: value.x, y: value.y)
        } else if(type == .Decimal) {
            self.value = coder.decodeDouble(forKey: vKey)
        } else if(type == .IntVector) {
            self.value = coder.decodeObject(forKey: vKey) as! [Int]
        } else if(type == .Vector) {
            self.value = coder.decodeObject(forKey: vKey) as! [Double]
        } else if(type == .Integer) {
            self.value = coder.decodeInteger(forKey: vKey)
        } else if(type == .String) {
            self.value = coder.decodeObject(of: NSString.self, forKey: vKey) as Any
        } else {
            self.value = 0 as Any
        }
    }
    
    private func typeToCode() -> Int {
        if(type == .Point) {
            return 0
        } else if(type == .Decimal) {
            return 1
        } else if(type == .IntVector) {
            return 2
        } else if(type == .Vector) {
            return 3
        } else if(type == .Integer) {
            return 4
        } else if(type == .String) {
            return 5
        }
        return 5
    }
    
    private static func codeToType(i: Int) -> AttributeType {
        if(i == 0) {
            return .Point
        } else if(i == 1) {
            return .Decimal
        } else if(i == 2) {
            return .IntVector
        } else if(i == 3) {
            return .Vector
        } else if(i == 4) {
            return .Integer
        } else if(i == 5) {
            return .String
        }
        return .String
    }
}
