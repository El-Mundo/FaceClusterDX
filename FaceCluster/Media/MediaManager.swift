//
//  MediaManager.swift
//  FaceCluster
//
//  Created by El-Mundo on 01/06/2024.
//

import Foundation

import AppKit
import AVFoundation
import SwiftUI

let THUMBNAIL_SIZE: Int = 64

struct MediaAttributes: Codable {
    let path: String
    let interval: Double
    let downsample: Float
    let created: Date
    let model: String
}

class MediaManager {
    static var instance: MediaManager?
    private var importedURL: URL
    private var isVideo: Bool
    
    //private static let timeoutSeconds = 10
    //private let timeout = Duration.seconds(timeoutSeconds)
    
    private var processedImages = 0
    private var cv: ContentView?
    private var framesExpected = 1
    
    private var faceNetwork: FaceNetwork? = nil
    public static var importMessage = ""
    
    init(importedURL: URL, isVideo: Bool) {
        self.importedURL = importedURL
        self.isVideo = isVideo
    }
    
    func setMediaFile(importedURL: URL, isVideo: Bool) {
        self.importedURL = importedURL
        self.isVideo = isVideo
    }
    
    func getURL() -> URL {
        return self.importedURL
    }
    
    func getIsVideo() -> Bool {
        return self.isVideo
    }
    
    private func getVideoAsset() -> AVAsset {
        return AVAsset(url: importedURL)
    }
    
    func addProcessedImage(faces: [DetectedFace], identifier: String, image: CGImage?=nil, isError: Bool=false) {
        processedImages += 1
        cv?.pbProgress = min(Double(processedImages) / Double(framesExpected), 1.0)
        
        if(!isError) {
            for faceDet in faces {
                let face = Face(detectedAttributes: faceDet, network: faceNetwork)
                faceNetwork?.faces.append(face)
                
                guard let frameImg = image else {
                    let _ = faceNetwork?.saveSingle(face: face)
                    continue
                }
                
                /*let iw = Double(frameImg.width)
                let ih = Double(frameImg.height)
                let ox = faceDet.box[0] * iw
                let oy = faceDet.box[1] * -ih + ih
                let o = CGPoint(x: max(0, ox), y: max(0, oy))
                let w = CGSize(width: min(iw-1, faceDet.box[2] * iw), height: min(ih-1, faceDet.box[3] * -ih))*/
                
                //var thumbnail = ImageUtils.cropCGImage(frameImg, toRect: CGRect(origin: o, size: w))
                var thumbnail = ImageUtils.cropCGImageNormalised(frameImg, normalisedBox: faceDet.box)
                if(thumbnail != nil) {
                    //thumbnail = ImageUtils.resizeCG(image: thumbnail!, scale: (thumbnailSize/Double((max(thumbnail!.width, thumbnail!.height)))))
                    thumbnail = ImageUtils.resizeCGExactly(thumbnail!, size: CGSize(width: THUMBNAIL_SIZE, height: THUMBNAIL_SIZE))!
                }
                face.generateDefaultPosition(index: Int(identifier) ?? 0)
                let _ = faceNetwork?.saveSingle(face: face, thumbnail: thumbnail)
            }
        }
    }
    
    private static func getNativeFrameExtractor(asset: AVAsset, frameDuration: Double, timescale: Int32) -> AVAssetImageGenerator {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.requestedTimeToleranceAfter = CMTime(seconds: frameDuration, preferredTimescale: timescale)
        generator.requestedTimeToleranceBefore = .zero
        return generator
    }
    
    func loadExistingProject(context: ContentView) {
        cv = context
        do {
            let data = try Data(contentsOf: importedURL, options: .mappedIfSafe)
            let _ = try JSONDecoder().decode(FaceClusterProject.self, from: data)
            cv?.state = 5
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func generateFrameSeuqnce(extractValue: Double, extractUnit: ExtractionUnit, context: ContentView?, downsample: Float, useMTCNN: Bool) async throws {
        cv = context
        cv?.pbInfo = "Analysing video asset"
        processedImages = 0
        
        let videoName = self.importedURL.lastPathComponent
        //videoName = (videoName as NSString).deletingPathExtension
        let saveURL = self.getSaveParentDirectory(name: videoName)!
        faceNetwork = FaceNetwork(savedPath: saveURL, attributes: [SavableAttribute(name: "Position", type: .Point, dimensions: nil)])
        
        let video = self.getVideoAsset()
        let saveImageURL = saveURL.appending(path: "frames/")
        let duration = try await video.load(.duration)
        let frameRate = try await video.load(.tracks).first!.load(.nominalFrameRate)
        let timescale = Int32(frameRate)
        let frameDuration = 1.0 / Double(frameRate)
        let generator = MediaManager.getNativeFrameExtractor(asset: video, frameDuration: frameDuration, timescale: timescale)
        let extractInterval: CMTime
        if(extractUnit == .frame) {
            extractInterval = CMTimeMakeWithSeconds(frameDuration * extractValue, preferredTimescale: timescale + 1)
        } else {
            extractInterval = CMTimeMakeWithSeconds(extractValue, preferredTimescale: timescale)
        }
        framesExpected = Int(duration.seconds / extractInterval.seconds) + (extractUnit == .frame ? 0 : 1)
        print("\(framesExpected) frames expected.")
        MediaManager.importMessage += String(localized: "\(framesExpected) frames expected." ) + "\n"
        
        faceNetwork?.media = MediaAttributes(path: self.importedURL.lastPathComponent, interval: extractInterval.seconds, downsample: downsample, created: Date.now, model: "Vision")
        faceNetwork?.saveMetadata()
        
        var timeCursor: CMTime = CMTimeMakeWithSeconds(0.0, preferredTimescale: timescale)
        let startTime: Date = Date.now
        
        cv?.pbInfo = "Analysing frames"
        var index = 0
        while timeCursor < duration {
            /*let t = timeCursor.seconds
            
            let fetchTask = Task {
                let image: CGImage = try await generator.image(at: CMTime(seconds: t, preferredTimescale: timescale)).image
                try Task.checkCancellation()
                return image
            }
                
            let timeoutTask = Task {
                try await Task.sleep(for: timeout)
                fetchTask.cancel()
                print("Frame extraction timeout at \(t) second")
            }*/
                
            do {
                //let image = try await fetchTask.value
                //timeoutTask.cancel()
                
                let source: CGImage = try await generator.image(at: timeCursor).image
                let image: CGImage
                let identifier = String(index)
                if(downsample < 0.999) {
                    image = ImageUtils.resizeCG(image: source, scale: Double(downsample))!
                } else {
                    image = source
                }
                
                // Save image
                let save = saveImageURL.appending(path: "\(identifier).jpg")
                let saved = ImageUtils.saveImageAsJPG(image, at: save)
                if(!saved) {
                    FaceRectangle.detectFacesNative(cgImage: image, identifier: identifier)
                    index += 1
                    print("Failed to save thumbnail for frame \(identifier)")
                    MediaManager.importMessage += String(localized: "Failed to save thumbnail for frame \(identifier)") + "\n"
                } else {
                    // print(processedImages)
                    // if(useMTCNN) {
                    //     FaceRectangle.detectFacesMTCNN(in: image)
                    // } else {
                    FaceRectangle.detectFacesNative(in: save, identifier: identifier)
                    // }
                    index += 1
                }
            } catch {
                addProcessedImage(faces: [], identifier: String(index), isError: true)
                print("Failed to analyse frame at position \(timeCursor.seconds) second")
                print(error)
                MediaManager.importMessage += String(localized: "Failed to analyse frame at position \(timeCursor.seconds) second" ) + "\n"
            }
            
            timeCursor = CMTimeAdd(timeCursor, extractInterval)
        }
        
        while(processedImages < index) {
            sleep(1)
        }
        
        try? faceNetwork?.saveAttributesData()
        
        let timeLapse = Date.now.timeIntervalSince(startTime)
        print("Time lapse \(timeLapse)")
        MediaManager.importMessage += String(localized: "Time lapse \(timeLapse)") + "\n"
        
        let faceTotal: Int = faceNetwork?.faces.count ?? 0
        print(faceTotal, "faces detected from the video")
        MediaManager.importMessage +=  String(localized: "\(faceTotal) faces detected from the video") + "\n\n"
        
        if(faceTotal < 1) {
            cv?.state = 4
        } else {
            cv?.state = 5
        }
    }
    
    private func getSaveParentDirectory(name: String) -> URL? {
        var autoURL = AppDelegate.workspace.appending(path: "\(name)/")
        var renameNumber = 1
        let manager = FileManager.default
        while(AppDelegate.checkIfDirectoryExists(url: autoURL)) {
            if(renameNumber > 256) {
                fatalError(String(localized: "There are too many folder created for video \(name) in the workspace. Please clear the workspace before processing."))
            }
            autoURL = AppDelegate.workspace.appending(path: "\(name)-\(renameNumber)/")
            renameNumber += 1
        }
        
        do {
            try manager.createDirectory(at: autoURL, withIntermediateDirectories: true, attributes: nil)
            try manager.createDirectory(at: autoURL.appending(path: "frames/"), withIntermediateDirectories: true)
            try manager.createDirectory(at: autoURL.appending(path: "faces/"), withIntermediateDirectories: true)
            return autoURL
        } catch {
            print(error)
            return nil
        }
    }
    
    func videoProcessFailed() {
        cv?.state = 4
    }
    
    func getInfo(display: VideoPreview) {
        let video = self.getVideoAsset()
        
        Task {
            guard let track = try? await video.load(.tracks).first else {
                display.fps = -0.0
                display.dimension = CGSize.zero
                return
            }
            let fps = (try? await track.load(.nominalFrameRate)) ?? 0
            let dimension = (try? await track.load(.naturalSize)) ?? CGSize.zero
            display.fps = Float(round(100 * fps) / 100)
            display.dimension = dimension
            return
        }
    }
    
    func getEditFaceNetwork() -> FaceNetwork? {
        return faceNetwork
    }
    
    func setEditFaceNetwork(newNetwork: FaceNetwork) {
        faceNetwork = newNetwork
    }
    
    func importImageSequence(info: Binding<String>?, progress: Binding<CGFloat>?, urls: [URL], network: FaceNetwork) {
        info?.wrappedValue = String(localized: "Analysing images...")
        var completed = 0
        
        for url in urls {
            guard let source: CGImage = ImageUtils.loadJPG(url: url) else {
                continue
            }
            let identifier = url.deletingPathExtension().lastPathComponent
            
            guard let result = FaceRectangle.detectFacesAppendingNative(in: source, identifier: identifier) else {
                completed += 1
                continue
            }
            
            let frame = result.2
            let id = result.1
            let faces = result.0
            
            appendFaceDetection(faces: faces, identifier: id, image: frame, network: network)
            
            completed += 1
            progress?.wrappedValue = CGFloat(completed) / CGFloat(urls.count)
        }
    }
    
    private func appendFaceDetection(faces: [DetectedFace], identifier: String, image: CGImage?=nil, network: FaceNetwork) {
        for faceDet in faces {
            let face = Face(detectedAttributes: faceDet, network: network)
            network.faces.append(face)
            
            guard let frameImg = image else {
                let _ = faceNetwork?.saveSingle(face: face)
                continue
            }
            
            var thumbnail = ImageUtils.cropCGImageNormalised(frameImg, normalisedBox: faceDet.box)
            if(thumbnail != nil) {
                thumbnail = ImageUtils.resizeCGExactly(thumbnail!, size: CGSize(width: THUMBNAIL_SIZE, height: THUMBNAIL_SIZE))
            }
            face.forceUpdateAttribute(key: network.layoutKey, value: FacePoint(DoublePoint(x: 0, y: 0), for: network.layoutKey))
            let _ = faceNetwork?.saveSingle(face: face, thumbnail: thumbnail)
        }
    }
    
}
