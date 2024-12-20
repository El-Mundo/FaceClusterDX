//
//  TimelineRenderer.swift
//  FaceCluster
//
//  Created by El-Mundo on 12/12/2024.
//

import Foundation
import MetalKit
import SwiftUI

struct TimelineFace {
    var face: Face
    var time: Double
    var clusterIndex: Int
    var clusterIdTotal: Int = -1
    var tlDisplayPos: DoublePoint
    
    init(face: Face, network: FaceNetwork, id: Int) {
        self.face = face
        self.time = network.getMediaTime(face: face)
        self.clusterIndex = id
        self.tlDisplayPos = DoublePoint(x: 0, y: 0)
    }
}

struct SimplifiedNetwork {
    var clusters: [String : [TimelineFace]]
    var order: Int
    var length: Double
    var isActive: Bool
    
    init(url: URL, order: Int) {
        var id = 0
        let fn = try! FaceNetwork(url: url, showProgress: false)
        self.clusters = [String : [TimelineFace]]()
        for cluster in fn.clusters {
            var newArray = [TimelineFace]()
            for face in cluster.value.faces {
                newArray.append(TimelineFace(face: face, network: fn, id: id))
            }
            clusters.updateValue(newArray, forKey: cluster.key)
            id += 1
        }
        self.isActive = false
        self.order = order
        self.length = fn.media!.duration
    }
}

struct TimelineRenderer: NSViewRepresentable {
    static var networks: [SimplifiedNetwork] = []
    static var xMode: Int = 0
    static var yMode: String = "Cluster"
    static var pYMode: String = "Cluster"
    static var pXMode: Int = 0
    static var scaling: Float = 1.0
    static var xStretch: Float = 1.0
    static var pShowTexture: Bool = false
    let farPlane: Float = 99
    let context: MediaTimeline
    
    init(project: FaceClusterProject, context: MediaTimeline) {
        TimelineRenderer.networks = []
        self.context = context
        var i = 0
        for path in project.paths {
            TimelineRenderer.networks.append(SimplifiedNetwork(url: AppDelegate.workspace.appendingPathComponent(path), order: i))
            if(path == project.activePath) {
                TimelineRenderer.networks[i].isActive = true
            }
            i += 1
        }
    }
    
    class Coordinator: NSObject, MTKViewDelegate {
        var device: MTLDevice
        var commandQueue: MTLCommandQueue
        var pipelineState: MTLRenderPipelineState?
        var textPipelineState: MTLRenderPipelineState
        var uniforms: UnsafeMutablePointer<Uniforms>
        var dynamicUniformBuffer: MTLBuffer
        
        var context: MediaTimeline
        
        var aspectRatio: Float = 1
        var showTextures: Bool = false
        var faceObjBuffer: MTLBuffer?
        var faceObjPtr: UnsafeMutablePointer<FaceMap>?
        var colorClusterBuffer: MTLBuffer?
        var colorClusters: UnsafeMutablePointer<UInt16>
        var faceCount: Int
        var initializationFailed: Bool = false
        var fontArrayTexture: FontTextureArray
        
        var textureCaches: [MTLTexture]
        var textureDescriptor: MTLTextureDescriptor
        var linesRenderState: MTLRenderPipelineState
        
        var mergedClusters: [String : [ TimelineFace ]]
        var mergedClusterId: [String : Int]
        var mediaDuration: Float = 0
        
        init(device: MTLDevice, context: MediaTimeline) {
            self.device = device
            self.commandQueue = device.makeCommandQueue()!
            self.pipelineState = try! TimelineRenderer.buildTL_OBJRenderPipelineState(metalDevice: device)// Self.build//makeRenderPipelineState(device)
            
            self.linesRenderState = Self.makeLineRenderPipelineState(device)!
            
            self.textPipelineState = Self.makeTextRenderPipelineState(device)!
            
            var count = 0
            mergedClusters = [String : [TimelineFace]]()
            mergedClusterId = [:]
            var allFaces = [TimelineFace]()
            for network in TimelineRenderer.networks {
                for cluster in network.clusters.values {
                    count += cluster.count
                    for face in cluster {
                        allFaces.append(face)
                        let key = face.face.clusterName!
                        if(mergedClusters.keys.contains(key)) {
                            mergedClusters[key]!.append(face)
                        } else {
                            mergedClusterId.updateValue(mergedClusters.count, forKey: key)
                            mergedClusters.updateValue([face], forKey: key)
                        }
                    }
                }
            }
            
            self.context = context
            
            initializationFailed = count == 0
            if(count == 0) {
                count += 1
            }
            print("\(mergedClusters.count) clusters in total")
            
            faceObjBuffer = device.makeBuffer(length: MemoryLayout<FaceMap>.stride * count, options: [.storageModeShared])
            faceObjPtr = UnsafeMutableRawPointer(faceObjBuffer!.contents()).bindMemory(to:FaceMap.self, capacity:count)
            if(faceObjPtr == nil || faceObjBuffer == nil) {
                fatalError(String(localized: "Failed to allocate memory for rendering face network. Please reduce the network size."))
            }
            colorClusterBuffer = device.makeBuffer(length: MemoryLayout<UInt16>.stride * count, options: [.storageModeShared])
            colorClusters = UnsafeMutableRawPointer(colorClusterBuffer!.contents()).bindMemory(to: UInt16.self, capacity:count)
            if(colorClusterBuffer == nil) {
                fatalError(String(localized: "Failed to allocate memory for rendering face network. Please reduce the network size."))
            }
            
            if(!initializationFailed) {
                let n = count
                faceCount = n
                for i in 0..<n {
                    var face = allFaces[i]
                    let y = mergedClusterId[face.face.clusterName!] ?? 0
                    let x = face.time
                    face.tlDisplayPos = DoublePoint(x: x, y: Double(y))
                    
                    faceObjPtr![i].pos = simd_float2(x: Float(face.tlDisplayPos.x), y: Float(face.tlDisplayPos.y))
                    faceObjPtr![i].disabled = face.face.disabled
                    colorClusters[i] = UInt16(mergedClusterId[face.face.clusterName!] ?? 0)
                }
            } else {
                self.faceCount = 0
            }
            
            guard let buffer = device.makeBuffer(length: (MemoryLayout<Uniforms>.size + 0xFF) & -0x100, options:[MTLResourceOptions.storageModeShared]) else { fatalError(String(localized: "Failed to initialise Metal 3 environment.")) }
            dynamicUniformBuffer = buffer
            uniforms = UnsafeMutableRawPointer(dynamicUniformBuffer.contents()).bindMemory(to:Uniforms.self, capacity:1)
            NetworkView.resetCamera()
            showTextures = false
            TimelineRenderer.pShowTexture = false
            TimelineRenderer.xMode = 0
            TimelineRenderer.pXMode = 0
            TimelineRenderer.yMode = "Cluster"
            TimelineRenderer.pYMode = "Cluster"
            
            guard let texDes = NetworkView.Coordinator.createArrayTextureDescriptor(device: device, size: CGSize(width: THUMBNAIL_SIZE, height: THUMBNAIL_SIZE), layers: Int(FACE_TEXTURE_BATCH_SIZE), pixelFormat: .bgra8Unorm) else {
                fatalError(String(localized: "Failed to initialise Metal 3 environment."))
            }
            self.textureDescriptor = texDes
            self.textureCaches = []
            
            var w: Float = 0.0
            for n in TimelineRenderer.networks {
                w += Float(n.length)
            }
            mediaDuration = w
            self.fontArrayTexture = FontTextureArray(device: device, fontSize: 36, textureSize: CGSize(width: 64, height: 64), commandQueue: commandQueue)
        }
        
        func update() {
            let n = faceCount
            faceCount = n
            var allFaces = [TimelineFace]()
            var allPoses = [DoublePoint]()
            var timeZero = 0.0
            for network in TimelineRenderer.networks {
                let networkMediaDuration = network.length
                let isActive = network.isActive
                
                for cluster in network.clusters.values {
                    for face in cluster {
                        allFaces.append(face)
                        
                        var x = 0.0
                        if(xMode == 1) {
                            x = face.time
                            x += timeZero
                        } else if(xMode == 0) {
                            x = face.time
                        } else {
                            if(isActive) {
                                x = face.time
                            } else {
                                x = -5.0
                            }
                        }
                        
                        var y = 0.0
                        if(yMode == "Cluster") {
                            y = Double(mergedClusterId[face.face.clusterName!] ?? 0)
                        } else {
                            guard let fa = face.face.attributes[yMode] else {
                                y = 0
                                x = -5.0
                                allPoses.append(DoublePoint(x: x, y: y))
                                continue
                            }
                            
                            if let v = fa as? FaceDecimal {
                                y = v.value
                            } else if let v = fa as? FaceInteger {
                                let vv = v.value
                                y = Double(vv)
                            } else {
                                y = 0
                                x = -5.0
                            }
                        }
                        allPoses.append(DoublePoint(x: x, y: y))
                    }
                }
                
                timeZero += networkMediaDuration
            }
            for i in 0..<n {
                var face = allFaces[i]
                face.tlDisplayPos = allPoses[i]
                
                faceObjPtr![i].pos = simd_float2(x: Float(face.tlDisplayPos.x), y: Float(face.tlDisplayPos.y))
                faceObjPtr![i].disabled = face.face.disabled
                colorClusters[i] = UInt16(mergedClusterId[face.face.clusterName!] ?? 0)
            }
            
            var w: Float = 0.0
            for n in TimelineRenderer.networks {
                w += Float(n.length)
            }
            mediaDuration = w
        }
        
        func toggleShowTexture() {
            if(showTextures) {
                loadImagesIntoTexture()
            } else {
                textureCaches = []
            }
        }
        
        static func makeLineRenderPipelineState(_ device: MTLDevice) -> MTLRenderPipelineState? {
            let library = device.makeDefaultLibrary()!
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = library.makeFunction(name: "vertex_main")
            pipelineDescriptor.fragmentFunction = library.makeFunction(name: "fragment_main")
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            return try? device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        }
        
        static func makeTextRenderPipelineState(_ device: MTLDevice) -> MTLRenderPipelineState? {
            let library = device.makeDefaultLibrary()!
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = library.makeFunction(name: "textVertex")
            pipelineDescriptor.fragmentFunction = library.makeFunction(name: "textFragment")
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            let attachment = pipelineDescriptor.colorAttachments[0]
            attachment?.isBlendingEnabled = true
            attachment?.rgbBlendOperation = .add
            attachment?.alphaBlendOperation = .add
            attachment?.sourceRGBBlendFactor = .sourceAlpha
            attachment?.destinationRGBBlendFactor = .oneMinusSourceAlpha
            attachment?.sourceAlphaBlendFactor = .sourceAlpha
            attachment?.destinationAlphaBlendFactor = .oneMinusSourceAlpha
            return try? device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // Handle resizing if needed
            aspectRatio = Float(size.width) / Float(size.height)
        }
        
        func draw(in view: MTKView) {
            if(initializationFailed) {
                return
            }
            
            if(context.mergedClusterId.count != self.mergedClusterId.count) {
                context.mergedClusterId = mergedClusterId
                print("\(context.mergedClusterId.count) + clusters loaded in HUD.")
            }
            
            guard let drawable = view.currentDrawable,
                  let renderPassDescriptor = view.currentRenderPassDescriptor,
                let pipelineState = pipelineState else { return }
            
            showTextures = NetworkView.allowMultipleSelection
            if(showTextures != pShowTexture) {
                toggleShowTexture()
            }
            
            let commandBuffer = commandQueue.makeCommandBuffer()!
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            
            // Camera
            let pos = NetworkView.camera
            uniforms[0].camera = SIMD2<Float>(pos.x, pos.y)
            
            if(pXMode != xMode || pYMode != yMode) {
                update()
            }

            // Borrowing this attribute
            uniforms[0].multipleSelect = showTextures
            uniforms[0].mousePos.x = scaling
            uniforms[0].mousePos.y = xStretch
            uniforms[0].scale = -1/pos.z
            uniforms[0].aspect = aspectRatio
            if(NetworkView.mouseDown) {
                let mouseStep = NetworkView.mouse - NetworkView.pMousePos
                NetworkView.camera.x -= mouseStep.x * 0.005 / uniforms[0].scale
                NetworkView.camera.y -= mouseStep.y * 0.005 / uniforms[0].scale
            }
            
            // Render
            renderEncoder.setRenderPipelineState(textPipelineState)
            renderEncoder.setVertexBytes(&mediaDuration, length: MemoryLayout<Float>.stride, index: 0)
            renderEncoder.setVertexBuffer(dynamicUniformBuffer, offset: 0, index: 1)
            renderEncoder.setFragmentTexture(fontArrayTexture.texture, index: 0)
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 36 * (max(Int(mediaDuration / 15), 1) + 1))
            
            renderEncoder.setRenderPipelineState(linesRenderState)

            renderEncoder.setVertexBytes(&mediaDuration, length: MemoryLayout<Float>.stride, index: 0)
            renderEncoder.setVertexBuffer(dynamicUniformBuffer, offset: 0, index: 1)
            renderEncoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: 20)
            
            
            renderEncoder.setRenderPipelineState(pipelineState)
                        
            /*renderEncoder.setVertexBuffer(faceObjBuffer, offset: 0, index: 0)
            renderEncoder.setVertexBuffer(dynamicUniformBuffer, offset: 0, index: 1)
            renderEncoder.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: faceCount)*/
            
            var bi = 0
            renderEncoder.setObjectBuffer(faceObjBuffer, offset: 0, index: 0)
            renderEncoder.setObjectBuffer(dynamicUniformBuffer, offset: 0, index: 1)
            renderEncoder.setObjectBuffer(colorClusterBuffer, offset: 0, index: 3)
            if(showTextures) {
                for textureBatch in self.textureCaches {
                    renderEncoder.setObjectBuffer(self.createFaceCountBuffer(batchIndex: bi), offset: 0, index: 2)
                    renderEncoder.setFragmentTexture(textureBatch, index: TextureIndex.color.rawValue)
                    renderEncoder.drawMeshThreads(MTLSize(width: FACE_TEXTURE_BATCH_SIZE, height: 1, depth: 1),
                                                  threadsPerObjectThreadgroup: MTLSize(width: 1, height: 1, depth: 1),
                                                  threadsPerMeshThreadgroup: MTLSize(width: 8, height: 1, depth: 1))
                    
                    bi += 1
                }
                    
            } else {
                renderEncoder.setObjectBuffer(self.createFaceCountBuffer(batchIndex: 0), offset: 0, index: 2)
                renderEncoder.drawMeshThreads(MTLSize(width: faceCount, height: 1, depth: 1),
                                              threadsPerObjectThreadgroup: MTLSize(width: 1, height: 1, depth: 1),
                                              threadsPerMeshThreadgroup: MTLSize(width: 8, height: 1, depth: 1))
            }
            
            renderEncoder.endEncoding()
            
            commandBuffer.present(drawable)
            commandBuffer.commit()
            
            TimelineRenderer.pXMode = TimelineRenderer.xMode
            TimelineRenderer.pYMode = TimelineRenderer.yMode
            
            NetworkView.pMousePos = NetworkView.mouse
            TimelineRenderer.pShowTexture = showTextures
        }
        
        func createFaceCountBuffer(batchIndex: Int) -> MTLBuffer? {
            guard let buffer = device.makeBuffer(length: MemoryLayout<UInt>.stride, options: [.storageModeShared]) else {
                return nil
            }
            let faceCountMem = UnsafeMutableRawPointer(buffer.contents()).bindMemory(to: UInt.self, capacity:2)
            faceCountMem[0] = UInt(faceCount)
            faceCountMem[1] = UInt(batchIndex)
            return buffer
        }
        
        func loadImagesIntoTexture() {
            guard var commandBuffer = commandQueue.makeCommandBuffer(),
            var blitCommandEncoder = commandBuffer.makeBlitCommandEncoder() else {
                return
            }
            
            
            var faces = [TimelineFace]()
            for network in TimelineRenderer.networks {
                for cluster in network.clusters.values {
                    for face in cluster {
                        faces.append(face)
                    }
                }
            }
            
            var arrayTextureIndex = 0, singleTextureIndex = 0
            var workingArrayTexture = device.makeTexture(descriptor: textureDescriptor)!
            
            for face in faces {
                if(singleTextureIndex == FACE_TEXTURE_BATCH_SIZE) {
                    blitCommandEncoder.endEncoding()
                    commandBuffer.commit()
                    commandBuffer.waitUntilCompleted()
                    
                    singleTextureIndex = 0
                    arrayTextureIndex += 1
                    
                    self.textureCaches.append(workingArrayTexture)
                    workingArrayTexture = device.makeTexture(descriptor: textureDescriptor)!
                    
                    commandBuffer = commandQueue.makeCommandBuffer()!
                    blitCommandEncoder = commandBuffer.makeBlitCommandEncoder()!
                }
                
                if let newTexture = face.face.texture {
                    blitCommandEncoder.copy(from: newTexture,
                                            sourceSlice: 0,
                                            sourceLevel: 0,
                                            sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                                            sourceSize: MTLSize(width: THUMBNAIL_SIZE, height: THUMBNAIL_SIZE, depth: 1),
                                            to: workingArrayTexture,
                                            destinationSlice: singleTextureIndex,
                                            destinationLevel: 0,
                                            destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
                }
                singleTextureIndex += 1
                
                if(arrayTextureIndex * FACE_TEXTURE_BATCH_SIZE + singleTextureIndex >= faces.count) {
                    blitCommandEncoder.endEncoding()
                    commandBuffer.commit()
                    commandBuffer.waitUntilCompleted()
                    self.textureCaches.append(workingArrayTexture)
                    // The loop will end after this no matter what
                    break
                }
            }
            
            print("\(textureCaches.count) texture batches created, sized \(FACE_TEXTURE_BATCH_SIZE)")
        }
    }
    
    func makeCoordinator() -> Coordinator {
        let device = GPUManager.instance?.metalDevice
        return Coordinator(device: device!, context: context)
    }
    
    func makeNSView(context: Context) -> MTKView {
        let mtkView = CustomizedMetalView()
        mtkView.delegate = context.coordinator
        mtkView.enableSetNeedsDisplay = false
        mtkView.framebufferOnly = true
        mtkView.device = GPUManager.instance?.getMTLDevice()
        mtkView.clearColor = MTLClearColor(red: NetworkView.backgroundColour.x, green: NetworkView.backgroundColour.y, blue: NetworkView.backgroundColour.z, alpha: 1.0)
        mtkView.autoResizeDrawable = true
        mtkView.mouseDraggedFunction = mouseDragged
        mtkView.mouseWheelFunction = mouseWheel
        mtkView.mouseMove = mouseMove
        mtkView.mouseExit = mouseExited
        mtkView.mouseDownFunc = mouseDownFunc
        mtkView.mouseUpFunc = mouseUpFunc
        mtkView.rightMouseFunc = rMouseDown
        mtkView.rightMouseUpFunc = rMouseUp
        
        return mtkView
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
        // Update view as needed
        nsView.setNeedsDisplay(NSRect(x: 0, y: 0, width: nsView.frame.width, height: nsView.frame.height))
        nsView.clearColor = MTLClearColor(red: NetworkView.backgroundColour.x, green: NetworkView.backgroundColour.y, blue: NetworkView.backgroundColour.z, alpha: 1.0)
    }
    
    static func buildTL_OBJRenderPipelineState(metalDevice: MTLDevice) throws -> MTLRenderPipelineState? {
        let pipelineDescriptor = MTLMeshRenderPipelineDescriptor()
        guard let library = metalDevice.makeDefaultLibrary() else {
            return nil
        }
        let meshFunction = library.makeFunction(name: "timeObjectShader")
        let meshletFunction = library.makeFunction(name: "timeMeshletShader")
        let fragmentFunction = library.makeFunction(name: "timeFragmentShader")
        
        pipelineDescriptor.label = "FacesRenderPipeline"
        //pipelineDescriptor.rasterSampleCount = parent.mtlSampleCount
        pipelineDescriptor.objectFunction = meshFunction
        pipelineDescriptor.meshFunction = meshletFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm //parent.colourPixelFormat
        //enableAlpha(ca: pipelineDescriptor.colorAttachments[0])
        //pipelineDescriptor.depthAttachmentPixelFormat = parent.depthPixelFormat
        //pipelineDescriptor.stencilAttachmentPixelFormat = parent.depthPixelFormat
        
        let a: MTLPipelineOption = MTLPipelineOption()
        let state: MTLRenderPipelineState
        (state, _) = try metalDevice.makeRenderPipelineState(descriptor: pipelineDescriptor, options: a)
        
        return state
    }
    
    private static func enableAlpha(ca: MTLRenderPipelineColorAttachmentDescriptor) {
        ca.isBlendingEnabled = true
        ca.rgbBlendOperation = .add
        ca.alphaBlendOperation = .add
        ca.sourceRGBBlendFactor = .destinationAlpha
        ca.sourceAlphaBlendFactor = .destinationAlpha
        ca.destinationRGBBlendFactor = .oneMinusSourceAlpha
        ca.destinationAlphaBlendFactor = .oneMinusBlendAlpha
    }
    
    
}

extension TimelineRenderer {
    func mouseDragged(with event: NSEvent) {
        //NetworkView.camera.x = NetworkView.camera.x - Float(event.deltaX) * 0.02
        //NetworkView.camera.y = NetworkView.camera.y - Float(event.deltaY) * -0.02
        let loc = event.locationInWindow
        NetworkView.mouse = SIMD2<Float>(Float(loc.x), Float(loc.y - 24))
    }
    
    func mouseExited(with event: NSEvent) {
        NetworkView.mouseDown = false
        NetworkView.rightMouseDown = false
    }
    
    func mouseDownFunc(with event: NSEvent) {
        NetworkView.mouseDown = true
    }
    
    func mouseUpFunc(with event: NSEvent) {
        NetworkView.mouseDown = false
    }
    
    func mouseWheel(with event: NSEvent) {
        var z = NetworkView.camera.z + Float(event.scrollingDeltaY) * 0.02
        if(z > -1) {
            z = -1
        } else if(z < -farPlane) {
            z = -farPlane
        }
        NetworkView.camera.z = z
    }
    
    func rMouseUp(with event: NSEvent) {
        NetworkView.rightMouseDown = false
    }
    
    func rMouseDown(with event: NSEvent) {
        NetworkView.rightMouseDown = true
    }
    
    func mouseMove(with event: NSEvent, view: MTKView) {
        let loc = event.locationInWindow
        NetworkView.mouse = SIMD2<Float>(Float(loc.x), Float(loc.y - 24))
    }
}
