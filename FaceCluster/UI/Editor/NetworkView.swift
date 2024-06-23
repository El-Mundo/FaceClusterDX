//
//  NetworkView.swift
//  FaceCluster
//
//  Created by El-Mundo on 19/06/2024.
//

import Foundation
import MetalKit
import SwiftUI

let FACE_TEXTURE_BATCH_SIZE: Int = FaceNetworkConstants.batchSize.rawValue

struct NetworkView: NSViewRepresentable {
    let depthPixelFormat = MTLPixelFormat.depth32Float_stencil8
    let colourPixelFormat = MTLPixelFormat.bgra8Unorm
    let mtlSampleCount = 1
    let farPlane: Float = 99
    var context: NetworkEditor?
    
    func makeNSView(context: NSViewRepresentableContext<NetworkView>) -> CustomizedMetalView {
        let mtkView = CustomizedMetalView()
        mtkView.delegate = context.coordinator
        mtkView.enableSetNeedsDisplay = false
        mtkView.framebufferOnly = true
        mtkView.device = GPUManager.instance?.getMTLDevice()
        mtkView.clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        mtkView.autoResizeDrawable = true
        mtkView.depthStencilPixelFormat = depthPixelFormat
        mtkView.colorPixelFormat = colourPixelFormat
        mtkView.sampleCount = mtlSampleCount
        mtkView.mouseDraggedFunction = mouseDragged
        mtkView.mouseWheelFunction = mouseWheel
        mtkView.mouseMove = mouseMove
        mtkView.mouseExit = mouseExited
        mtkView.mouseDownFunc = mouseDownFunc
        mtkView.mouseUpFunc = mouseUpFunc
        
        return mtkView
    }
    
    func updateNSView(_ nsView: CustomizedMetalView, context: Context) {
        nsView.setNeedsDisplay(NSRect(x: 0, y: 0, width: nsView.frame.width, height: nsView.frame.height))
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    typealias NSViewType = CustomizedMetalView
    static var camera = SIMD3<Float>(0, 0, -5)
    static var mouse = SIMD2<Float>(0, 0)
    static var mouseDown: Bool = false
    static var pMouseDown: Bool = false
    static var pMousePos = SIMD2<Float>(0, 0)
    
    static var allowMultipleSelection = true
    static var allowEditing = false
    static var selectRadius: Float = 2
    
    func mouseDragged(with event: NSEvent) {
        //NetworkView.camera.x = NetworkView.camera.x - Float(event.deltaX) * 0.02
        //NetworkView.camera.y = NetworkView.camera.y - Float(event.deltaY) * -0.02
        let loc = event.locationInWindow
        NetworkView.mouse = SIMD2<Float>(Float(loc.x), Float(loc.y - 24))
    }
    
    func mouseExited(with event: NSEvent) {
        NetworkView.mouseDown = false
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
    
    func mouseMove(with event: NSEvent, view: MTKView) {
        let loc = event.locationInWindow
        NetworkView.mouse = SIMD2<Float>(Float(loc.x), Float(loc.y - 24))
    }
    
    class Coordinator: NSObject, MTKViewDelegate {
        var parent: NetworkView
        var metalDevice: MTLDevice!
        var metalCommandQueue: MTLCommandQueue!
        
        let alignedUniformsSize = (MemoryLayout<Uniforms>.size + 0xFF) & -0x100
        var uniformBufferOffset = 0
        var uniformBufferIndex = 0
        var uniforms: UnsafeMutablePointer<Uniforms>
        var projectionMatrix: matrix_float4x4 = matrix_float4x4()
        
        private var network: FaceNetwork?
        
        var dynamicUniformBuffer: MTLBuffer
        var faceObjBuffer: MTLBuffer?
        var faceObjPtr: UnsafeMutablePointer<SIMD2<Float>>?
        var pipelineState: MTLRenderPipelineState
        var mousePipeline: MTLRenderPipelineState
        var depthState: MTLDepthStencilState
        //var debugTexture: MTLTexture?
        var textureDescriptor: MTLTextureDescriptor
        var arrayTextures: [MTLTexture] = []
        var textureSliceSize: Int
        var aspectRatio: Float = 1
        
        var pointDistanceBuffer: MTLBuffer?
        
        var movedFaces = [FaceSelection]()
        var mouseTexture: MTLTexture?
        
        init(_ parent: NetworkView) {
            self.parent = parent
            guard let md = GPUManager.instance?.getMTLDevice() else {
                fatalError(String(localized: "Failed to initialise Metal 3 environment."))
            }
            self.metalDevice = md
            guard let mq = GPUManager.instance?.metalCommandQueue else {
                fatalError(String(localized: "Failed to initialise Metal 3 environment."))
            }
            self.metalCommandQueue = mq
            
            guard let buffer = self.metalDevice.makeBuffer(length: alignedUniformsSize, options:[MTLResourceOptions.storageModeShared]) else { fatalError(String(localized: "Failed to initialise Metal 3 environment.")) }
            dynamicUniformBuffer = buffer
            uniforms = UnsafeMutableRawPointer(dynamicUniformBuffer.contents()).bindMemory(to:Uniforms.self, capacity:1)
            self.pipelineState = try! NetworkView.Coordinator.buildFaceMeshletRenderPipelineState(metalDevice: metalDevice, parent: parent)!
            self.mousePipeline = try! NetworkView.Coordinator.buildMouseRenderPipelineState(metalDevice: metalDevice, parent: parent)!
            
            let depthStateDescriptor = MTLDepthStencilDescriptor()
            depthStateDescriptor.depthCompareFunction = MTLCompareFunction.less
            depthStateDescriptor.isDepthWriteEnabled = true
            guard let state = metalDevice.makeDepthStencilState(descriptor:depthStateDescriptor) else { fatalError(String(localized: "Failed to initialise Metal 3 environment.")) }
            self.depthState = state
            
            let thumbnail = THUMBNAIL_SIZE
            guard let texDes = Coordinator.createArrayTextureDescriptor(device: metalDevice, size: CGSize(width: thumbnail, height: thumbnail), layers: Int(FACE_TEXTURE_BATCH_SIZE), pixelFormat: parent.colourPixelFormat) else {
                fatalError(String(localized: "Failed to initialise Metal 3 environment."))
            }
            self.textureDescriptor = texDes
            self.textureSliceSize = Int(thumbnail)
            
            super.init()
            
            let net = MediaManager.instance?.getEditFaceNetwork()
            if(net != nil) {
                setNetwork(network: net!)
            }
            NetworkView.camera = SIMD3<Float>(0, 0, -5)
            NetworkView.mouse = SIMD2<Float>(0, 0)
            NetworkView.mouseDown = false
            NetworkView.pMouseDown = false
            NetworkView.pMousePos = SIMD2<Float>(0, 0)
            NetworkView.allowEditing = false
            NetworkView.allowMultipleSelection = false
            NetworkView.selectRadius = 2.0
            
            self.mouseTexture =  try! loadBundledTexture(name: "rectangle1")
        }
        
        func setNetwork(network: FaceNetwork) {
            self.network = network
            let count = network.faces.count
            network.textures.removeAll()
            
            faceObjBuffer = self.metalDevice.makeBuffer(length: MemoryLayout<SIMD2<Float>>.stride * count, options: [.storageModeShared])
            faceObjPtr = UnsafeMutableRawPointer(faceObjBuffer!.contents()).bindMemory(to:SIMD2<Float>.self, capacity:count)
            if(faceObjPtr == nil || faceObjBuffer == nil) {
                fatalError(String(localized: "Failed to allocate memory for rendering face network. Please reduce the network size."))
            }
            
            let n = network.faces.count
            let half = (n % 2 == 0) ? (n / 2) : ((n + 1) / 2)
            let threadCount = half * n
            guard let cptBuffer = self.metalDevice.makeBuffer(length: MemoryLayout<PairedDistance>.stride * threadCount, options:[MTLResourceOptions.storageModeShared]) else {
                fatalError(String(localized: "Failed to allocate memory for rendering face network. Please reduce the network size."))
            }
            pointDistanceBuffer = cptBuffer
            
            
            for i in 0..<n {
                let face = network.faces[i]
                let tag = network.layoutKey
                let pos = face.attributes[tag]
                if let p = pos as? FacePoint {
                    face.displayPos = p.value
                } else {
                    face.displayPos = DoublePoint(x: 0, y: 0)
                }
                if(face.texture != nil) {
                    face.textureId = network.textures.count
                    network.textures.append(face.texture!)
                }
                faceObjPtr![i] = simd_float2(x: Float(face.displayPos.x), y: Float(face.displayPos.y))
            }
            //debugTexture = try? loadBundledTexture(name: "img")
            loadImagesIntoTexture()
            
            NetworkEditor.networkDisplayed = network
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            aspectRatio = Float(size.width) / Float(size.height)
            //print(aspect)
            projectionMatrix = matrix_perspective_right_hand(fovyRadians: radians_from_degrees(60), aspectRatio:aspectRatio, nearZ: 0.1, farZ: parent.farPlane + 1)
        }
        
        struct FaceSelection {
            var locRelToMouse: SIMD2<Float>
            var face: Face
            var index: Int
        }
        
        func draw(in view: MTKView) {
            guard let faceNetwork = network else {
                return
            }
            
            guard view.currentDrawable != nil else {
                return
            }
            
            guard let commandBuffer = metalCommandQueue.makeCommandBuffer() else {
                return
            }
            
            //uniforms[0].projectionMatrix = projectionMatrix
            let pos = NetworkView.camera
            uniforms[0].camera = SIMD2<Float>(pos.x, pos.y)

            uniforms[0].scale = -1/pos.z
            uniforms[0].aspect = aspectRatio
            
            let renderPassDescriptor = view.currentRenderPassDescriptor
            if let renderPassDescriptor = renderPassDescriptor, let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
                renderEncoder.label = "Primary Render Encoder"
                renderEncoder.pushDebugGroup("Draw Faces")
                
                renderEncoder.setCullMode(.none)
                renderEncoder.setFrontFacing(.counterClockwise)
                renderEncoder.setDepthStencilState(depthState)
                var bi = 0
                
                let r = parent.context?.radius ?? 2
                if(r < 0.999 || !allowEditing) {
                    allowMultipleSelection = false
                } else {
                    allowMultipleSelection = true
                    selectRadius = r
                }
                let w = Float(view.bounds.width)
                let h = Float(view.bounds.height)
                let ndcX = 2.0 * (mouse.x / w) - 1.0
                let ndcY = 1.0 - 2.0 * (mouse.y / h)
                let ndcPos = SIMD3<Float>(ndcX, ndcY, 0)
                let scale = uniforms[0].scale
                let mouseInFrameY = -ndcPos.y / scale + pos.y
                let mouseInFrameX = ndcPos.x / scale * aspectRatio + pos.x
                //print(mouseInFrameX, mouseInFrameY)
                uniforms[0].mousePos = SIMD2<Float>(mouseInFrameX, mouseInFrameY)
                uniforms[0].selectRadius = NetworkView.selectRadius
                
                var selectedFace: Face? = nil
                var selectedIndex: Int = -1
                var selectedRelPos: SIMD2<Float>? = nil
                
                var selectedFaces = [FaceSelection]()
                if(!allowEditing || !mouseDown) {
                    for i in (0..<faceNetwork.faces.count).reversed() {
                        let face = faceNetwork.faces[i]
                        // CPU version
                        let size: Float = allowMultipleSelection ? 0.5 * NetworkView.selectRadius : 0.5
                        let faceX = Float(face.displayPos.x)
                        let faceY = Float(face.displayPos.y)
                        let inMouse = mouseInFrameX > faceX - size && mouseInFrameY > faceY - size && mouseInFrameX < faceX + size && mouseInFrameY < faceY + size;
                        
                        if(inMouse) {
                            let relPos = SIMD2<Float>(x: Float(face.displayPos.x) - mouseInFrameX, y: Float(face.displayPos.y) - mouseInFrameY)
                            selectedFace = face
                            selectedIndex = i
                            selectedRelPos = relPos
                            
                            selectedFaces.append(FaceSelection(locRelToMouse: relPos, face: face, index: i))
                        }
                    }
                    
                    if(!mouseDown && pMouseDown) {
                        for movedFace in movedFaces {
                            let _ = faceNetwork.requestUpdateFiles(updatedFace: movedFace.face)
                        }
                    }
                    
                    movedFaces = [FaceSelection]()
                    if(!NetworkView.allowMultipleSelection && selectedFace != nil) {
                        movedFaces = [FaceSelection(locRelToMouse: selectedRelPos!, face: selectedFace!, index: selectedIndex)]
                    } else {
                        movedFaces = selectedFaces
                    }
                }
                if(!NetworkView.allowMultipleSelection) {
                    parent.context?.faceInfo = selectedFace?.createDescription() ?? ""
                } else {
                    parent.context?.faceInfo = ""
                }
                uniforms[0].multipleSelect = NetworkView.allowMultipleSelection
                uniforms[0].selectedFaceIndex = Int32(selectedIndex)
                
                // print(mouseDown)
                
                if(NetworkView.mouseDown) {
                    if(NetworkView.allowEditing) {
                        for face in movedFaces {
                            let tx = mouseInFrameX + face.locRelToMouse.x
                            let ty = mouseInFrameY + face.locRelToMouse.y
                            faceObjPtr?[face.index].x = tx
                            faceObjPtr?[face.index].y = ty
                            face.face.updateDisplayPosition(newPosition: DoublePoint(x: Double(tx), y: Double(ty)))
                        }
                    } else {
                        let mouseStep = mouse - pMousePos
                        camera.x -= mouseStep.x * 0.005 / scale
                        camera.y -= mouseStep.y * 0.005 / scale
                    }
                }
                
                if(allowMultipleSelection) {
                    drawMouse(encoder: renderEncoder, mouseX: mouseInFrameX, mouseY: mouseInFrameY)
                }
                
                renderEncoder.setRenderPipelineState(pipelineState)
                renderEncoder.setObjectBuffer(faceObjBuffer, offset: 0, index: BufferIndex.object.rawValue)
                renderEncoder.setObjectBuffer(dynamicUniformBuffer, offset: uniformBufferOffset, index: BufferIndex.uniforms.rawValue)
                for textureBatch in self.arrayTextures {
                    renderEncoder.setObjectBuffer(self.createFaceCountBuffer(batchIndex: bi), offset: 0, index: BufferIndex.faceCount.rawValue)
                    renderEncoder.setFragmentTexture(textureBatch, index: TextureIndex.color.rawValue)
                    renderEncoder.drawMeshThreads(MTLSize(width: faceNetwork.faces.count, height: 1, depth: 1),
                                                  threadsPerObjectThreadgroup: MTLSize(width: 1, height: 1, depth: 1),
                                                  threadsPerMeshThreadgroup: MTLSize(width: 8, height: 1, depth: 1))
                    bi += 1
                }
                
                renderEncoder.popDebugGroup()
                renderEncoder.endEncoding()
                
                if let drawable = view.currentDrawable {
                    commandBuffer.present(drawable)
                }
            }
            commandBuffer.commit()
            
            pMouseDown = mouseDown
            pMousePos = mouse
            NetworkEditor.networkDisplayedFacemapBuffer = self.faceObjBuffer
            NetworkEditor.networkDisplayedPointDistanceBuffer = self.pointDistanceBuffer
        }
        
        func drawMouse(encoder: MTLRenderCommandEncoder, mouseX: Float, mouseY: Float) {
            encoder.pushDebugGroup("Mouse")
            encoder.setRenderPipelineState(mousePipeline)
            let mousePosition = [mouseX, mouseY]
            encoder.setVertexBytes(mousePosition, length: MemoryLayout<Float>.stride * 2, index: 1)
            encoder.setVertexBuffer(dynamicUniformBuffer, offset: uniformBufferOffset, index: 2)
            encoder.setFragmentTexture(mouseTexture, index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            encoder.popDebugGroup()
        }
        
        static func buildFaceMeshletRenderPipelineState(metalDevice: MTLDevice, parent: NetworkView) throws -> MTLRenderPipelineState? {
            let pipelineDescriptor = MTLMeshRenderPipelineDescriptor()
            guard let library = metalDevice.makeDefaultLibrary() else {
                return nil
            }
            let meshFunction = library.makeFunction(name: "faceObjectShader")
            let meshletFunction = library.makeFunction(name: "faceMeshletShader")
            let fragmentFunction = library.makeFunction(name: "fragmentShader")
            
            pipelineDescriptor.label = "FacesRenderPipeline"
            pipelineDescriptor.rasterSampleCount = parent.mtlSampleCount
            pipelineDescriptor.objectFunction = meshFunction
            pipelineDescriptor.meshFunction = meshletFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            
            pipelineDescriptor.colorAttachments[0].pixelFormat = parent.colourPixelFormat
            pipelineDescriptor.depthAttachmentPixelFormat = parent.depthPixelFormat
            pipelineDescriptor.stencilAttachmentPixelFormat = parent.depthPixelFormat
            
            let a: MTLPipelineOption = MTLPipelineOption()
            let state: MTLRenderPipelineState
            (state, _) = try metalDevice.makeRenderPipelineState(descriptor: pipelineDescriptor, options: a)
            
            return state
        }
        
        static func buildMouseRenderPipelineState(metalDevice: MTLDevice, parent: NetworkView) throws -> MTLRenderPipelineState? {
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            guard let library = metalDevice.makeDefaultLibrary() else {
                return nil
            }
            let vertexFunction = library.makeFunction(name: "mouseVertex")
            let fragmentFunction = library.makeFunction(name: "mouseFragment")
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = parent.colourPixelFormat
            pipelineDescriptor.depthAttachmentPixelFormat = parent.depthPixelFormat
            pipelineDescriptor.stencilAttachmentPixelFormat = parent.depthPixelFormat
            
            let a: MTLPipelineOption = MTLPipelineOption()
            let state: MTLRenderPipelineState
            (state, _) = try metalDevice.makeRenderPipelineState(descriptor: pipelineDescriptor, options: a)
            
            return state
        }
        
        func createFaceCountBuffer(batchIndex: Int) -> MTLBuffer? {
            guard let buffer = metalDevice.makeBuffer(length: MemoryLayout<UInt>.stride, options: [.storageModeShared]) else {
                return nil
            }
            let faceCountMem = UnsafeMutableRawPointer(buffer.contents()).bindMemory(to: UInt.self, capacity:2)
            faceCountMem[0] = UInt(network!.faces.count)
            faceCountMem[1] = UInt(batchIndex)
            return buffer
        }
        
        func createMouseRenderBuffer() -> MTLBuffer? {
            guard let buffer = metalDevice.makeBuffer(length: MemoryLayout<UInt>.stride, options: [.storageModeShared]) else {
                return nil
            }
            let faceCountMem = UnsafeMutableRawPointer(buffer.contents()).bindMemory(to: UInt.self, capacity:2)
            faceCountMem[0] = UInt(0)
            faceCountMem[1] = UInt(0)
            return buffer
        }
        
        func loadBundledTexture(name: String) throws -> MTLTexture {
            let textureLoader = MTKTextureLoader(device: metalDevice)
            let textureLoaderOptions = [
                MTKTextureLoader.Option.textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
                MTKTextureLoader.Option.textureStorageMode: NSNumber(value: MTLStorageMode.`private`.rawValue)
            ]
            return try textureLoader.newTexture(name: name, scaleFactor: 1.0, bundle: nil, options: textureLoaderOptions)
        }
        
        static func createArrayTextureDescriptor(device: MTLDevice, size: CGSize, layers: Int, pixelFormat: MTLPixelFormat) -> MTLTextureDescriptor? {
            let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat,
                                                                             width: Int(size.width),
                                                                             height: Int(size.height),
                                                                             mipmapped: false)
            textureDescriptor.textureType = .type2DArray
            textureDescriptor.arrayLength = layers
            textureDescriptor.usage = [.shaderRead]
            textureDescriptor.storageMode = .private

            return textureDescriptor
        }
        
        func createEmptyArrayTexture() -> MTLTexture? {
            return metalDevice.makeTexture(descriptor: textureDescriptor)
        }
        
        func loadImagesIntoTexture() {
            guard var commandBuffer = metalCommandQueue.makeCommandBuffer(),
            var blitCommandEncoder = commandBuffer.makeBlitCommandEncoder() else {
                return
            }
            
            guard let faces = network?.faces else {
                return
            }
            
            var arrayTextureIndex = 0, singleTextureIndex = 0
            var workingArrayTexture = createEmptyArrayTexture()!
            
            for face in faces {
                if(singleTextureIndex == FACE_TEXTURE_BATCH_SIZE) {
                    blitCommandEncoder.endEncoding()
                    commandBuffer.commit()
                    commandBuffer.waitUntilCompleted()
                    
                    singleTextureIndex = 0
                    arrayTextureIndex += 1
                    
                    self.arrayTextures.append(workingArrayTexture)
                    workingArrayTexture = createEmptyArrayTexture()!
                    
                    commandBuffer = metalCommandQueue.makeCommandBuffer()!
                    blitCommandEncoder = commandBuffer.makeBlitCommandEncoder()!
                }
                
                if let newTexture = face.texture {
                    blitCommandEncoder.copy(from: newTexture,
                                            sourceSlice: 0,
                                            sourceLevel: 0,
                                            sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                                            sourceSize: MTLSize(width: self.textureSliceSize, height: self.textureSliceSize, depth: 1),
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
                    self.arrayTextures.append(workingArrayTexture)
                    // The loop will end after this no matter what
                    break
                }
            }
            
            print("\(arrayTextures.count) texture batches created, sized \(FACE_TEXTURE_BATCH_SIZE)")
        }
    }
}

class CustomizedMetalView: MTKView {
    var camera: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    var mouseDraggedFunction: (NSEvent) -> Void = {_ in }
    var mouseWheelFunction: (NSEvent) -> Void = {_ in }
    var mouseExit: (NSEvent) -> Void = {_ in }
    var mouseMove: (NSEvent, MTKView) -> Void = {_,_  in }
    var mouseDownFunc: (NSEvent) -> Void = {_ in }
    var mouseUpFunc: (NSEvent) -> Void = {_ in }
    override var acceptsFirstResponder: Bool {get{return true}}
    
    override func updateTrackingAreas() {
         let area = NSTrackingArea(rect: self.bounds,
                                   options: [NSTrackingArea.Options.activeAlways,
                                             NSTrackingArea.Options.mouseMoved,
                                             NSTrackingArea.Options.enabledDuringMouseDrag],
                                   owner: self,
                                   userInfo: nil)
         self.addTrackingArea(area)
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        mouseExit(event)
    }
    
    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        mouseMove(event, self)
    }
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        //print("Mouse down at location: \(event.locationInWindow)")
        // Handle mouse down event
        mouseDownFunc(event)
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        //print("Mouse up at location: \(event.locationInWindow)")
        // Handle mouse up event
        mouseUpFunc(event)
    }

    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        //print("Mouse dragged to location: \(event.locationInWindow)")
        // Handle mouse dragged event
        mouseDraggedFunction(event)
    }

    override func rightMouseDown(with event: NSEvent) {
        super.rightMouseDown(with: event)
        //print("Right mouse down at location: \(event.locationInWindow)")
        // Handle right mouse down event
    }

    override func rightMouseUp(with event: NSEvent) {
        super.rightMouseUp(with: event)
        //print("Right mouse up at location: \(event.locationInWindow)")
        // Handle right mouse up event
    }

    override func otherMouseDown(with event: NSEvent) {
        super.otherMouseDown(with: event)
        //print("Other mouse button down at location: \(event.locationInWindow)")
        // Handle other mouse button down event
    }

    override func otherMouseUp(with event: NSEvent) {
        super.otherMouseUp(with: event)
        //print("Other mouse button up at location: \(event.locationInWindow)")
        // Handle other mouse button up event
    }
    
    override func scrollWheel(with event: NSEvent) {
        super.scrollWheel(with: event)
        mouseWheelFunction(event)
    }
}
