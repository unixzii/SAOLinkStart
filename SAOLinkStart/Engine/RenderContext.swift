//
//  RenderContext.swift
//  SAOLinkStart
//
//  Created by Cyandev on 2022/5/24.
//

import Metal

fileprivate var _currentContext: RenderContext? = nil

/// An object that holds the required context for other rendering components.
///
/// Note:
/// This object is not thread-safe, and must be accessed from main thread.
class RenderContext {
    
    /// The currently active `RenderContext`.
    class var current: RenderContext? {
        assert(Thread.isMainThread, "Must be accessed from main thread!")
        return _currentContext
    }
    
    let device: MTLDevice
    let defaultLibrary: MTLLibrary
    let commandQueue: MTLCommandQueue
    var drawableSize: CGSize = .zero
    var currentRenderPassDescriptor: (() -> MTLRenderPassDescriptor)?
    var currentDrawable: (() -> MTLDrawable)?  // Lazy getter for performance
    var targetPixelFormat: MTLPixelFormat = .bgra8Unorm
    
    var geometryRenderPipelineState: MTLRenderPipelineState?
    var geometryDepthStencilState: MTLDepthStencilState?
    
    init(device: MTLDevice) {
        self.device = device
        guard let library = device.makeDefaultLibrary() else {
            fatalError("Failed to open default library.")
        }
        self.defaultLibrary = library
        guard let queue = device.makeCommandQueue() else {
            fatalError("Failed to create command queue.")
        }
        self.commandQueue = queue
    }
    
    func performAsCurrent<T>(_ action: () -> T) -> T {
        assert(Thread.isMainThread, "Must be called from main thread!")
        _currentContext = self
        defer { _currentContext = nil }
        return action()
    }
    
}
