import AppKit
import SpriteKit
import PerchCore

extension NSColor {
    convenience init(hex: String) {
        let value = UInt32(hex.dropFirst(), radix: 16) ?? 0xC58B55
        self.init(srgbRed: Double((value >> 16) & 255) / 255,
                  green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255, alpha: 1)
    }
}
/// Wraps straight RGBA bytes (alpha is always 0 or 255) without any smoothing.
func pixelImage(_ rgba: [UInt8], width: Int, height: Int) -> CGImage {
    let provider = CGDataProvider(data: Data(rgba) as CFData)!
    return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                   space: CGColorSpace(name: CGColorSpace.sRGB)!,
                   bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                   provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
}

@MainActor
struct RigFrame {
    static let side = PixelSprites.side
    let image: CGImage
    let texture: SKTexture
    /// Bottom-up alpha, matching SpriteKit's coordinate space.
    let alpha: [UInt8]
    init(art: PixelArt, palette: PixelPalette) {
        let rgba = palette.rgba(art)
        image = pixelImage(rgba, width: art.width, height: art.height)
        texture = SKTexture(cgImage: image); texture.filteringMode = .nearest
        var bottomUp = [UInt8](repeating: 0, count: art.width * art.height)
        for y in 0..<art.height {
            for x in 0..<art.width { bottomUp[y * art.width + x] = rgba[((art.height - 1 - y) * art.width + x) * 4 + 3] }
        }
        alpha = bottomUp
    }
    func hit(x: Double, y: Double) -> Bool {
        guard x >= 0, y >= 0, x < Double(Self.side), y < Double(Self.side) else { return false }
        return alpha[Int(y) * Self.side + Int(x)] > 16
    }
}

@MainActor
final class PetRig {
    let pack: PetPack
    let palette: PixelPalette
    var frames: [Action: [RigFrame]] = [:]
    private(set) var generatedCount = 0
    lazy var diningFrames = build(.feed, atDish: true)
    /// Points per art pixel. Whole numbers keep every pixel square and crisp.
    var pixelScale: Double { Self.pixelScale(pack.size) }
    static func pixelScale(_ size: PetSize) -> Double { size == .small ? 2 : size == .large ? 4 : 3 }
    init(pack: PetPack) {
        self.pack = pack
        palette = PixelPalette(pack: pack)
        for action in Action.allCases { frames[action] = build(action, atDish: false) }
    }
    private func build(_ action: Action, atDish: Bool) -> [RigFrame] {
        let animation = PixelSprites.animation(action, species: pack.species, ears: pack.ears, atDish: atDish)
        let unique = animation.frames.map { RigFrame(art: $0, palette: palette) }
        generatedCount += unique.count
        return animation.slots.map { unique[$0] }
    }
    func frame(_ action: Action, index: Int) -> RigFrame {
        let poses = frames[action]!
        return poses[index % poses.count]
    }
}

@MainActor
final class PetScene: SKScene {
    let sprite = SKSpriteNode()
    var rig: PetRig
    var selected: Action = .idle {
        didSet { if oldValue != selected { frameIndex = 0 } }
    }
    var frameIndex = 0
    private(set) var updateCount = 0
    private var began = 0.0
    private var lastAction: Action?
    var hover = false
    var still = false
    var atDish = false
    private var displayedFrame: RigFrame {
        if atDish { return rig.diningFrames[frameIndex % 12] }
        return rig.frame(hover && selected == .idle ? .look : selected, index: frameIndex)
    }
    init(size: CGSize, rig: PetRig) {
        self.rig = rig
        super.init(size: size)
        backgroundColor = .clear; scaleMode = .resizeFill
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0); sprite.size = CGSize(width: RigFrame.side, height: RigFrame.side)
        addChild(sprite); refresh()
    }
    required init?(coder: NSCoder) { fatalError("Programmatic scenes only") }
    override func update(_ currentTime: TimeInterval) {
        updateCount += 1
        if lastAction != selected { began = currentTime; lastAction = selected }
        let animation = rig.pack.animations.first { $0.name == selected }!
        let count = animation.frameCount
        let raw = Int(max(0, currentTime - began) * animation.fps)
        let manifestFrame = animation.loop == .loop ? raw % count : min(raw, count - 1)
        frameIndex = still ? 0 : atDish ? raw % 12 : Int(Double(manifestFrame) / Double(count) * 12)
        refresh()
    }
    func refresh() {
        sprite.texture = displayedFrame.texture
        let anchor = rig.pack.animations.first { $0.name == selected }!.anchor
        // Pack anchors specify a conceptual paw coordinate; every sprite keeps its paw line at the bottom row.
        sprite.anchorPoint = CGPoint(x: anchor.x, y: 0)
    }
    func alphaHit(_ point: CGPoint) -> Bool {
        guard !sprite.isHidden, sprite.xScale != 0 else { return false }
        let local = sprite.convert(point, from: self)
        return displayedFrame.hit(x: local.x + Double(RigFrame.side) * sprite.anchorPoint.x, y: local.y)
    }
}

@MainActor
final class RigPreview: NSView {
    var rig: PetRig
    var action: Action = .idle
    var phase = 0
    var caption = "Milo · curious company"
    var contactSheet = false
    init(rig: PetRig) { self.rig = rig; super.init(frame: .zero); setAccessibilityLabel("Live procedural pet preview") }
    required init?(coder: NSCoder) { fatalError("Programmatic views only") }
    override func draw(_ dirtyRect: NSRect) {
        NSColor(hex: "#E9EDF5").setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 24, yRadius: 24).fill()
        let ctx = NSGraphicsContext.current!.cgContext
        ctx.interpolationQuality = .none
        let actions: [Action] = contactSheet ? [.idle, .walk, .sit, .sleep, .held, .fall, .ride, .climb, .pet, .feed, .play, .highFive] : [action]
        for (index, pose) in actions.enumerated() {
            let columns = contactSheet ? 4 : 1, rows = contactSheet ? 3 : 1
            let width = Double(bounds.width) / Double(columns), height = Double(bounds.height) / Double(rows)
            let x = Double(index % columns) * width, y = Double(bounds.height) - Double(index / columns + 1) * height
            let unit = contactSheet ? 5.0 : rig.pack.size == .small ? 5 : rig.pack.size == .large ? 7 : 6
            let side = Double(RigFrame.side) * unit
            let rect = NSRect(x: (x + (width - side) / 2).rounded(), y: (y + (height - side) / 2 + 15).rounded(),
                              width: side, height: side)
            ctx.draw(rig.frame(pose, index: phase).image, in: rect)
            NSColor(hex: "#ABB8CB").setFill()
            NSBezierPath(roundedRect: NSRect(x: x + 22, y: rect.minY - 4, width: width - 44, height: 4), xRadius: 2, yRadius: 2).fill()
            let label = contactSheet ? pose.rawValue : caption
            let font = NSFont.systemFont(ofSize: contactSheet ? 13 : 14, weight: .medium)
            let text = NSAttributedString(string: label, attributes: [.font: font, .foregroundColor: NSColor(hex: "#293341")])
            text.draw(at: NSPoint(x: x + (width - text.size().width) / 2, y: y + 18))
        }
    }
}
