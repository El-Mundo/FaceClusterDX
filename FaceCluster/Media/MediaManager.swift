//
//  MediaManager.swift
//  FaceCluster
//
//  Created by El-Mundo on 01/06/2024.
//

import Foundation

import AppKit
import AVFoundation

class MediaManager {
    static var instance: MediaManager?
    private var importedURL: URL
    private var isVideo: Bool
    
    private static let timeoutSeconds = 10
    private let timeout = Duration.seconds(timeoutSeconds)
    
    private var processedImages = 0
    private var cv: ContentView?
    private var framesExpected = 1
    
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
    
    func addProcessedImage() {
        processedImages += 1
        cv?.pbProgress = min(Double(processedImages) / Double(framesExpected), 1.0)
    }
    
    private static func getNativeFrameExtractor(asset: AVAsset, frameDuration: Double, timescale: Int32) -> AVAssetImageGenerator {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.requestedTimeToleranceAfter = CMTime(seconds: frameDuration, preferredTimescale: timescale)
        generator.requestedTimeToleranceBefore = .zero
        return generator
    }
    
    func generateFrameSeuqnce(extractValue: Double, extractUnit: ExtractionUnit, context: ContentView?, downsample: Float, useMTCNN: Bool=false) async throws {
        cv = context
        cv?.pbInfo = "Analysing video asset"
        processedImages = 0
        
        let video = self.getVideoAsset()
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
        
        var timeCursor: CMTime = CMTimeMakeWithSeconds(0.0, preferredTimescale: timescale)
        let startTime: Date = Date.now
        
        cv?.pbInfo = "Analysing frames"
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
                if(downsample < 0.999) {
                    image = ImageUtils.resizeCG(image: source, scale: Double(downsample))!
                } else {
                    image = source
                }
                print(processedImages)
                if(useMTCNN) {
                    FaceRectangle.detectFacesMTCNN(in: image)
                } else {
                    FaceRectangle.detectFacesNative(in: image)
                }
            } catch {
                addProcessedImage()
                print("Failed to analyse frame at position \(timeCursor.seconds) second")
                print(error)
            }
            
            timeCursor = CMTimeAdd(timeCursor, extractInterval)
        }
        
        while(processedImages < framesExpected) {
            sleep(1)
        }
        
        let timeLapse = Date.now.timeIntervalSince(startTime)
        print("Time lapse \(timeLapse)")
        
        cv?.state = 3
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
            print(fps * 100)
            display.fps = Float(round(100 * fps) / 100)
            display.dimension = dimension
            return
        }
    }
    
}
