//
//  SceneView.swift
//  SAOLinkStart
//
//  Created by Cyandev on 2022/5/25.
//

import MetalKit

class SceneView: MTKView {
    
    let renderContext: RenderContext
    let sceneRenderer: SceneRenderer
    
    var sceneUpdater: (() -> ())?
    
    init(frame frameRect: CGRect, device: MTLDevice) {
        renderContext = .init(device: device)
        sceneRenderer = .init()
        
        super.init(frame: frameRect, device: device)
        
        layer?.isOpaque = false
        colorPixelFormat = .bgra8Unorm
        delegate = self
        
        renderContext.targetPixelFormat = colorPixelFormat
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
    
    func prepare() {
        renderContext.performAsCurrent {
            self.sceneRenderer.prepare()
        }
    }
    
}

extension SceneView: MTKViewDelegate {
    
    func draw(in view: MTKView) {
        renderContext.currentRenderPassDescriptor = {
            return view.currentRenderPassDescriptor!
        }
        renderContext.currentDrawable = {
            return view.currentDrawable!
        }
        renderContext.drawableSize = view.bounds.size
        
        renderContext.performAsCurrent {
            self.sceneUpdater?()
            self.sceneRenderer.render()
        }
        
        // Release these temporary resources for good.
        renderContext.currentDrawable = nil
        renderContext.currentRenderPassDescriptor = nil
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        renderContext.performAsCurrent {
            self.sceneRenderer.drawableDidUpdateSize(size)
        }
    }
    
}
