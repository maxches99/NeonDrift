import AppKit
import IOKit.ps
import MetalKit
import ServiceManagement
import SwiftUI
import simd

enum ColorPalettePreset: UInt32, CaseIterable, Codable, Identifiable {
    case rose = 0
    case glass = 1
    case synthwave = 2
    case monochrome = 3
    case minimal = 4
    case ambient = 5

    var id: UInt32 { rawValue }

    var title: String {
        switch self {
        case .rose: "Rose"
        case .glass: "Glass"
        case .synthwave: "Synthwave"
        case .monochrome: "Monochrome"
        case .minimal: "Minimal"
        case .ambient: "Ambient"
        }
    }
}

struct ShaderTuning: Codable, Equatable {
    var palettePreset: ColorPalettePreset
    var intensity: Float
    var contrast: Float
    var noiseAmount: Float
    var zoom: Float

    static let `default` = ShaderTuning(
        palettePreset: .rose,
        intensity: 1,
        contrast: 1,
        noiseAmount: 0.08,
        zoom: 1
    )
}

struct WallpaperConfiguration: Codable, Equatable {
    var theme: PlasmaTheme
    var frameRate: Int
    var animationSpeed: Float
    var tuning: ShaderTuning

    static let `default` = PlasmaTheme.velvetRose.defaultConfiguration

    mutating func applyRecommendedStyle(for theme: PlasmaTheme) {
        self.theme = theme
        tuning = theme.recommendedTuning
        animationSpeed = theme.recommendedAnimationSpeed
    }
}

struct GeneralPreferences: Codable, Equatable {
    var launchAtLoginEnabled: Bool
    var showControlCenterOnLaunch: Bool
    var backgroundModeEnabled: Bool
    var pauseOnLowPowerMode: Bool

    static let `default` = GeneralPreferences(
        launchAtLoginEnabled: false,
        showControlCenterOnLaunch: true,
        backgroundModeEnabled: false,
        pauseOnLowPowerMode: false
    )
}

struct ExportedSettings: Codable {
    var version = 2
    var defaultConfiguration: WallpaperConfiguration
    var displayOverrides: [String: WallpaperConfiguration]
    var generalPreferences: GeneralPreferences
    var automationRules: AutomationRules

    init(
        defaultConfiguration: WallpaperConfiguration,
        displayOverrides: [String: WallpaperConfiguration],
        generalPreferences: GeneralPreferences,
        automationRules: AutomationRules
    ) {
        self.defaultConfiguration = defaultConfiguration
        self.displayOverrides = displayOverrides
        self.generalPreferences = generalPreferences
        self.automationRules = automationRules
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = (try? c.decode(Int.self, forKey: .version)) ?? 2
        defaultConfiguration = try c.decode(WallpaperConfiguration.self, forKey: .defaultConfiguration)
        displayOverrides = try c.decode([String: WallpaperConfiguration].self, forKey: .displayOverrides)
        generalPreferences = try c.decode(GeneralPreferences.self, forKey: .generalPreferences)
        automationRules = (try? c.decode(AutomationRules.self, forKey: .automationRules)) ?? .default
    }
}

enum BuiltInPreset: String, CaseIterable, Identifiable {
    case work, chill, night, presentation

    var id: String { rawValue }

    var title: String {
        switch self {
        case .work: "Work"
        case .chill: "Chill"
        case .night: "Night"
        case .presentation: "Presentation"
        }
    }

    var systemImage: String {
        switch self {
        case .work: "briefcase"
        case .chill: "cup.and.saucer"
        case .night: "moon.stars"
        case .presentation: "rectangle.on.rectangle"
        }
    }

    var configuration: WallpaperConfiguration {
        switch self {
        case .work:
            return WallpaperConfiguration(theme: .ambientHaze, frameRate: 30, animationSpeed: 0.5, tuning: PlasmaTheme.ambientHaze.recommendedTuning)
        case .chill:
            return WallpaperConfiguration(theme: .velvetRose, frameRate: 60, animationSpeed: 0.9, tuning: PlasmaTheme.velvetRose.recommendedTuning)
        case .night:
            return WallpaperConfiguration(theme: .midnightBlush, frameRate: 30, animationSpeed: 0.55, tuning: PlasmaTheme.midnightBlush.recommendedTuning)
        case .presentation:
            return WallpaperConfiguration(theme: .monoMist, frameRate: 24, animationSpeed: 0.25, tuning: PlasmaTheme.monoMist.recommendedTuning)
        }
    }
}

struct TimeOfDaySchedule: Codable, Equatable {
    var morningTheme: PlasmaTheme
    var afternoonTheme: PlasmaTheme
    var eveningTheme: PlasmaTheme
    var nightTheme: PlasmaTheme

    static let `default` = TimeOfDaySchedule(
        morningTheme: .minimalArc,
        afternoonTheme: .velvetRose,
        eveningTheme: .synthwaveRun,
        nightTheme: .midnightBlush
    )

    func themeForNow() -> PlasmaTheme {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<12: return morningTheme
        case 12..<18: return afternoonTheme
        case 18..<22: return eveningTheme
        default: return nightTheme
        }
    }
}

struct AutomationRules: Codable, Equatable {
    var timeOfDayEnabled: Bool
    var schedule: TimeOfDaySchedule
    var powerAdaptiveEnabled: Bool
    var onBatteryTheme: PlasmaTheme
    var onChargerTheme: PlasmaTheme

    static let `default` = AutomationRules(
        timeOfDayEnabled: false,
        schedule: .default,
        powerAdaptiveEnabled: false,
        onBatteryTheme: .ambientHaze,
        onChargerTheme: .velvetRose
    )
}

struct DisplayInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let size: CGSize
    let isPrimary: Bool

    var title: String {
        isPrimary ? "\(name) Main" : name
    }

    var subtitle: String {
        "\(Int(size.width)) x \(Int(size.height))"
    }
}

struct RendererDiagnostics: Identifiable, Equatable {
    let id: String
    var displayName: String
    var themeTitle: String
    var profileTitle: String
    var fps: Double
    var frameRateLimit: Int
    var isPaused: Bool
    var status: String
    var lastUpdate: Date
}

enum SettingsSelection: Hashable {
    case dashboard
    case gallery
    case diagnostics
    case display(String)
}

enum EditorTarget: Hashable {
    case global
    case display(String)
}

enum ShaderBundleLocator {
    static var resourceURL: URL? {
        // Bundle.module's SPM-generated accessor looks in Bundle.main.bundleURL, which
        // equals the .app root for packaged apps — but the resource bundle lands in
        // Contents/Resources/ after packaging. On user machines the hardcoded build-dir
        // fallback doesn't exist, causing an assertionFailure crash.
        // Instead, probe both locations manually so this works for both app bundles and
        // SPM dev builds (.build/…/NeonDrift_NeonDrift.bundle next to the executable).
        let bundleName = "NeonDrift_NeonDrift.bundle"

        // Packaged app: bundle is in Contents/Resources/
        if let resourcesURL = Bundle.main.resourceURL {
            let url = resourcesURL.appendingPathComponent(bundleName, isDirectory: true)
            if let b = Bundle(url: url) { return b.resourceURL }
        }

        // SPM dev build: bundle is in the same dir as the executable
        let url = Bundle.main.bundleURL.appendingPathComponent(bundleName, isDirectory: true)
        if let b = Bundle(url: url) { return b.resourceURL }

        return Bundle.main.resourceURL
    }

    static var shaderDirectoryURL: URL? {
        guard let resourceURL else { return nil }

        let directShader = resourceURL.appendingPathComponent("01_pink_plasma.metal")
        if FileManager.default.fileExists(atPath: directShader.path) {
            return resourceURL
        }

        let nestedResourcesURL = resourceURL.appendingPathComponent("Resources", isDirectory: true)
        let nestedShader = nestedResourcesURL.appendingPathComponent("01_pink_plasma.metal")
        if FileManager.default.fileExists(atPath: nestedShader.path) {
            return nestedResourcesURL
        }

        return resourceURL
    }
}

struct Uniforms {
    var time: Float = 0
    var resolution: SIMD2<Float> = .zero
    var mouse: SIMD2<Float> = .zero
    var frame: UInt32 = 0
    var theme: UInt32 = 0
    var themeFamily: UInt32 = 0
    var themeVariant: UInt32 = 0
    var previousTheme: UInt32 = 0
    var previousThemeFamily: UInt32 = 0
    var previousThemeVariant: UInt32 = 0
    var transitionProgress: Float = 1
    var mandelbrotCenter: SIMD2<Float> = .zero
    var mandelbrotZoom: Float = 1
    var mandelbrotEpoch: UInt32 = 0
    var familyTime: Float = 0
    var accentPhase: Float = 0
    var palettePreset: UInt32 = 0
    var previousPalettePreset: UInt32 = 0
    var intensity: Float = 1
    var previousIntensity: Float = 1
    var contrast: Float = 1
    var previousContrast: Float = 1
    var noiseAmount: Float = 0
    var previousNoiseAmount: Float = 0
    var zoom: Float = 1
    var previousZoom: Float = 1
}

enum PlasmaThemeFamily: UInt32, CaseIterable, Codable, Identifiable {
    case plasma = 0
    case fractals = 1
    case patterns = 2
    case atmosphere = 3

    var id: UInt32 { rawValue }

    var title: String {
        switch self {
        case .plasma: "Plasma"
        case .fractals: "Fractals"
        case .patterns: "Patterns"
        case .atmosphere: "Atmosphere"
        }
    }
}

enum PlasmaTheme: UInt32, CaseIterable, Codable, Identifiable {
    case velvetRose = 0
    case sakura = 1
    case bubblegum = 2
    case neonRose = 3
    case midnightBlush = 4
    case silver = 5
    case mandelbrot = 6
    case juliaBloom = 7
    case newtonPetals = 8
    case polarLissajous = 9
    case moireDream = 10
    case kaleidoWave = 11
    case domainColoring = 12
    case apollonianTiles = 13
    case glassCurrent = 14
    case synthwaveRun = 15
    case monoMist = 16
    case minimalArc = 17
    case ambientHaze = 18

    var id: UInt32 { rawValue }

    var title: String {
        switch self {
        case .velvetRose: "Velvet Rose"
        case .sakura: "Sakura"
        case .bubblegum: "Bubblegum"
        case .neonRose: "Neon Rose"
        case .midnightBlush: "Midnight Blush"
        case .silver: "Silver"
        case .mandelbrot: "Mandelbrot"
        case .juliaBloom: "Julia Bloom"
        case .newtonPetals: "Newton Petals"
        case .polarLissajous: "Polar Lissajous"
        case .moireDream: "Moire Dream"
        case .kaleidoWave: "Kaleido Wave"
        case .domainColoring: "Domain Coloring"
        case .apollonianTiles: "Apollonian Tiles"
        case .glassCurrent: "Glass Current"
        case .synthwaveRun: "Synthwave Run"
        case .monoMist: "Mono Mist"
        case .minimalArc: "Minimal Arc"
        case .ambientHaze: "Ambient Haze"
        }
    }

    var family: PlasmaThemeFamily {
        switch self {
        case .velvetRose, .sakura, .bubblegum, .neonRose, .midnightBlush, .silver:
            return .plasma
        case .mandelbrot, .juliaBloom, .newtonPetals:
            return .fractals
        case .polarLissajous, .moireDream, .kaleidoWave, .domainColoring, .apollonianTiles:
            return .patterns
        case .glassCurrent, .synthwaveRun, .monoMist, .minimalArc, .ambientHaze:
            return .atmosphere
        }
    }

    var summary: String {
        switch self {
        case .velvetRose: "Soft cinematic plasma with deep rose bloom."
        case .sakura: "Warm blossom tones with airy highlights."
        case .bubblegum: "Candy neon plasma with saturated magenta lift."
        case .neonRose: "Sharper neon core with club-light contrast."
        case .midnightBlush: "Dark restrained palette for night desks."
        case .silver: "Metallic grayscale plasma with pearl highlights."
        case .mandelbrot: "Slow zoom through a vivid Mandelbrot basin."
        case .juliaBloom: "Petal-like Julia set with orbit glow."
        case .newtonPetals: "Newton fractal roots with floral basins."
        case .polarLissajous: "Orbital ribbons and rotational geometry."
        case .moireDream: "Dense moire interference with bright bands."
        case .kaleidoWave: "Folded kaleidoscope wave reflections."
        case .domainColoring: "Complex analysis map with contour glow."
        case .apollonianTiles: "Recursive bubble packing and webbing."
        case .glassCurrent: "Frosted glass currents with fluid refractions."
        case .synthwaveRun: "Retro horizon lines and sunset pulse."
        case .monoMist: "Monochrome mist with subtle film grain."
        case .minimalArc: "Minimal arcs and calm spatial motion."
        case .ambientHaze: "Low-contrast ambient gradients for focus."
        }
    }

    var usesAnimatedMandelbrotCamera: Bool {
        self == .mandelbrot
    }

    var variantInFamily: UInt32 {
        UInt32(Self.allCases.filter { $0.family == family }.firstIndex(of: self) ?? 0)
    }

    var recommendedTuning: ShaderTuning {
        switch self {
        case .velvetRose:
            return ShaderTuning(palettePreset: .rose, intensity: 1.0, contrast: 1.0, noiseAmount: 0.08, zoom: 1.0)
        case .sakura:
            return ShaderTuning(palettePreset: .rose, intensity: 1.05, contrast: 0.95, noiseAmount: 0.05, zoom: 1.0)
        case .bubblegum:
            return ShaderTuning(palettePreset: .rose, intensity: 1.18, contrast: 1.08, noiseAmount: 0.09, zoom: 1.05)
        case .neonRose:
            return ShaderTuning(palettePreset: .synthwave, intensity: 1.22, contrast: 1.15, noiseAmount: 0.10, zoom: 1.0)
        case .midnightBlush:
            return ShaderTuning(palettePreset: .ambient, intensity: 0.92, contrast: 1.05, noiseAmount: 0.04, zoom: 1.0)
        case .silver:
            return ShaderTuning(palettePreset: .monochrome, intensity: 0.96, contrast: 1.12, noiseAmount: 0.03, zoom: 1.0)
        case .mandelbrot:
            return ShaderTuning(palettePreset: .rose, intensity: 1.05, contrast: 1.08, noiseAmount: 0.05, zoom: 0.92)
        case .juliaBloom:
            return ShaderTuning(palettePreset: .rose, intensity: 1.1, contrast: 1.0, noiseAmount: 0.06, zoom: 1.0)
        case .newtonPetals:
            return ShaderTuning(palettePreset: .glass, intensity: 1.08, contrast: 1.06, noiseAmount: 0.07, zoom: 1.0)
        case .polarLissajous:
            return ShaderTuning(palettePreset: .minimal, intensity: 1.0, contrast: 1.1, noiseAmount: 0.05, zoom: 1.04)
        case .moireDream:
            return ShaderTuning(palettePreset: .glass, intensity: 1.08, contrast: 1.18, noiseAmount: 0.12, zoom: 1.0)
        case .kaleidoWave:
            return ShaderTuning(palettePreset: .synthwave, intensity: 1.1, contrast: 1.12, noiseAmount: 0.09, zoom: 1.02)
        case .domainColoring:
            return ShaderTuning(palettePreset: .glass, intensity: 1.02, contrast: 1.1, noiseAmount: 0.05, zoom: 0.95)
        case .apollonianTiles:
            return ShaderTuning(palettePreset: .ambient, intensity: 0.96, contrast: 1.14, noiseAmount: 0.08, zoom: 1.0)
        case .glassCurrent:
            return ShaderTuning(palettePreset: .glass, intensity: 0.95, contrast: 0.92, noiseAmount: 0.03, zoom: 0.96)
        case .synthwaveRun:
            return ShaderTuning(palettePreset: .synthwave, intensity: 1.2, contrast: 1.2, noiseAmount: 0.08, zoom: 1.0)
        case .monoMist:
            return ShaderTuning(palettePreset: .monochrome, intensity: 0.9, contrast: 0.9, noiseAmount: 0.02, zoom: 0.94)
        case .minimalArc:
            return ShaderTuning(palettePreset: .minimal, intensity: 0.88, contrast: 1.0, noiseAmount: 0.01, zoom: 0.9)
        case .ambientHaze:
            return ShaderTuning(palettePreset: .ambient, intensity: 0.86, contrast: 0.88, noiseAmount: 0.02, zoom: 0.92)
        }
    }

    var recommendedAnimationSpeed: Float {
        switch self.family {
        case .plasma: return 1
        case .fractals: return 0.82
        case .patterns: return 1.05
        case .atmosphere: return 0.72
        }
    }

    var defaultConfiguration: WallpaperConfiguration {
        WallpaperConfiguration(
            theme: self,
            frameRate: 60,
            animationSpeed: recommendedAnimationSpeed,
            tuning: recommendedTuning
        )
    }

    static func themes(for family: PlasmaThemeFamily) -> [PlasmaTheme] {
        allCases.filter { $0.family == family }
    }
}

struct ThemeRuntimeState {
    var family: PlasmaThemeFamily
    var variant: UInt32
    var familyTime: Float
    var accentPhase: Float
    var mandelbrotCenter: SIMD2<Float>
    var mandelbrotZoom: Float
    var mandelbrotEpoch: UInt32
}

@MainActor
final class PlasmaRenderer: NSObject, MTKViewDelegate {
    struct RendererState {
        let startTime: CFTimeInterval
        let familyStartTime: CFTimeInterval
        let familyTransitionCount: UInt32
        let mandelbrotEpochStart: CFTimeInterval
        let mandelbrotEpoch: UInt32
        let mandelbrotCenter: SIMD2<Float>
    }

    private let displayID: String
    private let displayName: String
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private weak var view: MTKView?
    private let startTime: CFTimeInterval
    private var frame: UInt32 = 0
    private var familyStartTime = CACurrentMediaTime()
    private var familyTransitionCount: UInt32 = 0
    private var mandelbrotEpochStart = CACurrentMediaTime()
    private var mandelbrotEpoch: UInt32 = 0
    private var mandelbrotCenter = SIMD2<Float>(-0.7436439, 0.1318259)
    private let mandelbrotCenters: [SIMD2<Float>] = [
        SIMD2<Float>(-0.7436439, 0.1318259),
        SIMD2<Float>(-0.7435669, 0.1314023),
        SIMD2<Float>(-0.7445397, 0.1217231),
        SIMD2<Float>(-0.7508750, 0.1082500),
        SIMD2<Float>(-0.7615740, 0.0847596),
        SIMD2<Float>(-0.7756838, 0.1364674)
    ]
    private var currentConfiguration = WallpaperConfiguration.default
    private var previousConfiguration = WallpaperConfiguration.default
    private var transitionStartTime = CACurrentMediaTime()
    private var transitionDuration: CFTimeInterval = 0.7
    private var profileTitle = "Shared"
    private var pauseReason: String?
    private var lastDiagnosticsTimestamp = CACurrentMediaTime()
    private var framesSinceLastDiagnostic: Int = 0

    var onDiagnosticsUpdate: ((RendererDiagnostics) -> Void)?

    var theme: PlasmaTheme = .velvetRose {
        didSet {
            resetThemeStateIfNeeded(from: oldValue, to: theme)
        }
    }

    var frameRate: Int = 60 {
        didSet {
            view?.preferredFramesPerSecond = frameRate
        }
    }

    var animationSpeed: Float = 1

    func captureState() -> RendererState {
        RendererState(
            startTime: startTime,
            familyStartTime: familyStartTime,
            familyTransitionCount: familyTransitionCount,
            mandelbrotEpochStart: mandelbrotEpochStart,
            mandelbrotEpoch: mandelbrotEpoch,
            mandelbrotCenter: mandelbrotCenter
        )
    }

    init(view: MTKView, displayID: String, displayName: String, inheritedState: RendererState? = nil) throws {
        let now = CACurrentMediaTime()
        self.startTime = inheritedState?.startTime ?? now

        guard let device = MTLCreateSystemDefaultDevice() else {
            throw RuntimeError("Metal is not available on this Mac.")
        }
        guard let commandQueue = device.makeCommandQueue() else {
            throw RuntimeError("Could not create a Metal command queue.")
        }

        self.displayID = displayID
        self.displayName = displayName
        self.commandQueue = commandQueue
        self.view = view

        view.device = device
        view.colorPixelFormat = .bgra8Unorm
        view.framebufferOnly = true
        view.isPaused = false
        view.enableSetNeedsDisplay = false
        view.preferredFramesPerSecond = frameRate

        let source = try Self.loadShaderSource()
        let library = try device.makeLibrary(source: source, options: nil)

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "vs_main")
        descriptor.fragmentFunction = library.makeFunction(name: "fs_main")
        descriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat

        pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
        super.init()

        if let inherited = inheritedState {
            familyStartTime = inherited.familyStartTime
            familyTransitionCount = inherited.familyTransitionCount
            mandelbrotEpochStart = inherited.mandelbrotEpochStart
            mandelbrotEpoch = inherited.mandelbrotEpoch
            mandelbrotCenter = inherited.mandelbrotCenter
        }
    }

    private static func loadShaderSource() throws -> String {
        guard let resourcesURL = ShaderBundleLocator.shaderDirectoryURL else {
            throw RuntimeError("Shader resource directory is missing.")
        }

        let shaderURLs = try FileManager.default.contentsOfDirectory(
            at: resourcesURL,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension == "metal" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }

        guard !shaderURLs.isEmpty else {
            throw RuntimeError("No shader source files were found.")
        }

        return try shaderURLs
            .map { try String(contentsOf: $0, encoding: .utf8) }
            .joined(separator: "\n\n")
    }

    func apply(configuration: WallpaperConfiguration, profileTitle: String) {
        self.profileTitle = profileTitle
        let shouldTransition = currentConfiguration != configuration
        if shouldTransition {
            previousConfiguration = currentConfiguration
            currentConfiguration = configuration
            transitionStartTime = CACurrentMediaTime()
        }

        theme = configuration.theme
        frameRate = configuration.frameRate
        animationSpeed = configuration.animationSpeed
        emitDiagnostics(force: true)
    }

    func setPaused(_ paused: Bool, reason: String?) {
        pauseReason = paused ? reason : nil
        view?.isPaused = paused
        if !paused {
            lastDiagnosticsTimestamp = CACurrentMediaTime()
            framesSinceLastDiagnostic = 0
        }
        emitDiagnostics(force: true)
    }

    nonisolated func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    nonisolated func draw(in view: MTKView) {
        MainActor.assumeIsolated {
            drawFrame(in: view)
        }
    }

    private func drawFrame(in view: MTKView) {
        guard
            let descriptor = view.currentRenderPassDescriptor,
            let drawable = view.currentDrawable,
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
        else {
            return
        }

        let runtimeState = currentThemeRuntimeState()
        let transition = themeTransitionProgress
        let scale = Float(view.drawableSize.width / max(view.bounds.width, 1))
        var uniforms = Uniforms(
            time: scaledElapsedTime(since: startTime),
            resolution: SIMD2(Float(view.bounds.width) * scale, Float(view.bounds.height) * scale),
            mouse: .zero,
            frame: frame,
            theme: currentConfiguration.theme.rawValue,
            themeFamily: currentConfiguration.theme.family.rawValue,
            themeVariant: currentConfiguration.theme.variantInFamily,
            previousTheme: previousConfiguration.theme.rawValue,
            previousThemeFamily: previousConfiguration.theme.family.rawValue,
            previousThemeVariant: previousConfiguration.theme.variantInFamily,
            transitionProgress: transition,
            mandelbrotCenter: runtimeState.mandelbrotCenter,
            mandelbrotZoom: runtimeState.mandelbrotZoom,
            mandelbrotEpoch: runtimeState.mandelbrotEpoch,
            familyTime: runtimeState.familyTime,
            accentPhase: runtimeState.accentPhase,
            palettePreset: currentConfiguration.tuning.palettePreset.rawValue,
            previousPalettePreset: previousConfiguration.tuning.palettePreset.rawValue,
            intensity: currentConfiguration.tuning.intensity,
            previousIntensity: previousConfiguration.tuning.intensity,
            contrast: currentConfiguration.tuning.contrast,
            previousContrast: previousConfiguration.tuning.contrast,
            noiseAmount: currentConfiguration.tuning.noiseAmount,
            previousNoiseAmount: previousConfiguration.tuning.noiseAmount,
            zoom: currentConfiguration.tuning.zoom,
            previousZoom: previousConfiguration.tuning.zoom
        )
        frame &+= 1
        framesSinceLastDiagnostic += 1

        encoder.setRenderPipelineState(pipelineState)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()

        emitDiagnostics(force: false)
    }

    private var themeTransitionProgress: Float {
        let elapsed = CACurrentMediaTime() - transitionStartTime
        let progress = min(max(elapsed / max(transitionDuration, 0.001), 0), 1)
        let eased = 1 - pow(1 - progress, 3)
        return Float(eased)
    }

    private func emitDiagnostics(force: Bool) {
        let now = CACurrentMediaTime()
        let elapsed = max(now - lastDiagnosticsTimestamp, 0.001)
        if !force && elapsed < 0.6 {
            return
        }

        let fps = Double(framesSinceLastDiagnostic) / elapsed
        lastDiagnosticsTimestamp = now
        framesSinceLastDiagnostic = 0

        onDiagnosticsUpdate?(
            RendererDiagnostics(
                id: displayID,
                displayName: displayName,
                themeTitle: currentConfiguration.theme.title,
                profileTitle: profileTitle,
                fps: view?.isPaused == true ? 0 : fps,
                frameRateLimit: frameRate,
                isPaused: view?.isPaused == true,
                status: pauseReason ?? (themeTransitionProgress < 0.999 ? "Transitioning" : "Rendering"),
                lastUpdate: Date()
            )
        )
    }

    private func currentMandelbrotState() -> (center: SIMD2<Float>, zoom: Float, epoch: UInt32) {
        guard currentConfiguration.theme.usesAnimatedMandelbrotCamera else {
            return (mandelbrotCenter, 1, mandelbrotEpoch)
        }

        let elapsed = Double(scaledElapsedTime(since: mandelbrotEpochStart))
        let zoom = Float(2.95 * exp(-elapsed * 0.045))
        if zoom < 0.085 {
            mandelbrotEpoch &+= 1
            mandelbrotEpochStart = CACurrentMediaTime()
            mandelbrotCenter = mandelbrotCenters[Int(mandelbrotEpoch) % mandelbrotCenters.count]
            return (mandelbrotCenter, 2.95, mandelbrotEpoch)
        }

        return (mandelbrotCenter, zoom, mandelbrotEpoch)
    }

    private func resetMandelbrotZoom() {
        mandelbrotEpochStart = CACurrentMediaTime()
        mandelbrotEpoch = 0
        mandelbrotCenter = mandelbrotCenters[0]
    }

    private func currentThemeRuntimeState() -> ThemeRuntimeState {
        let familyTime = scaledElapsedTime(since: familyStartTime)
        let mandelbrotState = currentMandelbrotState()
        let transitionPhase = Float(familyTransitionCount) * 0.35
        let accentPhase: Float

        switch currentConfiguration.theme.family {
        case .plasma:
            accentPhase = familyTime * 0.55 + Float(currentConfiguration.theme.variantInFamily) * 0.8 + transitionPhase
        case .fractals:
            accentPhase = familyTime * 0.28 + Float(mandelbrotState.epoch) * 0.65 + transitionPhase
        case .patterns:
            accentPhase = familyTime * 0.82 + Float(currentConfiguration.theme.variantInFamily) * 0.45 + transitionPhase
        case .atmosphere:
            accentPhase = familyTime * 0.24 + Float(currentConfiguration.theme.variantInFamily) * 0.32 + transitionPhase
        }

        return ThemeRuntimeState(
            family: currentConfiguration.theme.family,
            variant: currentConfiguration.theme.variantInFamily,
            familyTime: familyTime,
            accentPhase: accentPhase,
            mandelbrotCenter: mandelbrotState.center,
            mandelbrotZoom: mandelbrotState.zoom,
            mandelbrotEpoch: mandelbrotState.epoch
        )
    }

    private func scaledElapsedTime(since start: CFTimeInterval) -> Float {
        Float(CACurrentMediaTime() - start) * animationSpeed
    }

    private func resetThemeStateIfNeeded(from oldValue: PlasmaTheme, to newValue: PlasmaTheme) {
        if oldValue.family != newValue.family {
            familyStartTime = CACurrentMediaTime()
            familyTransitionCount &+= 1
        }

        if newValue.usesAnimatedMandelbrotCamera && !oldValue.usesAnimatedMandelbrotCamera {
            resetMandelbrotZoom()
        }
    }
}

@MainActor
final class WallpaperSettingsStore: ObservableObject {
    private let defaultConfigurationKey = "DefaultWallpaperConfiguration"
    private let displayOverridesKey = "DisplayWallpaperOverrides"
    private let generalPreferencesKey = "GeneralPreferences"
    private let automationRulesKey = "AutomationRules"

    @Published private(set) var defaultConfiguration: WallpaperConfiguration
    @Published private(set) var displayOverrides: [String: WallpaperConfiguration]
    @Published private(set) var displays: [DisplayInfo] = []
    @Published private(set) var generalPreferences: GeneralPreferences
    @Published private(set) var automationRules: AutomationRules
    @Published private(set) var diagnostics: [String: RendererDiagnostics] = [:]
    @Published var launchAtLoginStatusMessage = "Checking login item status..."
    @Published var errorMessage: String?
    @Published var infoMessage: String?

    var onWallpaperConfigurationChanged: (() -> Void)?
    var onAppearancePreferencesChanged: (() -> Void)?
    var onPowerPreferenceChanged: (() -> Void)?
    var onAutomationRulesChanged: (() -> Void)?

    init() {
        self.defaultConfiguration = Self.loadValue(forKey: defaultConfigurationKey) ?? .default
        self.displayOverrides = Self.loadValue(forKey: displayOverridesKey) ?? [:]
        self.generalPreferences = Self.loadValue(forKey: generalPreferencesKey) ?? .default
        self.automationRules = Self.loadValue(forKey: automationRulesKey) ?? .default
        refreshLaunchAtLoginStatus()
    }

    func refreshDisplays(from screens: [NSScreen]) {
        let primaryDisplayID = screens.first?.stableDisplayID
        displays = screens.map { screen in
            DisplayInfo(
                id: screen.stableDisplayID,
                name: screen.localizedName,
                size: screen.frame.size,
                isPrimary: screen.stableDisplayID == primaryDisplayID
            )
        }
        .sorted { lhs, rhs in
            if lhs.isPrimary != rhs.isPrimary {
                return lhs.isPrimary
            }
            return lhs.name < rhs.name
        }

        let validIDs = Set(displays.map(\.id))
        let staleKeys = displayOverrides.keys.filter { !validIDs.contains($0) }
        if !staleKeys.isEmpty {
            staleKeys.forEach { displayOverrides.removeValue(forKey: $0) }
            persistOverrides()
        }
    }

    func configuration(for target: EditorTarget) -> WallpaperConfiguration {
        switch target {
        case .global:
            return defaultConfiguration
        case .display(let displayID):
            return displayOverrides[displayID] ?? defaultConfiguration
        }
    }

    func effectiveConfiguration(for displayID: String) -> WallpaperConfiguration {
        displayOverrides[displayID] ?? defaultConfiguration
    }

    func hasOverride(for displayID: String) -> Bool {
        displayOverrides[displayID] != nil
    }

    func profileTitle(for displayID: String) -> String {
        hasOverride(for: displayID) ? "Custom" : "Shared"
    }

    func setOverrideEnabled(_ enabled: Bool, for displayID: String) {
        if enabled {
            displayOverrides[displayID] = defaultConfiguration
        } else {
            displayOverrides.removeValue(forKey: displayID)
        }
        persistOverrides()
        notifyWallpaperChange()
    }

    func setTheme(_ theme: PlasmaTheme, for target: EditorTarget) {
        mutateConfiguration(for: target) { configuration in
            configuration.applyRecommendedStyle(for: theme)
        }
    }

    func setThemeFamily(_ family: PlasmaThemeFamily, for target: EditorTarget) {
        let themes = PlasmaTheme.themes(for: family)
        guard let first = themes.first else { return }

        mutateConfiguration(for: target) { configuration in
            if !themes.contains(configuration.theme) {
                configuration.applyRecommendedStyle(for: first)
            }
        }
    }

    func setFrameRate(_ frameRate: Int, for target: EditorTarget) {
        mutateConfiguration(for: target) { configuration in
            configuration.frameRate = frameRate
        }
    }

    func setAnimationSpeed(_ animationSpeed: Float, for target: EditorTarget) {
        mutateConfiguration(for: target) { configuration in
            configuration.animationSpeed = animationSpeed
        }
    }

    func setPalettePreset(_ preset: ColorPalettePreset, for target: EditorTarget) {
        mutateConfiguration(for: target) { configuration in
            configuration.tuning.palettePreset = preset
        }
    }

    func setIntensity(_ intensity: Float, for target: EditorTarget) {
        mutateConfiguration(for: target) { configuration in
            configuration.tuning.intensity = intensity
        }
    }

    func setContrast(_ contrast: Float, for target: EditorTarget) {
        mutateConfiguration(for: target) { configuration in
            configuration.tuning.contrast = contrast
        }
    }

    func setNoiseAmount(_ noiseAmount: Float, for target: EditorTarget) {
        mutateConfiguration(for: target) { configuration in
            configuration.tuning.noiseAmount = noiseAmount
        }
    }

    func setZoom(_ zoom: Float, for target: EditorTarget) {
        mutateConfiguration(for: target) { configuration in
            configuration.tuning.zoom = zoom
        }
    }

    func randomizeTheme(for target: EditorTarget) {
        guard let theme = PlasmaTheme.allCases.randomElement() else { return }
        setTheme(theme, for: target)
    }

    func applyPreset(_ preset: BuiltInPreset) {
        defaultConfiguration = preset.configuration
        persistDefaultConfiguration()
        notifyWallpaperChange()
    }

    func setAutomationRules(_ rules: AutomationRules) {
        automationRules = rules
        Self.store(rules, forKey: automationRulesKey)
        onAutomationRulesChanged?()
    }

    func updateDiagnostic(_ diagnostic: RendererDiagnostics) {
        diagnostics[diagnostic.id] = diagnostic
    }

    func refreshLaunchAtLoginStatus() {
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            switch service.status {
            case .enabled:
                generalPreferences.launchAtLoginEnabled = true
                launchAtLoginStatusMessage = "Neon Drift launches automatically when you sign in."
            case .requiresApproval:
                generalPreferences.launchAtLoginEnabled = false
                launchAtLoginStatusMessage = "Launch at login needs approval in System Settings > General > Login Items."
            case .notRegistered:
                generalPreferences.launchAtLoginEnabled = false
                launchAtLoginStatusMessage = "Launch at login is turned off."
            case .notFound:
                generalPreferences.launchAtLoginEnabled = false
                launchAtLoginStatusMessage = "A signed app bundle is required before login launch can be enabled."
            @unknown default:
                generalPreferences.launchAtLoginEnabled = false
                launchAtLoginStatusMessage = "Login item status is currently unavailable."
            }
            persistPreferences()
        } else {
            generalPreferences.launchAtLoginEnabled = false
            launchAtLoginStatusMessage = "Launch at login requires macOS 13 or later."
        }
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        guard #available(macOS 13.0, *) else {
            errorMessage = "Launch at login requires macOS 13 or later."
            return
        }

        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            generalPreferences.launchAtLoginEnabled = enabled
            persistPreferences()
            refreshLaunchAtLoginStatus()
        } catch {
            refreshLaunchAtLoginStatus()
            errorMessage = error.localizedDescription
        }
    }

    func setBackgroundModeEnabled(_ enabled: Bool) {
        generalPreferences.backgroundModeEnabled = enabled
        if enabled {
            generalPreferences.showControlCenterOnLaunch = false
        }
        persistPreferences()
        onAppearancePreferencesChanged?()
    }

    func setShowControlCenterOnLaunch(_ enabled: Bool) {
        generalPreferences.showControlCenterOnLaunch = enabled
        persistPreferences()
    }

    func setPauseOnLowPowerMode(_ enabled: Bool) {
        generalPreferences.pauseOnLowPowerMode = enabled
        persistPreferences()
        onPowerPreferenceChanged?()
    }

    func exportSettings() {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "NeonDriftSettings.json"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let payload = ExportedSettings(
                defaultConfiguration: defaultConfiguration,
                displayOverrides: displayOverrides,
                generalPreferences: generalPreferences,
                automationRules: automationRules
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(payload)
            try data.write(to: url)
            infoMessage = "Settings exported to \(url.lastPathComponent)."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func importSettings() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try Data(contentsOf: url)
            let payload = try JSONDecoder().decode(ExportedSettings.self, from: data)
            defaultConfiguration = payload.defaultConfiguration
            displayOverrides = payload.displayOverrides
            generalPreferences = payload.generalPreferences
            automationRules = payload.automationRules
            persistDefaultConfiguration()
            persistOverrides()
            persistPreferences()
            Self.store(automationRules, forKey: automationRulesKey)
            refreshLaunchAtLoginStatus()
            setLaunchAtLoginEnabled(payload.generalPreferences.launchAtLoginEnabled)
            onAppearancePreferencesChanged?()
            onPowerPreferenceChanged?()
            onAutomationRulesChanged?()
            notifyWallpaperChange()
            infoMessage = "Settings imported from \(url.lastPathComponent)."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func mutateConfiguration(for target: EditorTarget, update: (inout WallpaperConfiguration) -> Void) {
        switch target {
        case .global:
            update(&defaultConfiguration)
            persistDefaultConfiguration()
        case .display(let displayID):
            var configuration = displayOverrides[displayID] ?? defaultConfiguration
            update(&configuration)
            displayOverrides[displayID] = configuration
            persistOverrides()
        }
        notifyWallpaperChange()
    }

    private func notifyWallpaperChange() {
        onWallpaperConfigurationChanged?()
    }

    private func persistDefaultConfiguration() {
        Self.store(defaultConfiguration, forKey: defaultConfigurationKey)
    }

    private func persistOverrides() {
        Self.store(displayOverrides, forKey: displayOverridesKey)
    }

    private func persistPreferences() {
        Self.store(generalPreferences, forKey: generalPreferencesKey)
    }

    private static func loadValue<T: Decodable>(forKey key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private static func store<T: Encodable>(_ value: T, forKey key: String) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

struct WallpaperPreviewView: NSViewRepresentable {
    let configuration: WallpaperConfiguration
    let size: CGSize

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> MTKView {
        let view = MTKView(frame: NSRect(origin: .zero, size: size))
        view.clearColor = MTLClearColor(red: 0.04, green: 0.04, blue: 0.08, alpha: 1)
        view.wantsLayer = true

        do {
            let renderer = try PlasmaRenderer(
                view: view,
                displayID: "preview-\(UUID().uuidString)",
                displayName: "Preview"
            )
            renderer.apply(configuration: configuration, profileTitle: "Preview")
            view.delegate = renderer
            context.coordinator.renderer = renderer
        } catch {
            context.coordinator.error = error.localizedDescription
        }

        return view
    }

    func updateNSView(_ view: MTKView, context: Context) {
        context.coordinator.renderer?.apply(configuration: configuration, profileTitle: "Preview")
    }

    final class Coordinator {
        var renderer: PlasmaRenderer?
        var error: String?
    }
}

struct WallpaperSettingsView: View {
    @ObservedObject var store: WallpaperSettingsStore
    @State private var selection: SettingsSelection? = .dashboard

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.09, blue: 0.15),
                    Color(red: 0.13, green: 0.08, blue: 0.12),
                    Color(red: 0.04, green: 0.04, blue: 0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .alert("Couldn’t Update Settings", isPresented: errorBinding) {
            Button("OK") { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
        .alert("Done", isPresented: infoBinding) {
            Button("OK") { store.infoMessage = nil }
        } message: {
            Text(store.infoMessage ?? "")
        }
        .onChange(of: store.displays) { _, displays in
            if case .display(let displayID) = selection, !displays.contains(where: { $0.id == displayID }) {
                selection = .dashboard
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )
    }

    private var infoBinding: Binding<Bool> {
        Binding(
            get: { store.infoMessage != nil },
            set: { if !$0 { store.infoMessage = nil } }
        )
    }

    private var sidebar: some View {
        List(selection: $selection) {
            Section {
                NavigationLink(value: SettingsSelection.dashboard) {
                    SidebarRow(title: "Control Center", subtitle: "Preview, tuning, system", systemImage: "dial.medium")
                }
                NavigationLink(value: SettingsSelection.gallery) {
                    SidebarRow(title: "Theme Gallery", subtitle: "Miniatures of every wallpaper", systemImage: "square.grid.3x3.fill")
                }
                NavigationLink(value: SettingsSelection.diagnostics) {
                    SidebarRow(title: "Diagnostics", subtitle: "Displays, FPS, render state", systemImage: "waveform.path.ecg.rectangle")
                }
            }

            Section("Displays") {
                ForEach(store.displays) { display in
                    NavigationLink(value: SettingsSelection.display(display.id)) {
                        SidebarRow(
                            title: display.title,
                            subtitle: "\(display.subtitle) • \(store.profileTitle(for: display.id))",
                            systemImage: display.isPrimary ? "display.and.arrow.down" : "display"
                        )
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(.ultraThinMaterial)
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Neon Drift")
                    .font(.headline.weight(.semibold))
                    .fontDesign(.rounded)
                Text("\(store.displays.count) displays connected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.thinMaterial)
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch selection ?? .dashboard {
        case .dashboard:
            DashboardView(store: store)
        case .gallery:
            ThemeGalleryView(store: store)
        case .diagnostics:
            DiagnosticsView(store: store)
        case .display(let displayID):
            if let display = store.displays.first(where: { $0.id == displayID }) {
                DisplaySettingsView(store: store, display: display)
            } else {
                DashboardView(store: store)
            }
        }
    }
}

struct SidebarRow: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 30, height: 30)
                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct DashboardView: View {
    @ObservedObject var store: WallpaperSettingsStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HeroCard(
                    title: "Wallpaper Control Center",
                    subtitle: "Tune the renderer, add atmospheric styles, export settings, and keep the wallpaper healthy across power changes and display reconnects."
                )

                WallpaperPreviewCard(
                    title: "Live Preview",
                    subtitle: "This preview mirrors the shared configuration used by default across your setup.",
                    configuration: store.configuration(for: .global),
                    height: 280
                )

                PresetsCard(store: store)

                SystemIntegrationCard(store: store)

                AutomationCard(store: store)

                ConfigurationEditorCard(
                    title: "Shared Profile",
                    subtitle: "Used automatically on every display unless a monitor gets its own override.",
                    configuration: store.configuration(for: .global),
                    target: .global,
                    store: store,
                    isDisabled: false
                )

                DisplayStatusCard(store: store)
            }
            .padding(28)
        }
        .scrollContentBackground(.hidden)
    }
}

struct DisplaySettingsView: View {
    @ObservedObject var store: WallpaperSettingsStore
    let display: DisplayInfo

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HeroCard(
                    title: display.title,
                    subtitle: "Resolution \(display.subtitle). Give this monitor a custom personality or let it inherit the shared profile."
                )

                WallpaperPreviewCard(
                    title: "Display Preview",
                    subtitle: store.hasOverride(for: display.id)
                        ? "This monitor is using its own override."
                        : "This monitor is currently inheriting the shared profile.",
                    configuration: store.configuration(for: .display(display.id)),
                    height: 240
                )

                SurfaceCard {
                    Toggle(isOn: Binding(
                        get: { store.hasOverride(for: display.id) },
                        set: { store.setOverrideEnabled($0, for: display.id) }
                    )) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Use custom settings for this display")
                                .font(.headline)
                            Text("Turn this on when one monitor should look different from the rest.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                }

                ConfigurationEditorCard(
                    title: "Display Profile",
                    subtitle: store.hasOverride(for: display.id)
                        ? "These settings apply only to this display."
                        : "Controls are locked until this display gets its own override.",
                    configuration: store.configuration(for: .display(display.id)),
                    target: .display(display.id),
                    store: store,
                    isDisabled: !store.hasOverride(for: display.id)
                )
            }
            .padding(28)
        }
        .scrollContentBackground(.hidden)
    }
}

struct ThemeGalleryView: View {
    @ObservedObject var store: WallpaperSettingsStore

    private let columns = [
        GridItem(.adaptive(minimum: 220, maximum: 260), spacing: 18)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HeroCard(
                    title: "Theme Gallery",
                    subtitle: "Browse every wallpaper with live miniatures. Selecting one applies its recommended look to the shared profile."
                )

                LazyVGrid(columns: columns, spacing: 18) {
                    ForEach(PlasmaTheme.allCases) { theme in
                        ThemeThumbnailCard(
                            theme: theme,
                            isSelected: store.configuration(for: .global).theme == theme,
                            apply: { store.setTheme(theme, for: .global) }
                        )
                    }
                }
            }
            .padding(28)
        }
        .scrollContentBackground(.hidden)
    }
}

struct DiagnosticsView: View {
    @ObservedObject var store: WallpaperSettingsStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HeroCard(
                    title: "Diagnostics",
                    subtitle: "See which profile each display is running, current FPS, render status, and the current launch-at-login health."
                )

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("System State")
                            .font(.title3.weight(.semibold))

                        HStack(spacing: 12) {
                            MetricBadge(title: "Displays", value: "\(store.displays.count)")
                            MetricBadge(title: "Low Power", value: ProcessInfo.processInfo.isLowPowerModeEnabled ? "On" : "Off")
                            MetricBadge(title: "Login Item", value: store.generalPreferences.launchAtLoginEnabled ? "Enabled" : "Off")
                            MetricBadge(title: "Background", value: store.generalPreferences.backgroundModeEnabled ? "On" : "Off")
                        }

                        Text(store.launchAtLoginStatusMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                DiagnosticsDisplayList(store: store)
            }
            .padding(28)
        }
        .scrollContentBackground(.hidden)
    }
}

struct ThemeThumbnailCard: View {
    let theme: PlasmaTheme
    let isSelected: Bool
    let apply: () -> Void

    var body: some View {
        Button(action: apply) {
            VStack(alignment: .leading, spacing: 12) {
                WallpaperPreviewView(configuration: theme.defaultConfiguration, size: CGSize(width: 240, height: 140))
                    .frame(height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(isSelected ? Color.white.opacity(0.8) : Color.white.opacity(0.10), lineWidth: isSelected ? 2 : 1)
                    )

                Text(theme.title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(theme.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 8) {
                    CapsuleTag(text: theme.family.title)
                    CapsuleTag(text: theme.defaultConfiguration.tuning.palettePreset.title)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(isSelected ? Color.white.opacity(0.25) : Color.white.opacity(0.10), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct DiagnosticsDisplayList: View {
    @ObservedObject var store: WallpaperSettingsStore

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Display Renderers")
                    .font(.title3.weight(.semibold))

                ForEach(store.displays) { display in
                    let diagnostic = store.diagnostics[display.id]
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: display.isPrimary ? "display.and.arrow.down.fill" : "display.2")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 34, height: 34)
                            .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                        VStack(alignment: .leading, spacing: 6) {
                            Text(display.title)
                                .font(.headline)
                            Text("\(display.subtitle) • \(store.profileTitle(for: display.id)) profile")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            HStack(spacing: 10) {
                                CapsuleTag(text: diagnostic?.themeTitle ?? store.effectiveConfiguration(for: display.id).theme.title)
                                CapsuleTag(text: "\(Int((diagnostic?.fps ?? 0).rounded())) fps")
                                CapsuleTag(text: diagnostic?.status ?? "Waiting")
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 6) {
                            Text(diagnostic?.isPaused == true ? "Paused" : "Active")
                                .font(.headline)
                            Text("Limit \(diagnostic?.frameRateLimit ?? store.effectiveConfiguration(for: display.id).frameRate)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

struct MetricBadge: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.weight(.semibold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct HeroCard: View {
    let title: String
    let subtitle: String

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.94, green: 0.34, blue: 0.56),
                            Color(red: 0.37, green: 0.45, blue: 0.96),
                            Color(red: 0.11, green: 0.14, blue: 0.25)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Circle()
                        .fill(.white.opacity(0.18))
                        .frame(width: 220, height: 220)
                        .blur(radius: 18)
                        .offset(x: 150, y: -80)
                )

            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.88))
                    .frame(maxWidth: 620, alignment: .leading)
            }
            .padding(28)
        }
        .frame(height: 190)
        .shadow(color: .black.opacity(0.18), radius: 18, y: 10)
    }
}

struct PresetsCard: View {
    @ObservedObject var store: WallpaperSettingsStore

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Quick Presets")
                    .font(.title3.weight(.semibold))

                HStack(spacing: 12) {
                    ForEach(BuiltInPreset.allCases) { preset in
                        let isActive = store.defaultConfiguration == preset.configuration
                        Button(action: { store.applyPreset(preset) }) {
                            VStack(spacing: 8) {
                                Image(systemName: preset.systemImage)
                                    .font(.system(size: 20, weight: .semibold))
                                Text(preset.title)
                                    .font(.caption.weight(.semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                isActive ? Color.white.opacity(0.18) : Color.white.opacity(0.07),
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(isActive ? Color.white.opacity(0.4) : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct ThemeTimeRow: View {
    let label: String
    @Binding var theme: PlasmaTheme

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Picker("", selection: $theme) {
                ForEach(PlasmaTheme.allCases) { t in
                    Text(t.title).tag(t)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 180)
        }
    }
}

struct AutomationCard: View {
    @ObservedObject var store: WallpaperSettingsStore
    @State private var rules: AutomationRules

    init(store: WallpaperSettingsStore) {
        self.store = store
        self._rules = State(initialValue: store.automationRules)
    }

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 20) {
                Text("Automation")
                    .font(.title3.weight(.semibold))

                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Switch theme by time of day", isOn: $rules.timeOfDayEnabled)
                        .font(.headline)

                    if rules.timeOfDayEnabled {
                        VStack(spacing: 10) {
                            ThemeTimeRow(label: "Morning  (06–12)", theme: $rules.schedule.morningTheme)
                            ThemeTimeRow(label: "Afternoon (12–18)", theme: $rules.schedule.afternoonTheme)
                            ThemeTimeRow(label: "Evening  (18–22)", theme: $rules.schedule.eveningTheme)
                            ThemeTimeRow(label: "Night    (22–06)", theme: $rules.schedule.nightTheme)
                        }
                        .padding(.leading, 4)
                    }
                }

                Divider().opacity(0.3)

                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Switch theme by power source", isOn: $rules.powerAdaptiveEnabled)
                        .font(.headline)

                    if rules.powerAdaptiveEnabled {
                        VStack(spacing: 10) {
                            ThemeTimeRow(label: "On Battery", theme: $rules.onBatteryTheme)
                            ThemeTimeRow(label: "On Charger", theme: $rules.onChargerTheme)
                        }
                        .padding(.leading, 4)
                    }
                }
            }
        }
        .onChange(of: rules) { _, newRules in
            store.setAutomationRules(newRules)
        }
        .onReceive(store.$automationRules) { incoming in
            if incoming != rules { rules = incoming }
        }
    }
}

struct WallpaperPreviewCard: View {
    let title: String
    let subtitle: String
    let configuration: WallpaperConfiguration
    let height: CGFloat

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                WallpaperPreviewView(
                    configuration: configuration,
                    size: CGSize(width: 820, height: height)
                )
                .frame(height: height)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(.white.opacity(0.12), lineWidth: 1)
                )
            }
        }
    }
}

struct SystemIntegrationCard: View {
    @ObservedObject var store: WallpaperSettingsStore

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 18) {
                Text("System Integration")
                    .font(.title3.weight(.semibold))

                Toggle("Launch at login", isOn: Binding(
                    get: { store.generalPreferences.launchAtLoginEnabled },
                    set: { store.setLaunchAtLoginEnabled($0) }
                ))

                Toggle("Open Control Center on launch", isOn: Binding(
                    get: { store.generalPreferences.showControlCenterOnLaunch },
                    set: { store.setShowControlCenterOnLaunch($0) }
                ))

                Toggle("Background daemon mode (hide Dock icon, use status bar)", isOn: Binding(
                    get: { store.generalPreferences.backgroundModeEnabled },
                    set: { store.setBackgroundModeEnabled($0) }
                ))

                Toggle("Pause on Low Power Mode", isOn: Binding(
                    get: { store.generalPreferences.pauseOnLowPowerMode },
                    set: { store.setPauseOnLowPowerMode($0) }
                ))

                Text(store.launchAtLoginStatusMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Button("Export Settings") { store.exportSettings() }
                    Button("Import Settings") { store.importSettings() }
                    Button("Refresh Login Status") { store.refreshLaunchAtLoginStatus() }
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

struct DisplayStatusCard: View {
    @ObservedObject var store: WallpaperSettingsStore

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Display Status")
                    .font(.title3.weight(.semibold))

                ForEach(store.displays) { display in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(display.title)
                                .font(.headline)
                            Text(store.profileTitle(for: display.id))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(store.effectiveConfiguration(for: display.id).theme.title)
                                .font(.headline)
                            Text(display.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}

struct ConfigurationEditorCard: View {
    let title: String
    let subtitle: String
    let configuration: WallpaperConfiguration
    let target: EditorTarget
    @ObservedObject var store: WallpaperSettingsStore
    let isDisabled: Bool

    private let frameRateOptions = [30, 60, 120]

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.title3.weight(.semibold))
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Random Theme") {
                        store.randomizeTheme(for: target)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.89, green: 0.34, blue: 0.51))
                }

                HStack(spacing: 14) {
                    Picker("Family", selection: familyBinding) {
                        ForEach(PlasmaThemeFamily.allCases) { family in
                            Text(family.title).tag(family)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Theme", selection: themeBinding) {
                        ForEach(PlasmaTheme.themes(for: configuration.theme.family)) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Palette", selection: paletteBinding) {
                        ForEach(ColorPalettePreset.allCases) { preset in
                            Text(preset.title).tag(preset)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("FPS", selection: frameRateBinding) {
                        ForEach(frameRateOptions, id: \.self) { option in
                            Text("\(option) fps").tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                }

                VStack(alignment: .leading, spacing: 14) {
                    SliderRow(
                        title: "Speed",
                        valueText: String(format: "%.2fx", configuration.animationSpeed),
                        value: Binding(
                            get: { Double(configuration.animationSpeed) },
                            set: { store.setAnimationSpeed(Float($0), for: target) }
                        ),
                        range: 0.2 ... 2.5
                    )

                    SliderRow(
                        title: "Intensity",
                        valueText: String(format: "%.2f", configuration.tuning.intensity),
                        value: Binding(
                            get: { Double(configuration.tuning.intensity) },
                            set: { store.setIntensity(Float($0), for: target) }
                        ),
                        range: 0.5 ... 1.6
                    )

                    SliderRow(
                        title: "Contrast",
                        valueText: String(format: "%.2f", configuration.tuning.contrast),
                        value: Binding(
                            get: { Double(configuration.tuning.contrast) },
                            set: { store.setContrast(Float($0), for: target) }
                        ),
                        range: 0.7 ... 1.5
                    )

                    SliderRow(
                        title: "Noise",
                        valueText: String(format: "%.2f", configuration.tuning.noiseAmount),
                        value: Binding(
                            get: { Double(configuration.tuning.noiseAmount) },
                            set: { store.setNoiseAmount(Float($0), for: target) }
                        ),
                        range: 0 ... 0.22
                    )

                    SliderRow(
                        title: "Zoom",
                        valueText: String(format: "%.2f", configuration.tuning.zoom),
                        value: Binding(
                            get: { Double(configuration.tuning.zoom) },
                            set: { store.setZoom(Float($0), for: target) }
                        ),
                        range: 0.75 ... 1.35
                    )
                }

                HStack(spacing: 10) {
                    CapsuleTag(text: configuration.theme.family.title)
                    CapsuleTag(text: configuration.theme.title)
                    CapsuleTag(text: configuration.tuning.palettePreset.title)
                }
            }
            .disabled(isDisabled)
            .opacity(isDisabled ? 0.56 : 1)
        }
    }

    private var themeBinding: Binding<PlasmaTheme> {
        Binding(
            get: { configuration.theme },
            set: { store.setTheme($0, for: target) }
        )
    }

    private var familyBinding: Binding<PlasmaThemeFamily> {
        Binding(
            get: { configuration.theme.family },
            set: { store.setThemeFamily($0, for: target) }
        )
    }

    private var paletteBinding: Binding<ColorPalettePreset> {
        Binding(
            get: { configuration.tuning.palettePreset },
            set: { store.setPalettePreset($0, for: target) }
        )
    }

    private var frameRateBinding: Binding<Int> {
        Binding(
            get: { configuration.frameRate },
            set: { store.setFrameRate($0, for: target) }
        )
    }
}

struct SliderRow: View {
    let title: String
    let valueText: String
    let value: Binding<Double>
    let range: ClosedRange<Double>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text(valueText)
                    .font(.system(.body, design: .monospaced).weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
        }
    }
}

struct CapsuleTag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.white.opacity(0.08), in: Capsule())
    }
}

struct SurfaceCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(.white.opacity(0.10), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.10), radius: 18, y: 8)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windows: [String: NSWindow] = [:]
    private var renderers: [String: PlasmaRenderer] = [:]
    private var themeMenuItems: [NSMenuItem] = []
    private let settingsStore = WallpaperSettingsStore()
    private var settingsWindow: NSWindow?
    private var statusItem: NSStatusItem?
    private var lastScreenLayoutSignature: String?
    private var pendingScreenRefresh: DispatchWorkItem?
    private var automationTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        settingsStore.onWallpaperConfigurationChanged = { [weak self] in
            self?.applySettingsToRenderers()
            self?.updateThemeMenuSelection()
        }
        settingsStore.onAppearancePreferencesChanged = { [weak self] in
            self?.configureBackgroundExperience()
        }
        settingsStore.onPowerPreferenceChanged = { [weak self] in
            self?.applyPowerPolicy()
        }
        settingsStore.onAutomationRulesChanged = { [weak self] in
            self?.startAutomationTimer()
        }

        configureBackgroundExperience()
        buildMenu()
        refreshDisplaysAndWallpaperWindows()
        observeSystemNotifications()
        startAutomationTimer()

        if settingsStore.generalPreferences.showControlCenterOnLaunch {
            showSettingsWindow(nil)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func observeSystemNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenConfigurationChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePowerStateChange),
            name: Notification.Name.NSProcessInfoPowerStateDidChange,
            object: ProcessInfo.processInfo
        )

        let workspaceCenter = NSWorkspace.shared.notificationCenter
        workspaceCenter.addObserver(
            self,
            selector: #selector(handleWorkspaceWillSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        workspaceCenter.addObserver(
            self,
            selector: #selector(handleWorkspaceDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        workspaceCenter.addObserver(
            self,
            selector: #selector(handleScreensDidSleep),
            name: NSWorkspace.screensDidSleepNotification,
            object: nil
        )
        workspaceCenter.addObserver(
            self,
            selector: #selector(handleScreensDidWake),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )
    }

    @objc private func handleScreenConfigurationChange() {
        pendingScreenRefresh?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.refreshDisplaysAndWallpaperWindows()
        }
        pendingScreenRefresh = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    @objc private func handlePowerStateChange() {
        DispatchQueue.main.async { [weak self] in
            self?.applyPowerPolicy()
            self?.applyAutomatedTheme()
        }
    }

    @objc private func handleWorkspaceWillSleep() {
        setAllPaused(true, reason: "Sleeping")
    }

    @objc private func handleWorkspaceDidWake() {
        recoverAfterWake()
    }

    @objc private func handleScreensDidSleep() {
        setAllPaused(true, reason: "Displays sleeping")
    }

    @objc private func handleScreensDidWake() {
        recoverAfterWake()
    }

    private func recoverAfterWake() {
        refreshDisplaysAndWallpaperWindows()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.applyPowerPolicy()
        }
    }

    private func refreshDisplaysAndWallpaperWindows() {
        let screens = NSScreen.screens
        settingsStore.refreshDisplays(from: screens)

        let screenLayoutSignature = Self.makeScreenLayoutSignature(from: screens)
        let shouldRecreateWindows = windows.isEmpty || lastScreenLayoutSignature != screenLayoutSignature
        lastScreenLayoutSignature = screenLayoutSignature

        if shouldRecreateWindows {
            recreateWallpaperWindows()
        } else {
            applySettingsToRenderers()
        }
    }

    @objc private func recreateWallpaperWindows() {
        var capturedStates: [String: PlasmaRenderer.RendererState] = [:]
        for (displayID, renderer) in renderers {
            capturedStates[displayID] = renderer.captureState()
        }

        windows.values.forEach { $0.close() }
        windows.removeAll()
        renderers.removeAll()

        for screen in NSScreen.screens {
            let view = MTKView(frame: NSRect(origin: .zero, size: screen.frame.size))
            view.autoresizingMask = [.width, .height]
            let displayID = screen.stableDisplayID

            do {
                let renderer = try PlasmaRenderer(
                    view: view,
                    displayID: displayID,
                    displayName: screen.localizedName,
                    inheritedState: capturedStates[displayID]
                )
                renderer.onDiagnosticsUpdate = { [weak self] diagnostic in
                    self?.settingsStore.updateDiagnostic(diagnostic)
                }
                renderer.apply(
                    configuration: settingsStore.configuration(for: .display(displayID)),
                    profileTitle: settingsStore.profileTitle(for: displayID)
                )
                view.delegate = renderer
                renderers[displayID] = renderer

                let window = NSWindow(
                    contentRect: screen.frame,
                    styleMask: [.borderless],
                    backing: .buffered,
                    defer: false,
                    screen: screen
                )
                window.contentView = view
                window.backgroundColor = .black
                window.isOpaque = true
                window.hasShadow = false
                window.animationBehavior = .none
                window.isReleasedWhenClosed = false
                window.ignoresMouseEvents = true
                window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
                window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
                window.setFrame(screen.frame, display: true)
                window.order(.above, relativeTo: 0)
                windows[displayID] = window
            } catch {
                presentError(error)
            }
        }

        applyPowerPolicy()
    }

    private func applySettingsToRenderers() {
        for (displayID, renderer) in renderers {
            renderer.apply(
                configuration: settingsStore.configuration(for: .display(displayID)),
                profileTitle: settingsStore.profileTitle(for: displayID)
            )
        }
        applyPowerPolicy()
    }

    private func setAllPaused(_ paused: Bool, reason: String?) {
        for renderer in renderers.values {
            renderer.setPaused(paused, reason: reason)
        }
    }

    private func applyPowerPolicy() {
        let shouldPause = settingsStore.generalPreferences.pauseOnLowPowerMode && ProcessInfo.processInfo.isLowPowerModeEnabled
        for renderer in renderers.values {
            renderer.setPaused(shouldPause, reason: shouldPause ? "Low Power Mode" : nil)
        }
    }

    private func configureBackgroundExperience() {
        if settingsStore.generalPreferences.backgroundModeEnabled {
            NSApp.setActivationPolicy(.accessory)
            installStatusItemIfNeeded()
        } else {
            NSApp.setActivationPolicy(.regular)
            removeStatusItem()
        }
    }

    private func installStatusItemIfNeeded() {
        guard statusItem == nil else {
            rebuildStatusMenu()
            return
        }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "Neon Drift"
        statusItem = item
        rebuildStatusMenu()
    }

    private func removeStatusItem() {
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
    }

    private func rebuildStatusMenu() {
        guard let statusItem else { return }
        let menu = NSMenu()

        let openItem = menu.addItem(withTitle: "Open Control Center", action: #selector(showSettingsWindow(_:)), keyEquivalent: "")
        openItem.target = self

        menu.addItem(NSMenuItem.separator())

        let presetsHeader = NSMenuItem(title: "Presets", action: nil, keyEquivalent: "")
        presetsHeader.isEnabled = false
        menu.addItem(presetsHeader)
        for preset in BuiltInPreset.allCases {
            let item = NSMenuItem(title: preset.title, action: #selector(applyPresetFromMenu(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = preset.rawValue
            item.state = settingsStore.defaultConfiguration == preset.configuration ? .on : .off
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())

        let themeItem = NSMenuItem(title: "Theme", action: nil, keyEquivalent: "")
        let themeMenu = NSMenu()
        for family in PlasmaThemeFamily.allCases {
            let familyItem = NSMenuItem(title: family.title, action: nil, keyEquivalent: "")
            let familyMenu = NSMenu()
            for theme in PlasmaTheme.themes(for: family) {
                let item = NSMenuItem(title: theme.title, action: #selector(selectGlobalTheme(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = theme.rawValue
                item.state = theme == settingsStore.defaultConfiguration.theme ? .on : .off
                familyMenu.addItem(item)
            }
            familyItem.submenu = familyMenu
            themeMenu.addItem(familyItem)
        }
        themeItem.submenu = themeMenu
        menu.addItem(themeItem)

        menu.addItem(NSMenuItem.separator())

        let launchItem = menu.addItem(
            withTitle: settingsStore.generalPreferences.launchAtLoginEnabled ? "Disable Launch at Login" : "Enable Launch at Login",
            action: #selector(toggleLaunchAtLoginFromStatusItem),
            keyEquivalent: ""
        )
        launchItem.target = self

        menu.addItem(NSMenuItem.separator())

        let quitItem = menu.addItem(withTitle: "Quit Neon Drift", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = NSApp

        statusItem.menu = menu
    }

    private func startAutomationTimer() {
        automationTimer?.invalidate()
        automationTimer = nil
        let rules = settingsStore.automationRules
        guard rules.timeOfDayEnabled || rules.powerAdaptiveEnabled else { return }
        applyAutomatedTheme()
        automationTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.applyAutomatedTheme() }
        }
    }

    private func applyAutomatedTheme() {
        let rules = settingsStore.automationRules
        if rules.powerAdaptiveEnabled {
            let theme = PowerMonitor.isOnBattery() ? rules.onBatteryTheme : rules.onChargerTheme
            settingsStore.setTheme(theme, for: .global)
            return
        }
        if rules.timeOfDayEnabled {
            settingsStore.setTheme(rules.schedule.themeForNow(), for: .global)
        }
    }

    @objc private func applyPresetFromMenu(_ sender: NSMenuItem) {
        guard
            let raw = sender.representedObject as? String,
            let preset = BuiltInPreset(rawValue: raw)
        else { return }
        settingsStore.applyPreset(preset)
    }

    @objc private func toggleLaunchAtLoginFromStatusItem() {
        settingsStore.setLaunchAtLoginEnabled(!settingsStore.generalPreferences.launchAtLoginEnabled)
        rebuildStatusMenu()
    }

    private func buildMenu() {
        let menuBar = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        let settingsItem = appMenu.addItem(
            withTitle: "Settings…",
            action: #selector(showSettingsWindow(_:)),
            keyEquivalent: ","
        )
        settingsItem.target = self
        let exportItem = appMenu.addItem(withTitle: "Export Settings…", action: #selector(exportSettings), keyEquivalent: "e")
        exportItem.target = self
        let importItem = appMenu.addItem(withTitle: "Import Settings…", action: #selector(importSettings), keyEquivalent: "i")
        importItem.target = self
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(
            withTitle: "Quit Neon Drift",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appMenuItem.submenu = appMenu
        menuBar.addItem(appMenuItem)

        let themeMenuItem = NSMenuItem()
        let themeMenu = NSMenu(title: "Theme")
        themeMenuItems = PlasmaThemeFamily.allCases.flatMap { family in
            let familyMenuItem = NSMenuItem()
            familyMenuItem.title = family.title

            let familyMenu = NSMenu(title: family.title)
            let items = PlasmaTheme.themes(for: family).map { theme in
                let item = NSMenuItem(
                    title: theme.title,
                    action: #selector(selectGlobalTheme(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = theme.rawValue
                item.state = theme == settingsStore.defaultConfiguration.theme ? .on : .off
                familyMenu.addItem(item)
                return item
            }

            familyMenuItem.submenu = familyMenu
            themeMenu.addItem(familyMenuItem)
            return items
        }
        themeMenuItem.submenu = themeMenu
        menuBar.addItem(themeMenuItem)

        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        let reloadItem = windowMenu.addItem(
            withTitle: "Reload Displays",
            action: #selector(handleScreenConfigurationChange),
            keyEquivalent: "r"
        )
        reloadItem.target = self
        let backgroundItem = windowMenu.addItem(
            withTitle: "Toggle Background Mode",
            action: #selector(toggleBackgroundMode),
            keyEquivalent: "b"
        )
        backgroundItem.target = self
        windowMenuItem.submenu = windowMenu
        menuBar.addItem(windowMenuItem)

        NSApp.mainMenu = menuBar
    }

    @objc private func exportSettings() {
        settingsStore.exportSettings()
    }

    @objc private func importSettings() {
        settingsStore.importSettings()
        rebuildStatusMenu()
    }

    @objc private func toggleBackgroundMode() {
        settingsStore.setBackgroundModeEnabled(!settingsStore.generalPreferences.backgroundModeEnabled)
    }

    private func updateThemeMenuSelection() {
        for item in themeMenuItems {
            item.state = (item.representedObject as? UInt32) == settingsStore.defaultConfiguration.theme.rawValue ? .on : .off
        }
        rebuildStatusMenu()
    }

    @objc private func selectGlobalTheme(_ sender: NSMenuItem) {
        guard
            let rawValue = sender.representedObject as? UInt32,
            let theme = PlasmaTheme(rawValue: rawValue)
        else {
            return
        }

        settingsStore.setTheme(theme, for: .global)
        updateThemeMenuSelection()
    }

    @objc private func showSettingsWindow(_ sender: Any?) {
        if settingsWindow == nil {
            let rootView = WallpaperSettingsView(store: settingsStore)
            let hostingView = NSHostingView(rootView: rootView)

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1180, height: 820),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Neon Drift Settings"
            window.center()
            window.isReleasedWhenClosed = false
            window.contentView = hostingView
            settingsWindow = window
        }

        settingsStore.refreshLaunchAtLoginStatus()
        rebuildStatusMenu()
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(sender)
    }

    private func presentError(_ error: Error) {
        let alert = NSAlert(error: error)
        alert.runModal()
    }

    private static func makeScreenLayoutSignature(from screens: [NSScreen]) -> String {
        screens
            .map { screen in
                let frame = screen.frame
                return [
                    screen.stableDisplayID,
                    String(Int(frame.origin.x)),
                    String(Int(frame.origin.y)),
                    String(Int(frame.size.width)),
                    String(Int(frame.size.height))
                ].joined(separator: ":")
            }
            .sorted()
            .joined(separator: "|")
    }
}

struct RuntimeError: LocalizedError {
    let errorDescription: String?

    init(_ description: String) {
        errorDescription = description
    }
}

enum PowerMonitor {
    static func isOnBattery() -> Bool {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as [CFTypeRef]
        for source in sources {
            guard
                let desc = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
                let state = desc[kIOPSPowerSourceStateKey] as? String
            else { continue }
            return state == kIOPSBatteryPowerValue
        }
        return false
    }
}

private extension NSScreen {
    var stableDisplayID: String {
        if let screenNumber = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            return screenNumber.stringValue
        }
        let frame = self.frame
        return "\(localizedName)-\(Int(frame.origin.x))-\(Int(frame.origin.y))-\(Int(frame.size.width))-\(Int(frame.size.height))"
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
