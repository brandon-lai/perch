import AppKit
import PerchCore

/// The red panda's tree in the desktop overlay, on the same pixel grid as the panda. Drag it along the bottom of
/// any display to move it; Settings offers the same without dragging.
@MainActor
final class TreeView: NSView {
    static let art = PixelTree.art()
    static let rgba = PixelTree.palette.rgba(art)
    static let image = pixelImage(rgba, width: art.width, height: art.height)
    var pixelScale: CGFloat = 1.5 { didSet { if pixelScale != oldValue { relayout() } } }
    init() {
        super.init(frame: .zero)
        relayout()
        setAccessibilityElement(true); setAccessibilityRole(.image)
        setAccessibilityLabel("Your red panda's tree. Move it in Perch Settings, or drag it.")
    }
    required init?(coder: NSCoder) { fatalError("Programmatic views only") }
    private func relayout() {
        setFrameSize(NSSize(width: CGFloat(PixelTree.width) * pixelScale, height: CGFloat(PixelTree.height) * pixelScale))
        needsDisplay = true
    }
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.interpolationQuality = .none
        context.draw(Self.image, in: bounds)
    }
    /// True on a painted pixel of the tree, for a point in `view`'s coordinates. Clicks elsewhere pass through.
    func treeHit(_ point: CGPoint, from view: NSView) -> Bool {
        guard !isHidden else { return false }
        let local = convert(point, from: view)
        let x = Int(floor(local.x / pixelScale)), row = PixelTree.height - 1 - Int(floor(local.y / pixelScale))
        guard x >= 0, x < PixelTree.width, row >= 0, row < PixelTree.height else { return false }
        return Self.rgba[(row * PixelTree.width + x) * 4 + 3] > 0
    }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
