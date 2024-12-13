//
//  AppDelegate.swift
//  FaceCluster
//
//  Created by El-Mundo on 01/06/2024.
//

import Foundation
import AppKit
import SwiftUI

let CLUSTER_PALETTE = [
    [255, 0, 0],      // Red
    [0, 255, 0],      // Lime
    [0, 0, 255],      // Blue
    [255, 255, 0],    // Yellow
    [0, 255, 255],    // Cyan
    [255, 0, 255],    // Magenta
    [192, 192, 192],  // Silver
    [128, 128, 128],  // Gray
    [128, 0, 0],      // Maroon
    [128, 128, 0],    // Olive
    [0, 128, 0],      // Green
    [128, 0, 128],    // Purple
    [0, 128, 128],    // Teal
    [0, 0, 128],      // Navy
    [255, 165, 0],    // Orange
    [255, 215, 0],    // Gold
    [75, 0, 130],     // Indigo
    [255, 20, 147],   // Deep Pink
    [0, 191, 255],    // Deep Sky Blue
    [240, 128, 128],  // Light Coral
    [47, 79, 79],     // Dark Slate Gray
    [255, 105, 180],  // Hot Pink
    [72, 209, 204],   // Medium Turquoise
    [153, 50, 204]    // Dark Orchid
];

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
    
    public static func secureCopyItem(at srcURL: URL, to dstURL: URL, forceExtension: String?) -> (Bool, URL?) {
        do {
            var dst = dstURL.appendingPathComponent(srcURL.lastPathComponent)
            if(forceExtension != nil) {
                dst = dst.deletingPathExtension().appendingPathExtension(forceExtension!)
            }
            let name = srcURL.deletingPathExtension().lastPathComponent
            let ext = dstURL.pathExtension
            let fm = FileManager.default
            var fix = 0
            while fm.fileExists(atPath: dst.path(percentEncoded: false)) {
                fix += 1
                dst = dst.deletingLastPathComponent().appending(component: ("\(name)_\(fix)" + ext)).appendingPathExtension("jpg")
            }
            try fm.copyItem(at: srcURL, to: dst)
            return (true, dst)
        } catch {
            print("Cannot copy item at \(srcURL) to \(dstURL): \(error)")
            return (false, nil)
        }
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

