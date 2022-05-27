//
//  PostFXRenderPass.swift
//  SAOLinkStart
//
//  Created by Cyandev on 2022/5/26.
//

import Metal

class PostFXRenderPass: RenderPass {
    
    private struct _OffscreenTexture {
        let texture: MTLTexture
        var hasContents = false
    }
    
    private var offscreenTextures = [_OffscreenTexture]()
    private var currentOffscreenTextureIndex = 0
    private var renderPipelineState: MTLRenderPipelineState!
    private var vertexBuffer: MTLBuffer!
    
    var inputRenderTarget: MTLTexture {
        return offscreenTextures[currentOffscreenTextureIndex].texture
    }
    
    func prepare() {
        guard let renderContext = RenderContext.current else {
            fatalError("No active RenderContext.")
        }
        
        let device = renderContext.device
        let library = renderContext.defaultLibrary
        
        // Prepare render pipeline.
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.vertexFunction = library.makeFunction(name: "postFXVertex")
        renderPipelineDescriptor.fragmentFunction = library.makeFunction(name: "postFXFragment")
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = renderContext.targetPixelFormat
        do {
            renderPipelineState = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        } catch {
            fatalError(error.localizedDescription)
        }
        
        // Prepare vertex buffer.
        vertexBuffer = RenderPassCommon.makeQuadTextureVertexBuffer()
    }
    
    func drawableDidUpdateSize(_ size: CGSize) {
        guard let renderContext = RenderContext.current else {
            fatalError("No active RenderContext.")
        }
        
        let device = renderContext.device
        
        func makeTexture() -> _OffscreenTexture {
            let textureDescriptor = MTLTextureDescriptor()
            textureDescriptor.width = Int(size.width)
            textureDescriptor.height = Int(size.height)
            textureDescriptor.pixelFormat = renderContext.targetPixelFormat
            textureDescriptor.storageMode = .private
            textureDescriptor.usage = [.renderTarget, .shaderRead]
            guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
                fatalError("Failed to create PostFX offscreen texture.")
            }
            return .init(texture: texture, hasContents: false)
        }
        
        offscreenTextures = [makeTexture(), makeTexture()]
    }
    
    func render(with renderPassDescriptor: MTLRenderPassDescriptor, commandBuffer: MTLCommandBuffer) {
        renderPassDescriptor.colorAttachments[0].loadAction = .dontCare
        
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            fatalError("Failed to create command encoder")
        }
        
        encoder.setRenderPipelineState(renderPipelineState)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setFragmentTexture(offscreenTextures[0].texture, index: 0)
        if offscreenTextures[1].hasContents {
            encoder.setFragmentTexture(offscreenTextures[1].texture, index: 1)
        } else {
            encoder.setFragmentTexture(offscreenTextures[0].texture, index: 1)
        }
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
        
        offscreenTextures[currentOffscreenTextureIndex].hasContents = true
        currentOffscreenTextureIndex = (currentOffscreenTextureIndex + 1) % 2
    }
    
}
