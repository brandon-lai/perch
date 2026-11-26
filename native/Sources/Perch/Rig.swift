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
@MainActor
struct RigFrame {
    let image: CGImage
    let texture: SKTexture
    let alpha: [UInt8]
    func hit(x: Double, y: Double) -> Bool {
        let px = Int(x), py = Int(y)
        guard px >= 0, px < 160, py >= 0, py < 144 else { return false }
        return alpha[py * 160 + px] > 16
    }
}
@MainActor
final class PetRig {
    let pack: PetPack
    var frames: [Action: [RigFrame]] = [:]
    var generatedCount: Int { frames.values.reduce(0) { $0 + $1.count } }
    init(pack: PetPack) {
        self.pack = pack
        for action in Action.allCases {
            let count = [Action.sleep, .look, .fall, .feed, .peek].contains(action) ? 1 : 12
            frames[action] = (0..<count).map { render(action, phase: Double($0) / 12) }
        }
    }
    func frame(_ action: Action, index: Int) -> RigFrame {
        let poses = frames[action]!
        return poses[index % poses.count]
    }
    private func render(_ action: Action, phase: Double) -> RigFrame {
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 160, pixelsHigh: 144,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 640, bitsPerPixel: 32)!
        let graphics = NSGraphicsContext(bitmapImageRep: bitmap)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphics
        let context = graphics.cgContext
        context.clear(CGRect(x: 0, y: 0, width: 160, height: 144))
        let coat = NSColor(hex: pack.coat), ear = NSColor(hex: pack.earColor)
        let marking = NSColor(hex: pack.markingColor), ink = NSColor(hex: "#293341")
        let wave = sin(phase * .pi * 2)
        let sleeping = action == .sleep
        let sitting = [.sit, .highFive, .peek, .feed].contains(action)
        let bounce = action == .walk ? abs(wave) * 2 : action == .idle ? wave * 0.6 : 0
        let stretching = action == .stretch
        let shaking = action == .shake
        let bracing = action == .ride
        let climbing = action == .climb
        let bodyY = sleeping ? 13.0 : sitting ? 12.0 : stretching ? 19 : bracing ? 23 : 27.0 + bounce
        let headY = sleeping ? 35.0 : sitting ? 73.0 : stretching ? 43 : 73.0 + bounce
        if shaking { context.translateBy(x: wave * 3, y: 0) }
        func ellipse(_ rect: NSRect, _ color: NSColor) {
            color.setFill(); NSBezierPath(ovalIn: rect).fill()
        }
        func path(_ points: [NSPoint], _ color: NSColor) {
            let p = NSBezierPath(); p.move(to: points[0])
            for point in points.dropFirst() { p.line(to: point) }
            p.close(); color.setFill(); p.fill()
        }
        func round(_ rect: NSRect, radius: Double, _ color: NSColor) {
            color.setFill(); NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
        }
        // A single palette and set of body parts is posed, never independently generated.
        let tail = NSBezierPath()
        tail.move(to: NSPoint(x: 44, y: bodyY + 17))
        tail.curve(to: NSPoint(x: 21, y: bodyY + (sleeping ? 12 : 42) + wave * 6),
                   controlPoint1: NSPoint(x: 16, y: bodyY + 12), controlPoint2: NSPoint(x: 14, y: bodyY + 41))
        tail.lineWidth = pack.species == .cat ? 8 : 12; tail.lineCapStyle = .round
        ear.setStroke(); tail.stroke()
        ellipse(NSRect(x: sitting ? 41 : 36, y: bodyY, width: sleeping ? 79 : stretching ? 88 : sitting ? 65 : 76,
                       height: sleeping ? 36 : sitting ? 61 : stretching ? 37 : 45), coat)
        if !sleeping {
            for (index, x) in [48.0, 67.0, 91.0, 110.0].enumerated() {
                if sitting && index < 2 {
                    ellipse(NSRect(x: x - 7, y: 0, width: 28, height: 16), coat)
                    if pack.marking == .socks || pack.marking == .tuxedo {
                        ellipse(NSRect(x: x - 7, y: 0, width: 28, height: 8), marking)
                    }
                    continue
                }
                let lift = action == .walk || climbing ? max(0, sin(phase * .pi * 2 + Double(index) * .pi)) * (climbing ? 18 : 9) : 0
                let heldLift = action == .held ? 10 + wave * 3 : 0
                let height = bodyY + (sitting ? 40 : 12) - lift - heldLift
                if action == .highFive && index == 3 {
                    round(NSRect(x: x, y: 55 + wave * 3, width: 12, height: 30), radius: 6, coat)
                } else {
                    round(NSRect(x: x - 6 + (bracing ? (index < 2 ? -5 : 5) : 0),
                                 y: lift + heldLift, width: 13, height: max(14, height)), radius: 6, coat)
                    if pack.marking == .socks || pack.marking == .tuxedo {
                        round(NSRect(x: x - 6, y: lift + heldLift, width: 13, height: 10), radius: 5, marking)
                    }
                }
            }
        } else { ellipse(NSRect(x: 86, y: 2, width: 30, height: 13), coat) }
        if pack.marking == .chest || pack.marking == .tuxedo {
            ellipse(NSRect(x: sleeping ? 84 : 94, y: bodyY + 3, width: 19, height: sleeping ? 19 : 36), marking)
        }
        let headX = sleeping ? 108.0 : action == .sniff ? 113.0 : 104.0
        ellipse(NSRect(x: headX - 25, y: headY - 17, width: 48, height: 43), coat)
        if pack.ears == .pointed {
            path([NSPoint(x: headX - 22, y: headY + 10), NSPoint(x: headX - 21, y: headY + 43),
                  NSPoint(x: headX - 3, y: headY + 20)], ear)
            path([NSPoint(x: headX + 3, y: headY + 19), NSPoint(x: headX + 19, y: headY + 40),
                  NSPoint(x: headX + 22, y: headY + 9)], ear)
        } else {
            ellipse(NSRect(x: headX - 29, y: headY - 7 + (action == .look ? 3 : 0),
                           width: 19, height: 34), ear)
            ellipse(NSRect(x: headX + 12, y: headY - 2, width: 15, height: 29), ear)
        }
        ellipse(NSRect(x: headX - 7, y: headY - 13, width: pack.species == .dog ? 32 : 24, height: 22), marking)
        if sleeping || action == .yawn {
            let eye = NSBezierPath()
            eye.move(to: NSPoint(x: headX + 1, y: headY + 9))
            eye.line(to: NSPoint(x: headX + 8, y: headY + 8))
            eye.lineWidth = 2.5; eye.lineCapStyle = .round; ink.setStroke(); eye.stroke()
        } else {
            ellipse(NSRect(x: headX + (action == .look ? 5 : 2), y: headY + 6, width: 5, height: 6), ink)
        }
        ellipse(NSRect(x: headX + 16, y: headY - 1, width: 7, height: 5), ink)
        if action == .yawn { ellipse(NSRect(x: headX + 7, y: headY - 10, width: 7, height: 10 + wave * 2), ink) }
        if action == .fall {
            let line = NSBezierPath()
            line.move(to: NSPoint(x: 52, y: 117)); line.line(to: NSPoint(x: 52, y: 130))
            line.move(to: NSPoint(x: 70, y: 123)); line.line(to: NSPoint(x: 70, y: 139))
            line.lineWidth = 2; NSColor(hex: "#ABB8CB").setStroke(); line.stroke()
        }
        if pack.species == .cat {
            for y in [-3.0, 2.0] {
                let whisker = NSBezierPath(); whisker.move(to: NSPoint(x: headX + 12, y: headY + y))
                whisker.line(to: NSPoint(x: headX + 34, y: headY + y + 2))
                whisker.lineWidth = 1; ink.setStroke(); whisker.stroke()
            }
        }
        if [.pet, .react].contains(action) {
            let x = 74.0, y = 110 + phase * 13
            ellipse(NSRect(x: x, y: y, width: 8, height: 8), NSColor(hex: "#A94E52"))
            ellipse(NSRect(x: x + 6, y: y, width: 8, height: 8), NSColor(hex: "#A94E52"))
            path([NSPoint(x: x, y: y + 3), NSPoint(x: x + 14, y: y + 3), NSPoint(x: x + 7, y: y - 6)],
                 NSColor(hex: "#A94E52"))
        }
        if action == .feed {
            round(NSRect(x: 114, y: 0, width: 37, height: 14), radius: 6, NSColor(hex: "#4269AB"))
        }
        if action == .play {
            ellipse(NSRect(x: 129, y: 3 + abs(wave) * 20, width: 18, height: 18), NSColor(hex: "#4269AB"))
        }
        if sleeping {
            let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 14, weight: .medium), .foregroundColor: ink]
            ("z" as NSString).draw(at: NSPoint(x: 128, y: 76), withAttributes: attrs)
        }
        NSGraphicsContext.restoreGraphicsState()
        let image = bitmap.cgImage!
        // AppKit's bitmap has bottom-up rows in this non-flipped drawing context.
        var alpha = [UInt8](repeating: 0, count: 160 * 144)
        let bytes = bitmap.bitmapData!
        for y in 0..<144 { for x in 0..<160 { alpha[y * 160 + x] = bytes[(143 - y) * 640 + x * 4 + 3] } }
        let texture = SKTexture(cgImage: image); texture.filteringMode = .linear
        return RigFrame(image: image, texture: texture, alpha: alpha)
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
    init(size: CGSize, rig: PetRig) {
        self.rig = rig
        super.init(size: size)
        backgroundColor = .clear; scaleMode = .resizeFill
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0); sprite.size = CGSize(width: 160, height: 144)
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
        frameIndex = still ? 0 : Int(Double(manifestFrame) / Double(count) * 12)
        refresh()
    }
    func refresh() {
        sprite.texture = rig.frame(hover && selected == .idle ? .look : selected, index: frameIndex).texture
        let anchor = rig.pack.animations.first { $0.name == selected }!.anchor
        // Pack anchors specify a conceptual paw coordinate; the procedural rig normalizes to its paw line.
        sprite.anchorPoint = CGPoint(x: anchor.x, y: 0)
    }
    func alphaHit(_ point: CGPoint) -> Bool {
        guard !sprite.isHidden, sprite.xScale != 0 else { return false }
        let local = sprite.convert(point, from: self)
        return rig.frame(hover && selected == .idle ? .look : selected, index: frameIndex)
            .hit(x: local.x + 160 * sprite.anchorPoint.x, y: local.y)
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
        let actions: [Action] = contactSheet ? [.idle, .walk, .sit, .sleep, .held, .fall, .ride, .climb, .pet, .feed, .play, .highFive] : [action]
        for (index, pose) in actions.enumerated() {
            let columns = contactSheet ? 4 : 1, rows = contactSheet ? 3 : 1
            let width = Double(bounds.width) / Double(columns), height = Double(bounds.height) / Double(rows)
            let x = Double(index % columns) * width, y = Double(bounds.height) - Double(index / columns + 1) * height
            let sizeScale = rig.pack.size == .small ? 0.78 : rig.pack.size == .large ? 1.18 : 1.0
            let scale = (contactSheet ? 1.0 : min(1.8, (width - 30) / 160)) * sizeScale
            let rect = NSRect(x: x + (width - 160 * scale) / 2, y: y + (height - 144 * scale) / 2 + 15,
                              width: 160 * scale, height: 144 * scale)
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
