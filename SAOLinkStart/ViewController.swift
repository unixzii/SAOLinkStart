//
//  ViewController.swift
//  SAOLinkStart
//
//  Created by Cyandev on 2022/5/24.
//

import Cocoa
import MetalKit
import AVFAudio

fileprivate class BeamRenderNode: RenderNode {
    
    var intrinsicSpeed: Float = 0
    
}

fileprivate let beamColors: [simd_float4] = [
    .init(169.0 / 255.0, 0, 27.0 / 255.0, 1.0),              // Red
    .init(207.0 / 255.0, 225.0 / 255.0, 37.0 / 255.0, 1.0),  // Yellow
    .init(0, 219.0 / 255.0, 34.0 / 255.0, 1.0),              // Green
    .init(180.0 / 255.0, 0, 180.0 / 255.0, 1.0),             // Purple
    .init(0, 207.0 / 255.0, 183.0 / 255.0, 1.0),             // Cyan
    .init(92.0 / 255.0, 92.0 / 255.0, 92.0 / 255.0, 1.0),    // Gray
    .init(16.0 / 255.0, 16.0 / 255.0, 16.0 / 255.0, 1.0),    // Matt Black
]

class ViewController: NSViewController {

    var sceneView: SceneView!
    
    let backgroundRenderPass = BackgroundRenderPass()
    let sharedCylinderRenderer = OptimizedCylinderRenderer()
    
    var isFirstAppearance = true
    var currentPhase = 0
    
    var lastEmitTime: CFTimeInterval = 0
    var travelSpeed: Float = 0.005
    var emittedCount: Int = 0
    var birthRate: Float = 1
    
    var soundPlayer: AVAudioPlayer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let device = MTLCreateSystemDefaultDevice()!
        sceneView = .init(frame: .zero, device: device)
        sceneView.sceneUpdater = { [unowned self] in
            self.updateScene()
        }
        view.addSubview(sceneView)
        
        backgroundRenderPass.backgroundAlpha = 0
        
        sceneView.sceneRenderer.renderPasses = [
            backgroundRenderPass,
            PostFXRenderPass(),
        ]
        sceneView.prepare()
        
        sceneView.renderContext.performAsCurrent {
            self.sharedCylinderRenderer.prepareResources()
        }
        
        guard let audioURL = Bundle.main.url(forResource: "linkstart_sfx", withExtension: "m4a") else {
            fatalError("Audio resource is missing.")
        }
        do {
            soundPlayer = try .init(contentsOf: audioURL)
        } catch {
            fatalError("Failed to create audio player: \(error)")
        }
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        let window = view.window!
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.styleMask = .borderless
        window.level = .init(rawValue: NSWindow.Level.mainMenu.rawValue + 1)
        window.setFrame(NSScreen.main!.frame, display: false)
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        if isFirstAppearance {
            isFirstAppearance = false
            startPhase1()
        }
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        
        sceneView.frame = view.bounds
    }
    
}

private extension ViewController {
    
    func startPhase1() {
        guard currentPhase < 1 else {
            fatalError("Invalid phase transition.")
        }
        
        currentPhase = 1
        
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            self.soundPlayer.play()
            Timer.scheduledTimer(withTimeInterval: 1.8, repeats: false) { _ in
                self.startPhase2()
            }
        }
    }
    
    func startPhase2() {
        guard currentPhase < 2 else {
            fatalError("Invalid phase transition.")
        }
        
        currentPhase = 2
        
        sceneView.renderContext.performAsCurrent {
            // Emit some initial beams.
            for _ in 0..<50 {
                self.emitBeam()
            }
            
            // Above emissions don't count :)
            self.emittedCount = 0
        }
    }
    
    func updateScene() {
        guard currentPhase == 2 else {
            return
        }
        
        if emittedCount < 100 {
            backgroundRenderPass.backgroundAlpha += 0.02
        }
        
        let sceneRenderer = sceneView.sceneRenderer
        
        for renderNode in sceneRenderer.renderNodes {
            guard let beam = renderNode as? BeamRenderNode else {
                continue
            }
            beam.transform.translation.z += travelSpeed + beam.intrinsicSpeed
            beam.alpha += 0.1
        }
        
        if emittedCount > 490 {
            backgroundRenderPass.backgroundAlpha -= 0.02
            travelSpeed = max(0.6, travelSpeed - 0.04)
        } else if emittedCount > 480 {
            birthRate = max(5, birthRate - 1)
        }
        
        let now = CACurrentMediaTime()
        if now - lastEmitTime < 0.1 || emittedCount > 500 {
            return
        }

        if birthRate < 50 {
            birthRate += 2
        }

        if travelSpeed < 3 {
            travelSpeed += 0.24
        }

        for _ in 0..<Int(floor(birthRate)) {
            emitBeam()
        }

        sceneRenderer.renderNodes = sceneRenderer.renderNodes.filter {
            guard let beam = $0 as? BeamRenderNode else {
                return true
            }
            return beam.transform.translation.z < 0
        }

        lastEmitTime = now
    }
    
    func emitBeam() {
        let sceneRenderer = sceneView.sceneRenderer
        
        let isPioneer = emittedCount < 3
        let rotation = simd_float3(x: .pi / 2, y: 0, z: 0)
        let angle = Float.random(in: 0...(Float.pi * 2))
        let radius = Float(Int.random(in: 4...10)) * 5
        let beam = BeamRenderNode(
            transform: .init(
                translation: .init(x: sin(angle) * radius, y: cos(angle) * radius, z: .random(in: -120...(-100))),
                scale: .init(x: 1.2, y: isPioneer ? .random(in: 0.5...0.8) : .random(in: 0.5...10), z: 1.2),
                rotation: rotation
            ),
            geometryRenderer: sharedCylinderRenderer
        )
        if isPioneer {
            beam.intrinsicSpeed = .random(in: 0.8...1.0)
        }
        beam.alpha = 0
        beam.color = beamColors.randomElement()!
        sceneRenderer.renderNodes.append(beam)
        emittedCount += 1
    }
    
}
