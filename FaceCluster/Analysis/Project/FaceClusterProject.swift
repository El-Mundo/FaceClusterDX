//
//  FaceClusterProject.swift
//  FaceCluster
//
//  Created by El-Mundo on 16/07/2024.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

let faceClusterProjectFileExtension = UTType(filenameExtension: "fcproject")!

class FaceClusterProject: Codable {
    private static var instance: FaceClusterProject? = nil
    
    var activeNetwork: FaceNetwork
    
    var paths: [String] = []
    var activePath: String
    
    enum CodingKeys: String, CodingKey {
        case paths
        case activePath
    }
    
    init(firstNetwork: FaceNetwork) {
        activeNetwork = firstNetwork
        activePath = firstNetwork.savedPath.lastPathComponent
        updateActivePath()
    }
    
    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let workspace = AppDelegate.workspace
        
        self.paths = try c.decode(Array<String>.self, forKey: .paths)
        self.activePath = try c.decode(String.self, forKey: .activePath)
        let realUrl = workspace.appending(path: activePath)
        
        do {
            activeNetwork = try FaceNetwork(url: realUrl)
        } catch {
            fatalError(String(localized: "Fatal error: Cannot load the main network of this project! Error descrption: \(error.localizedDescription)"))
        }
        
        FaceClusterProject.instance = self
        MediaManager.instance?.setEditFaceNetwork(newNetwork: activeNetwork)
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(self.paths, forKey: .paths)
        try c.encode(self.activePath, forKey: .activePath)
    }
    
    private func updateActivePath() {
        activePath = activeNetwork.savedPath.lastPathComponent
        if(!paths.contains(activePath)) {
            paths.append(activePath)
        }
    }
    
    public static func getInstance() -> FaceClusterProject? {
        if(instance != nil) {
            return instance
        } else {
            if let i = MediaManager.instance?.getEditFaceNetwork() {
                instance = FaceClusterProject(firstNetwork: i)
                return instance
            } else {
                return nil
            }
        }
    }
    
    func updateActiveNetwork(activeUrl: URL) {
        if(paths.contains(activeUrl.lastPathComponent)) {
            self.activePath = activeUrl.lastPathComponent
            self.activeNetwork = try! FaceNetwork(url: activeUrl)
            MediaManager.instance?.setEditFaceNetwork(newNetwork: activeNetwork)
        }
            
    }
}

struct ProjectDocument: FileDocument {
    static var readableContentTypes: [UTType] { [UTType(filenameExtension: "fcproject")!] }

    var data: Data

    init?(project: FaceClusterProject) {
        do {
            self.data = try JSONEncoder().encode(project)
        } catch {
            return nil
        }
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: data)
    }
}
