//
//  FaceAttribute.swift
//  FaceCluster
//
//  Created by El-Mundo on 18/06/2024.
//

import Foundation

protocol FaceAttribute: Codable {
    associatedtype type
    var value: type {get set}
    var key: String {get set}
}

extension FaceAttribute {
    func toString() -> String {
        return String(describing: value)
    }
}

struct FacePoint: FaceAttribute {
    typealias type = DoublePoint
    var key: String
    var value: DoublePoint
    
    init(_ value: DoublePoint, for key: String) {
        self.value = value
        self.key = key
    }
}

struct FaceVector: FaceAttribute {
    typealias type = [Double]
    var value: [Double]
    var key: String
    var names: [String]
    
    init(_ value: [Double], for key: String, names: [String]) {
        self.value = value
        self.key = key
        self.names = names
    }
}

struct FaceIntegerVector: FaceAttribute {
    typealias type = [Int]
    var value: [Int]
    var key: String
    var names: [String]
    
    init(_ value: [Int], for key: String, names: [String]) {
        self.value = value
        self.key = key
        self.names = names
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
}

struct FaceDecimal: FaceAttribute {
    typealias type = Double
    var value: Double
    var key: String
    
    init(_ value: Double, for key: String) {
        self.value = value
        self.key = key
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
}

class SavableFaceAttribute: NSObject, NSSecureCoding {
    static var supportsSecureCoding: Bool { return true }
    var value: Any
    var type: AttributeType
    var key: String
    
    let vKey = "value", kKey = "key", tKey = "type"
    
    enum AttributeType {
        case Point
        case Integer
        case Decimal
        case Vector
        case IntVector
        case String
    }
    
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
