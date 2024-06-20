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
    
    func mouseDragged(with event: NSEvent) {
        NetworkView.camera.x = NetworkView.camera.x + Float(event.deltaX) * 0.02
        NetworkView.camera.y = NetworkView.camera.y + Float(event.deltaY) * -0.02
    }
    
    func mouseWheel(with event: NSEvent) {
        NetworkView.camera.z = NetworkView.camera.z + Float(event.scrollingDeltaY) * 0.02
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
        var depthState: MTLDepthStencilState
        var debugTexture: MTLTexture?
        var textureDescriptor: MTLTextureDescriptor
        var arrayTextures: [MTLTexture] = []
        var textureSliceSize: Int
        
        init(_ parent: NetworkView) {
            self.parent = parent
            guard let md = GPUManager.instance?.getMTLDevice() else {
                fatalError(String(localized: "Failed to initialise Metal 3 environment."))
            }
            self.metalDevice = md
            self.metalCommandQueue = metalDevice.makeCommandQueue()!
            
            guard let buffer = self.metalDevice.makeBuffer(length: alignedUniformsSize, options:[MTLResourceOptions.storageModeShared]) else { fatalError(String(localized: "Failed to initialise Metal 3 environment.")) }
            dynamicUniformBuffer = buffer
            uniforms = UnsafeMutableRawPointer(dynamicUniformBuffer.contents()).bindMemory(to:Uniforms.self, capacity:1)
            self.pipelineState = try! NetworkView.Coordinator.buildFaceMeshletRenderPipelineState(metalDevice: metalDevice, parent: parent)!
            
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
            
            for i in 0..<network.faces.count {
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
            debugTexture = try? DEBUG_loadDebugTexture()
            loadImagesIntoTexture()
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            let aspect = Float(size.width) / Float(size.height)
            //print(aspect)
            projectionMatrix = matrix_perspective_right_hand(fovyRadians: radians_from_degrees(65), aspectRatio:aspect, nearZ: 0.1, farZ: 100.0)
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
            
            uniforms[0].projectionMatrix = projectionMatrix
            let pos = NetworkView.camera

            //let modelMatrix = matrix4x4_rotation(radians: rotate.y, axis: rotationAxis)
            let modelMatrix = matrix4x4_translation(0, 0, 0)
            let viewMatrix = matrix4x4_translation(pos.x, pos.y, pos.z)
            uniforms[0].modelViewMatrix = simd_mul(viewMatrix, modelMatrix)
            
            let renderPassDescriptor = view.currentRenderPassDescriptor
            if let renderPassDescriptor = renderPassDescriptor, let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
                renderEncoder.label = "Primary Render Encoder"
                renderEncoder.pushDebugGroup("Draw Faces")
                
                renderEncoder.setCullMode(.none)
                renderEncoder.setFrontFacing(.counterClockwise)
                renderEncoder.setRenderPipelineState(pipelineState)
                renderEncoder.setDepthStencilState(depthState)
                var bi = 0
                
                for textureBatch in self.arrayTextures {
                    renderEncoder.setObjectBuffer(faceObjBuffer, offset: 0, index: BufferIndex.object.rawValue)
                    renderEncoder.setObjectBuffer(dynamicUniformBuffer, offset: uniformBufferOffset, index: BufferIndex.uniforms.rawValue)
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
        
        func createFaceCountBuffer(batchIndex: Int) -> MTLBuffer? {
            guard let buffer = metalDevice.makeBuffer(length: MemoryLayout<UInt>.stride, options: [.storageModeShared]) else {
                return nil
            }
            let faceCountMem = UnsafeMutableRawPointer(buffer.contents()).bindMemory(to: UInt.self, capacity:2)
            faceCountMem[0] = UInt(network!.faces.count)
            faceCountMem[1] = UInt(batchIndex)
            return buffer
        }
        
        func DEBUG_loadDebugTexture() throws -> MTLTexture {
            let textureLoader = MTKTextureLoader(device: metalDevice)
            let textureLoaderOptions = [
                MTKTextureLoader.Option.textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
                MTKTextureLoader.Option.textureStorageMode: NSNumber(value: MTLStorageMode.`private`.rawValue)
            ]
            return try textureLoader.newTexture(name: "img", scaleFactor: 1.0, bundle: nil, options: textureLoaderOptions)
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
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        print("Mouse down at location: \(event.locationInWindow)")
        // Handle mouse down event
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        print("Mouse up at location: \(event.locationInWindow)")
        // Handle mouse up event
    }

    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        //print("Mouse dragged to location: \(event.locationInWindow)")
        // Handle mouse dragged event
        mouseDraggedFunction(event)
    }

    override func rightMouseDown(with event: NSEvent) {
        super.rightMouseDown(with: event)
        print("Right mouse down at location: \(event.locationInWindow)")
        // Handle right mouse down event
    }

    override func rightMouseUp(with event: NSEvent) {
        super.rightMouseUp(with: event)
        print("Right mouse up at location: \(event.locationInWindow)")
        // Handle right mouse up event
    }

    override func otherMouseDown(with event: NSEvent) {
        super.otherMouseDown(with: event)
        print("Other mouse button down at location: \(event.locationInWindow)")
        // Handle other mouse button down event
    }

    override func otherMouseUp(with event: NSEvent) {
        super.otherMouseUp(with: event)
        print("Other mouse button up at location: \(event.locationInWindow)")
        // Handle other mouse button up event
    }
    
    override func scrollWheel(with event: NSEvent) {
        super.scrollWheel(with: event)
        mouseWheelFunction(event)
    }
}
