//
//  BackgroundRenderPass.swift
//  SAOLinkStart
//
//  Created by Cyandev on 2022/5/26.
//

import Metal

class BackgroundRenderPass: RenderPass {
    
    private var _inputRenderTarget: MTLTexture!
    private var renderPipelineState: MTLRenderPipelineState!
    private var vertexBuffer: MTLBuffer!
    
    var backgroundAlpha: Float = 1
    
    var inputRenderTarget: MTLTexture {
        return _inputRenderTarget
    }
    
    func prepare() {
        guard let renderContext = RenderContext.current else {
            fatalError("No active RenderContext.")
        }
        
        let device = renderContext.device
        let library = renderContext.defaultLibrary
        
        // Prepare render pipeline.
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.vertexFunction = library.makeFunction(name: "backgroundVertex")
        renderPipelineDescriptor.fragmentFunction = library.makeFunction(name: "backgroundFragment")
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = renderContext.targetPixelFormat
        renderPipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        renderPipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        renderPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        renderPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
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
        
        // Recreate render target texture.
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.width = Int(size.width)
        textureDescriptor.height = Int(size.height)
        textureDescriptor.pixelFormat = renderContext.targetPixelFormat
        textureDescriptor.storageMode = .private
        textureDescriptor.usage = [.renderTarget, .shaderRead]
        guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
            fatalError("Failed to create offscreen texture.")
        }
        _inputRenderTarget = texture
    }
    
    func render(with renderPassDescriptor: MTLRenderPassDescriptor, commandBuffer: MTLCommandBuffer) {
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = .init(red: 0, green: 0, blue: 0, alpha: 0)
        
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            fatalError("Failed to create command encoder")
        }
        
        encoder.setRenderPipelineState(renderPipelineState)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setFragmentTexture(inputRenderTarget, index: 0)
        withUnsafeBytes(of: &backgroundAlpha) {
            encoder.setFragmentBytes($0.baseAddress!, length: MemoryLayout<Float>.stride, index: 0)
        }
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
    }
    
}
