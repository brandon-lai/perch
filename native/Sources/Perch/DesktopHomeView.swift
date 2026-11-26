import AppKit
import PerchCore

private func homeImage(_ art: PixelArt, pressed: Bool = false) -> (CGImage, [UInt8]) {
    let rgba = PixelHome.palette(pressed: pressed).rgba(art)
    return (pixelImage(rgba, width: art.width, height: art.height), stride(from: 3, to: rgba.count, by: 4).map { rgba[$0] })
}

@MainActor
final class DesktopHomeView: NSView {
    let bowl = FoodBowlButton()
    private let base = homeImage(PixelHome.base()).0
    var pixelScale: CGFloat = 3 {
        didSet { if pixelScale != oldValue { relayout() } }
    }
    init() {
        super.init(frame: .zero)
        addSubview(bowl)
        relayout()
    }
    required init?(coder: NSCoder) { fatalError("Programmatic views only") }
    private func relayout() {
        setFrameSize(NSSize(width: CGFloat(PixelHome.width) * pixelScale, height: CGFloat(PixelHome.height) * pixelScale))
        bowl.pixelScale = pixelScale
        bowl.frame = NSRect(x: CGFloat(PixelHome.bowlX) * pixelScale,
                            y: CGFloat(PixelHome.height - PixelHome.bowlY - PixelHome.bowlHeight) * pixelScale,
                            width: CGFloat(PixelHome.bowlWidth) * pixelScale, height: CGFloat(PixelHome.bowlHeight) * pixelScale)
        needsDisplay = true
    }
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.interpolationQuality = .none
        context.draw(base, in: bounds)
    }
    func bowlHit(_ point: CGPoint, from view: NSView) -> Bool {
        !isHidden && bowl.containsPaint(bowl.convert(point, from: view))
    }
}

@MainActor
final class FoodBowlButton: NSButton {
    private let empty = homeImage(PixelHome.bowl(full: false))
    private let full = homeImage(PixelHome.bowl(full: true))
    private let emptyPressed = homeImage(PixelHome.bowl(full: false), pressed: true).0
    private let fullPressed = homeImage(PixelHome.bowl(full: true), pressed: true).0
    override var isFlipped: Bool { false }
    var pixelScale: CGFloat = 3 { didSet { needsDisplay = true } }
    var filled = false {
        didSet {
            guard filled != oldValue else { return }
            needsDisplay = true
            setAccessibilityValue(filled ? "Full" : "Empty")
        }
    }
    /// A point on the painted bowl body, in this button's coordinates.
    var paintedSample: NSPoint { NSPoint(x: 6.5 * pixelScale, y: (CGFloat(PixelHome.bowlHeight) - 6.5) * pixelScale) }
    init() {
        super.init(frame: .zero)
        title = ""; isBordered = false
        setAccessibilityLabel("Fill food bowl")
        setAccessibilityValue("Empty")
        toolTip = "Fill food bowl"
    }
    required init?(coder: NSCoder) { fatalError("Programmatic views only") }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    func containsPaint(_ point: CGPoint) -> Bool {
        let x = Int(floor(point.x / pixelScale)), row = PixelHome.bowlHeight - 1 - Int(floor(point.y / pixelScale))
        guard x >= 0, x < PixelHome.bowlWidth, row >= 0, row < PixelHome.bowlHeight else { return false }
        return (filled ? full.1 : empty.1)[row * PixelHome.bowlWidth + x] > 0
    }
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.interpolationQuality = .none
        let image = filled ? (isHighlighted ? fullPressed : full.0) : (isHighlighted ? emptyPressed : empty.0)
        context.draw(image, in: bounds)
    }
}
