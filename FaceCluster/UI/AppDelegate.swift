//
//  AppDelegate.swift
//  FaceCluster
//
//  Created by El-Mundo on 01/06/2024.
//

import Foundation
import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    static var workspace: URL = getDefaultWorkspaceURL()
    private static let userDefaultKey = "FaceClusterToolkit-Workspace"
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialise GPU environment
        let _ = GPUManager()
        
        if let workspaceURL = UserDefaults.standard.url(forKey: AppDelegate.userDefaultKey) {
            AppDelegate.workspace = workspaceURL
        } else {
            AppDelegate.updateWorkspaceURL(newURL: AppDelegate.getDefaultWorkspaceURL())
        }
        
        if(!AppDelegate.checkIfDirectoryExists(url: AppDelegate.workspace)) {
            print("Creating workspace")
            createDirectory(dir: AppDelegate.workspace)
        }
    }
    
    private static func updateWorkspaceURL(newURL: URL) {
        AppDelegate.workspace = newURL
        UserDefaults.standard.set(newURL, forKey: userDefaultKey)
    }
    
    private static func getDefaultWorkspaceURL() -> URL {
        return URL.documentsDirectory.appending(path: "Face Cluster Toolkit/")
    }
    
    private func createDirectory(dir: URL) {
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        } catch let error as NSError {
            NSLog("Unable to create directory \(error.debugDescription)")
        }
    }
    
    public static func checkIfDirectoryExists(url: URL) -> Bool {
        do {
            return (try url.resourceValues(forKeys: [URLResourceKey.isDirectoryKey]).isDirectory ?? false)
        } catch {
            //print(error.localizedDescription)
            return false
        }
    }
    
    public static func getDateString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd(HH-mm-ss)"
        let currentTime = Date.now
        let formattedTime = dateFormatter.string(from: currentTime)
        return formattedTime
    }
    
}

