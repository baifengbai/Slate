//
//  Renderer.swift
//  Slate
//
//  Created by John Coates on 9/29/16.
//  Copyright © 2016 John Coates. All rights reserved.
//

import Metal
import MetalKit
import CoreVideo
import AVFoundation

struct Vertex {
    var position: float4
}

@objc class Renderer: NSObject, MTKViewDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    weak var view: MTKView!
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let renderPipelineState: MTLRenderPipelineState
    var vertices = [Vertex]()
    var textureCoordinates = [float2]()
    var vertexBuffer: MTLBuffer
    var textureCoordinatesBuffer: MTLBuffer
    
    init?(metalView: MTKView) {
        view = metalView
        view.clearColor = MTLClearColorMake(1, 1, 1, 1)
        view.colorPixelFormat = .bgra8Unorm
        
        device = Renderer.getDevice()
        
        // Create the command queue to submit work to the GPU
        commandQueue = device.makeCommandQueue()
        
        do {
            renderPipelineState = try Renderer.buildRenderPipeline(device: device,
                                                                   view: metalView)
        } catch {
            print("Unable to compile render pipeline state")
            return nil
        }
        
        vertexBuffer = Renderer.generateQuad(forDevice: device, inArray: &vertices)
        textureCoordinatesBuffer = Renderer.generate(textureCoordinates: &textureCoordinates, forDevice: device)
        super.init()
        setUpVideoQuadTexture()
        startCapturingVideo()
        view.delegate = self
        view.device = device
    }
    
    // MARK: - Startup
    
    class func getDevice() -> MTLDevice {
        #if os(iOS)
            if let defaultDevice = MTLCreateSystemDefaultDevice() {
                return defaultDevice
            } else {
                fatalError("Metal is not supported")
            }
        #endif
        
        #if os(macOS)
            let devices = MTLCopyAllDevices()
            switch devices.count {
            case 0:
                fatalError("Metal is not supported")
            case 2:
                // temporary workaround for bug that gives bad
                // performance on discrete GPU
                return devices[1]
            default:
                return devices[0]
            }
        #endif
    }
    
    // developer.apple.com/library/content/documentation/Miscellaneous/
    // Conceptual/MetalProgrammingGuide/Render-Ctx/Render-Ctx.html
    
    // Metal defines its Normalized Device Coordinate (NDC) system as a 2x2x1 cube with its center a
    // (0, 0, 0.5). The left and bottom for x and y, respectively, of the NDC system are specified as -1.
    // The right and top for x and y, respectively, of the NDC system are specified as +1.
    class func generateQuad(forDevice device: MTLDevice, inArray vertices: inout [Vertex]) -> MTLBuffer {
        vertices.append(Vertex(position: float4(-1, -1, 0, 1))) // left bottom
        vertices.append(Vertex(position: float4(1, -1, 0, 1))) // right bottom
        vertices.append(Vertex(position: float4(-1, 1, 0, 1))) // left top
        vertices.append(Vertex(position: float4(1, -1, 0, 1))) // right bottom
        vertices.append(Vertex(position: float4(-1, 1, 0, 1))) // left top
        vertices.append(Vertex(position: float4(1, 1, 0, 1))) // right top
        
        var options: MTLResourceOptions = []
        #if os(macOS)
            options = [.storageModeManaged]
        #endif
        
        return device.makeBuffer(bytes: vertices,
                                 length: MemoryLayout<Vertex>.stride * vertices.count,
                                 options: options)
    }
    
    class func generate(textureCoordinates coordinates: inout[float2], forDevice device: MTLDevice) -> MTLBuffer {
        
        var options: MTLResourceOptions = []
        #if os(macOS)
            coordinates += macHorizontalFlipped()
            options = [.storageModeManaged]
        #endif
        
        #if os(iOS)
            coordinates += iOSCoordinates()
        #endif
        
        return device.makeBuffer(bytes: coordinates,
                                 length: MemoryLayout<float2>.stride * coordinates.count,
                                 options: options)
    }
    
    class func iOSCoordinates() -> [float2] {
        return [
            float2(1, 0),
            float2(1, 1),
            float2(0, 0),
            float2(1, 1),
            float2(0, 0),
            float2(0, 1)
        ]
    }
    class func macFlipped() -> [float2] {
        var coordinates = [float2]()
        coordinates.append(float2(0, 1))
        coordinates.append(float2(1, 1))
        coordinates.append(float2(0, 0))
        coordinates.append(float2(1, 1))
        coordinates.append(float2(0, 0))
        coordinates.append(float2(1, 0))
        return coordinates
    }
    
    class func macHorizontalFlipped() -> [float2] {
        var coordinates = [float2]()
        coordinates.append(float2(1, 1))
        coordinates.append(float2(0, 1))
        coordinates.append(float2(1, 0))
        coordinates.append(float2(0, 1))
        coordinates.append(float2(1, 0))
        coordinates.append(float2(0, 0))
        return coordinates
    }
    
    class func buildRenderPipeline(device: MTLDevice, view: MTKView) throws -> MTLRenderPipelineState {
        // The default library contains all of the shader functions that were compiled into our app bundle
        guard let library = device.newDefaultLibrary() else {
            fatalError("Couldn't find shader libary")
        }
        
        // Retrieve the functions that will comprise our pipeline
        let vertexFunction = library.makeFunction(name: "vertexPassthrough")
        let fragmentFunction = library.makeFunction(name: "fragmentPassthrough")
        
        // A render pipeline descriptor describes the configuration of our programmable pipeline
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = "Render Pipeline"
        pipelineDescriptor.sampleCount = view.sampleCount
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat
        
        // compile intermediate shaders into hardward-optimized code
        return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
    
    // MARK: - Render
    
    func render(_ view: MTKView) {
        // Our command buffer is a container for the work we want to perform with the GPU.
        let commandBuffer = commandQueue.makeCommandBuffer()
        
        // Ask the view for a configured render pass descriptor. It will have a loadAction of
        // MTLLoadActionClear and have the clear color of the drawable set to our desired clear color.
        guard let currentDrawable = view.currentDrawable else {
            fatalError("no drawable!")
        }
        //        let renderPassDescriptor = view.currentRenderPassDescriptor
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(1, 1, 1, 1)
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .dontCare
        #if METAL_DEVICE
            renderPassDescriptor.colorAttachments[0].texture = currentDrawable.texture
        #endif
        
        // Create a render encoder to clear the screen and draw our objects
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        
        renderTextureQuad(renderEncoder: renderEncoder, view: view, identifier: "video texture")
        
        // We are finished with this render command encoder, so end it.
        renderEncoder.endEncoding()
        
        // Tell the system to present the cleared drawable to the screen.
        commandBuffer.present(currentDrawable)
        
        // Now that we're done issuing commands, we commit our buffer so the GPU can get to work.
        commandBuffer.commit()
    }
    
    // MARK: - Texture
    
    func setUpVideoQuadTexture() {
        #if METAL_DEVICE
        guard CVMetalTextureCacheCreate(kCFAllocatorDefault,
                                        nil, // cache attributes
            device,
            nil, // texture attributes
            &textureCache) == kCVReturnSuccess else {
                fatalError("Couldn't create a texture cache")
        }
        #endif
        
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.label = "video texture sampler"
        sampler = device.makeSamplerState(descriptor: samplerDescriptor)
        guard sampler != nil else {
            fatalError("Couldn't create a texture sampler")
        }
    }
    
    // MARK: - Video
    
    var session: AVCaptureSession!
    var texture: MTLTexture?
    var sampler: MTLSamplerState!
    
    #if METAL_DEVICE
    var textureCache: CVMetalTextureCache?
    #endif
    
    func startCapturingVideo() {
        session = AVCaptureSession()
        session.beginConfiguration()
        
        session.sessionPreset = AVCaptureSessionPresetHigh
        let camera = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            session.addInput(input)
        } catch {
            print("Couldn't instantiate device input")
            return
        }
        
        let dataOutput = AVCaptureVideoDataOutput()
        dataOutput.alwaysDiscardsLateVideoFrames = true
        printAvailableFormatTypes(forDataOutput: dataOutput)
        dataOutput.videoSettings = captureVideoSettings
        
        // Set dispatch to be on the main thread to create the texture in memory
        // and allow Metal to use it for rendering
        dataOutput.setSampleBufferDelegate(self, queue: DispatchQueue.main)
        
        session.addOutput(dataOutput)
        session.commitConfiguration()
        session.startRunning()
    }
    
    var captureVideoSettings: [AnyHashable: AnyObject] {
        get {
            let pixelFormatKey = String(kCVPixelBufferPixelFormatTypeKey)
            let pixelFormat = kCVPixelFormatType_32BGRA
            let metalCompatibilityKey = String(kCVPixelBufferMetalCompatibilityKey)
            
            var videoSettings = [AnyHashable: AnyObject]()
            videoSettings[pixelFormatKey] = NSNumber(value: pixelFormat)
            #if os(macOS)
                videoSettings[metalCompatibilityKey] = NSNumber(value: true)
            #endif
            
            return videoSettings
        }
    }
    
    func printAvailableFormatTypes(forDataOutput dataOutput: AVCaptureVideoDataOutput) {
        #if os(iOS)
            return
        #endif
        
        #if os(macOS)
            guard let formatTypes = dataOutput.availableVideoCVPixelFormatTypes else {
                print("no available format types!")
                return
            }
            
            for formatType in formatTypes {
                guard let type = formatType as? Int else {
                    continue
                }
                let intType = UInt32(type)
                let osType = UTCreateStringForOSType(intType).takeRetainedValue() as String
                print("available pixel format type: \(osType)")
            }
        #endif
    }
    
    // MARK: - Video Delegate
    
    var frame = 0
    func captureOutput(_ captureOutput: AVCaptureOutput!,
                       didOutputSampleBuffer sampleBuffer: CMSampleBuffer!,
                       from connection: AVCaptureConnection!) {
        #if METAL_DEVICE
        guard let textureCache = textureCache else {
            print("Missing texture cache!")
            return
        }
            
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Couldn't get image buffer")
            return
        }
        
        var optionalTextureRef: CVMetalTexture? = nil
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        let returnValue = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                                    textureCache,
                                                                    imageBuffer,
                                                                    nil,
                                                                    .bgra8Unorm,
                                                                    width, height, 0,
                                                                    &optionalTextureRef)
        
        guard returnValue == kCVReturnSuccess, let textureRef = optionalTextureRef else {
            print("Error, couldn't create texture from image, error: \(returnValue), \(optionalTextureRef)")
            return
        }
        
        guard let texture = CVMetalTextureGetTexture(textureRef) else {
            print("Error, Couldn't get texture")
            return
        }
        
        self.texture = texture
        frame += 1
        
        if frame % 10 == 0 {
//            print("new frame: \(frame)")
        }
        #endif
    }
    
    func renderTextureQuad(renderEncoder: MTLRenderCommandEncoder, view: MTKView, identifier: String) {
        guard let texture = texture else {
            return
        }
        renderEncoder.pushDebugGroup(identifier)
        // Set the pipeline state so the GPU knows which vertex and fragment function to invoke.
        renderEncoder.setRenderPipelineState(renderPipelineState)
        renderEncoder.setFrontFacing(.counterClockwise)
        
        // Bind the buffer containing the array of vertex structures so we can
        // read it in our vertex shader.
        renderEncoder.setVertexBuffer(vertexBuffer, offset:0, at:0)
        renderEncoder.setVertexBuffer(textureCoordinatesBuffer, offset: 0, at: 1)
        renderEncoder.setFragmentTexture(texture, at: 0)
        renderEncoder.setFragmentSamplerState(sampler, at: 0)
        renderEncoder.drawPrimitives(type: .triangle,
                                     vertexStart: 0,
                                     vertexCount: 6,
                                     instanceCount: 1)
        renderEncoder.popDebugGroup()
    }
    
    // MARK: - Buffer Updates
    
    #if os(macOS)
    func invalidateVertexBuffer() {
        let contents = vertexBuffer.contents()
        memcpy(contents, vertices, MemoryLayout<Vertex>.stride * vertices.count)
        let length = vertexBuffer.length
        let range = NSRange(location: 0, length: length)
        vertexBuffer.didModifyRange(range)
    }
    
    func invalidateTextureCoordinatesBuffer() {
        let contents = textureCoordinatesBuffer.contents()
        memcpy(contents, textureCoordinates, MemoryLayout<float2>.stride * textureCoordinates.count)
        let length = textureCoordinatesBuffer.length
        let range = NSRange(location: 0, length: length)
        textureCoordinatesBuffer.didModifyRange(range)
    }
    #endif
    
    // MARK: - Metal View Delegate
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // respond to resize
    }
    
    @objc(drawInMTKView:)
    func draw(in metalView: MTKView) {
        render(metalView)
    }
}
