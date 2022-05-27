//
//  SceneRenderer.swift
//  SAOLinkStart
//
//  Created by Cyandev on 2022/5/24.
//

import Metal
import QuartzCore

struct Transform {
    
    var translation: simd_float3
    var scale: simd_float3
    var rotation: simd_float3
    
    init(translation: simd_float3, scale: simd_float3, rotation: simd_float3) {
        self.translation = translation
        self.scale = scale
        self.rotation = rotation
    }
    
    init() {
        translation = .zero
        scale = .init(x: 1, y: 1, z: 1)
        rotation = .zero
    }
    
}

/// An object that can be rendered by `SceneRenderer`.
class RenderNode {
    
    var transform: Transform = .init()
    var geometryRenderer: GeometryRenderer
    var alpha: Float = 1.0
    var color: simd_float4 = .init(1.0, 1.0, 1.0, 1.0)
    var isBillboard: Bool = false
    
    init(transform: Transform, geometryRenderer: GeometryRenderer) {
        self.transform = transform
        self.geometryRenderer = geometryRenderer
    }
    
    init(geometryRenderer: GeometryRenderer) {
        self.geometryRenderer = geometryRenderer
    }
    
}

/// A type that represents a render pass for scenes' multi-pass rendering.
protocol RenderPass {
    
    var inputRenderTarget: MTLTexture { get }
    
    func prepare()
    
    func drawableDidUpdateSize(_ size: CGSize)
    
    func render(with renderPassDescriptor: MTLRenderPassDescriptor,
                commandBuffer: MTLCommandBuffer)
    
}

/// A simple scene renderer that helps manage objects to render and related resources.
class SceneRenderer {
    
    private struct _OffscreenTexture {
        let texture: MTLTexture
        var hasContents = false
    }
    
    var renderNodes = [RenderNode]()
    var renderPasses = [RenderPass]()
    
    private let uniformPoolSize = 10_000  // Do you really need to draw this many object? LOL.
    private var uniformPoolBuffer: MTLBuffer!
    private var depthTexture: MTLTexture!
    
    func prepare() {
        guard let renderContext = RenderContext.current else {
            fatalError("No active RenderContext.")
        }
        
        let device = renderContext.device
        let library = renderContext.defaultLibrary
        
        // Prepare geometry render resources.
        let geometryRenderPipelineDescriptor = MTLRenderPipelineDescriptor()
        geometryRenderPipelineDescriptor.vertexFunction = library.makeFunction(name: "geometryVertex")
        geometryRenderPipelineDescriptor.fragmentFunction = library.makeFunction(name: "geometryFragment")
        geometryRenderPipelineDescriptor.colorAttachments[0].pixelFormat = renderContext.targetPixelFormat
        geometryRenderPipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        geometryRenderPipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        geometryRenderPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        geometryRenderPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        geometryRenderPipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        do {
            renderContext.geometryRenderPipelineState =
                try device.makeRenderPipelineState(descriptor: geometryRenderPipelineDescriptor)
        } catch {
            fatalError(error.localizedDescription)
        }
        
        let geometryDepthStencilDescriptor = MTLDepthStencilDescriptor()
        geometryDepthStencilDescriptor.depthCompareFunction = .less
        geometryDepthStencilDescriptor.isDepthWriteEnabled = true
        renderContext.geometryDepthStencilState = device.makeDepthStencilState(descriptor: geometryDepthStencilDescriptor)
        
        guard let uniformPoolBuffer = device.makeBuffer(
            length: MemoryLayout<SAORUniforms>.stride * uniformPoolSize,
            options: .cpuCacheModeWriteCombined
        ) else {
            fatalError("Failed to create uniform buffer.")
        }
        self.uniformPoolBuffer = uniformPoolBuffer
        
        for renderPass in renderPasses {
            renderPass.prepare()
        }
    }
    
    func drawableDidUpdateSize(_ size: CGSize) {
        guard let renderContext = RenderContext.current else {
            fatalError("No active RenderContext.")
        }
        
        let device = renderContext.device
        
        let depthTextureDescriptor = MTLTextureDescriptor()
        depthTextureDescriptor.width = Int(size.width)
        depthTextureDescriptor.height = Int(size.height)
        depthTextureDescriptor.pixelFormat = .depth32Float
        depthTextureDescriptor.storageMode = .private
        depthTextureDescriptor.usage = [.renderTarget]
        depthTexture = device.makeTexture(descriptor: depthTextureDescriptor)
        
        for renderPass in renderPasses {
            renderPass.drawableDidUpdateSize(size)
        }
    }
    
    func render() {
        guard let renderContext = RenderContext.current,
              let currentRenderPassDescriptor = renderContext.currentRenderPassDescriptor,
              let geometryRenderPipelineState = renderContext.geometryRenderPipelineState,
              let geometryDepthStencilState = renderContext.geometryDepthStencilState,
              let currentDrawable = renderContext.currentDrawable else {
            fatalError("No active RenderContext or required resources.")
        }
        
        let drawableSize = renderContext.drawableSize
        let commandQueue = renderContext.commandQueue
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            fatalError("Failed to create command buffer.")
        }
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = renderPasses[0].inputRenderTarget
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = .init(red: 0, green: 0, blue: 0, alpha: 0)
        renderPassDescriptor.depthAttachment.texture = depthTexture
        renderPassDescriptor.depthAttachment.loadAction = .clear
        renderPassDescriptor.depthAttachment.storeAction = .dontCare
        renderPassDescriptor.depthAttachment.clearDepth = 1
        
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            fatalError("Failed to create render command encoder.")
        }
        
        // Perform common setups.
        encoder.setRenderPipelineState(geometryRenderPipelineState)
        encoder.setDepthStencilState(geometryDepthStencilState)
        encoder.setFrontFacing(.counterClockwise)
        encoder.setCullMode(.back)
        
        for (i, renderNode) in renderNodes.enumerated() {
            // Update and encode uniforms for the render node.
            let uniformsPointer = uniformPoolBuffer
                .contents()
                .assumingMemoryBound(to: SAORUniforms.self)
                .advanced(by: i)
            updateUniforms(&uniformsPointer.pointee, for: renderNode, drawableSize: drawableSize)
            
            if i == 0 {
                encoder.setVertexBuffer(uniformPoolBuffer, offset: 0, index: 1)
                encoder.setFragmentBuffer(uniformPoolBuffer, offset: 0, index: 1)
            } else {
                // For the following render nodes, just update the index of uniform buffer
                // instead of rebinding.
                let offset = MemoryLayout<SAORUniforms>.stride * i
                encoder.setVertexBufferOffset(offset, index: 1)
                encoder.setFragmentBufferOffset(offset, index: 1)
            }
            
            // Perform the actual rendering.
            renderNode.geometryRenderer.render(with: renderNode.transform, into: encoder)
        }
        
        encoder.endEncoding()
        commandBuffer.commit()
        
        // Render the final scene with render passes.
        for (i, renderPass) in renderPasses.enumerated() {
            let isLastRenderPass = i == renderPasses.count - 1
            
            let renderPassDescriptor: MTLRenderPassDescriptor = {
                if isLastRenderPass {
                    // Directly render to the framebuffer of scene view.
                    return currentRenderPassDescriptor()
                }
                let renderPassDescriptor = MTLRenderPassDescriptor()
                renderPassDescriptor.colorAttachments[0].texture = renderPasses[i + 1].inputRenderTarget
                return renderPassDescriptor
            }()
            guard let commandBuffer = commandQueue.makeCommandBuffer() else {
                fatalError("Failed to create command buffer.")
            }
            
            renderPass.render(with: renderPassDescriptor, commandBuffer: commandBuffer)
            
            if isLastRenderPass {
                commandBuffer.present(currentDrawable())
            }
            commandBuffer.commit()
        }
    }
    
    private func updateUniforms(_ uniforms: inout SAORUniforms, for renderNode: RenderNode, drawableSize: CGSize) {
        let transform = renderNode.transform
        
        let xRotationMatrix = simd_float4x4(rotation: .init(x: 1, y: 0, z: 0), angle: transform.rotation.x)
        let scaleMatrix = simd_float4x4(scale: transform.scale)
        let translationMatrix = simd_float4x4(translation: transform.translation)
        let modelMatrix = translationMatrix * (xRotationMatrix * scaleMatrix)
        
        let viewMatrix = simd_float4x4(translation: .init(x: 0, y: 0, z: 0)).inverse
        
        let projectionMatrix = simd_float4x4(
            perspectiveWithAspect: Float(drawableSize.width / drawableSize.height),
            fovy: 65.0,
            near: 0.1,
            far: 1000
        )
        
        uniforms.mvpMatrix = projectionMatrix * viewMatrix * modelMatrix
        uniforms.mvMatrix = viewMatrix * modelMatrix
        uniforms.color = renderNode.color
        uniforms.alpha = renderNode.alpha
    }
    
}
